# Copyright (c) 2006-2013 OnKnows.com, Logica, 2008 IBM, and others
#  
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
#Contributors:
#* Onno van der Straaten:: initial implementation
#* Ricardo Balduino:: additions for feed generation (practices and UMA types)

require 'test_helper'

class EpfcLibraryTest < ActiveSupport::TestCase

  def teardown
    [ENV['EPFWIKI_SITES_PATH'], ENV['EPFWIKI_WIKIS_PATH']].each do |p|
      FileUtils.rm_r(p) if File.exists?(p)
      FileUtils.makedirs(p)
    end
  end

  # Shows:
  # 1. No notify_immediate users, no email
  # 2. Notify_immediate users are receiving email
  test "Notification 2" do 
    # 1. Note: create_templates uses update.do_update which sends emails
    @emails = ActionMailer::Base::deliveries
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    @tony = Factory(:user, :name => 'Tony Clifton', :password => 'secret', :admin => 'N')
    @emails.clear
    @oup_20060721 = create_oup_20060721
    @oup_wiki = create_oup_wiki(@oup_20060721)
    @oup_20060728 = create_oup_20060728 
    assert_equal 5, Site.count # 2 wiki, 3 baseline
    assert_equal 3, @emails.size # STARTED and FINISHED
    @emails.clear
    update = Update.create(:wiki_id => @oup_wiki.id, :baseline_process_id => @oup_20060728.id, :user_id => @andy.id)
    @andy.notify_immediate = 1
    @george.notify_immediate = 1
    @cash.notify_immediate = 1
    @andy.save!
    @george.save!
    @cash.save!
    update.do_update
    #assert_equal 4, @emails.size
    #email = @emails[3]
    assert_equal ["[EPF Wiki - Test Enviroment] SCHEDULED creation new Wiki OpenUP Wiki using Baseline Process oup_20060728",
  "[EPF Wiki - Test Enviroment] STARTED update of Wiki OpenUP Wiki with Baseline Process oup_20060728",
  "[EPF Wiki - Test Enviroment] FINISHED update of Wiki OpenUP Wiki with Baseline Process oup_20060728",
  "[EPF Wiki - Test Enviroment] Wiki OpenUP Wiki Updated with Baseline Process oup_20060728"], @emails.collect{|e|e.subject}
   # assert_equal ["[EPF Wiki - Test Enviroment] Wiki Templates Updated with Baseline Process templates_20080828",["andy.kaufman@epf.eclipse.org",
 #"cash.oshman@epf.eclipse.org",
 #"george.shapiro@epf.eclipse.org"], true], [email.subject, email.bcc, email.body.include?('http://localhost:3000/users/account')]
  end

  # Shows
  # 1. That #job_daily can be used to notify users on the status of contributions
  # 2. Users are auto subscribed to receive alerts on the page
  # 3. Tony receives notification on update of the harvested comment and version
  # 4. Andy receives notification of having been processed
  test "Reviewed notification email" do
    @emails = ActionMailer::Base::deliveries
    @emails.clear
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @tony = Factory(:user, :name => 'Tony Clifton', :password => 'secret', :admin => 'N')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    #create_templates
    wiki = Wiki.find_by_folder('templates')
    assert_not_nil wiki
    assert_equal 'Ready', wiki.status
    p1, p2 = wiki.pages[23], wiki.pages[6]
    # create some versions
    co1 = Checkout.new(:note => 'Checkout to test notification email', :page => p1, :site => wiki, :source_version => p1.current_version, :user => @tony)
    co2 = Checkout.new(:note => 'Checkout to test notification email', :page => p2, :site => wiki, :source_version => p2.current_version, :user => @cash)
    # 2
    assert !Notification.find_all_users(p1, Page.name).include?(@tony) 
    assert !Notification.find_all_users(p2, Page.name).include?(@cash)    
    assert co1.save, "Failed to save co1 #{co1.errors.inspect}"
    assert co2.save, "Failed to save co2 #{co2.errors.inspect}"
    v1 = co1.version
    v2 = co2.version
    assert_equal 2, Checkout.count
    co1.checkin(@tony)
    co2.checkin(@cash)
    assert Notification.find_all_users(p1, Page.name).include?(@tony) 
    assert Notification.find_all_users(p2, Page.name).include?(@cash)    
    assert_equal 0, Checkout.count
    v1.review_note = "Review note 1"
    v2.review_note = "Review note 2"
    v1.done = 'Y'
    v2.done = 'Y'
    v1.reviewer = @andy
    v2.reviewer = @george
    assert v1.save
    assert v2.save
    # create some comments
    cmt1 = Comment.create(:text => 'Comment 1', :user => @tony, :version => v1, :page => v1.page, :site => v1.wiki)
    cmt2 = Comment.create(:text => 'Comment 2', :user => @cash, :version => v1, :page => v1.page, :site => v1.wiki)
    cmt3 = Comment.create(:text => 'Comment 3', :user => @george, :version => v2, :page => v2.page, :site => v2.wiki)
    assert cmt1.save
    assert cmt2.save
    assert cmt3.save
    assert Notification.find_all_users(p2, Page.name).include?(@cash)    
    assert Notification.find_all_users(p1, Page.name).include?(@tony) 
    assert Notification.find_all_users(p2, Page.name).include?(@cash)    
    assert Notification.find_all_users(p2, Page.name).include?(@george)    
    [cmt1, cmt2, cmt3].each do |cmt|
      assert cmt.save
      cmt.review_note = cmt.text
      cmt.done = 'Y'
      cmt.reviewer = @andy
      assert cmt.save
    end
    for i in 1..3
      Upload.create(:filename => 'index.html', :upload_type => 'Image', :description => 'Description of upload ' + i.to_s, :user => @cash, :reviewer => @andy, :review_note => 'Review note of upload ' + i.to_s, :done => 'Y')
    end
    @emails.clear 
    update = Update.new(:wiki => Wiki.find_by_folder('templates'), :baseline_process => BaselineProcess.find(:first), :user => @andy)
    assert update.save
    Site.update # was job_daily
    Site.reports
    r =  ["[EPF Wiki - Test Enviroment] SCHEDULED creation new Wiki Templates using Baseline Process templates_20080828",
 "[EPF Wiki - Test Enviroment] STARTED update of Wiki Templates with Baseline Process templates_20080828",
 "[EPF Wiki - Test Enviroment] FINISHED update of Wiki Templates with Baseline Process templates_20080828",
 "[EPF Wiki - Test Enviroment] Your contribution has been processed",
 "[EPF Wiki - Test Enviroment] Your contribution has been processed",
 "[EPF Wiki - Test Enviroment] Your contribution has been processed"]
 #"[EPF Wiki - Test Enviroment] Templates Daily Summary", # send but without recipients
 #"[EPF Wiki - Test Enviroment] Daily Summary"]
 #r << "[EPF Wiki - Test Enviroment] Weekly Summary"  if Time.now.wday == 1 # monday, sunday is 0
 #r << "[EPF Wiki - Test Enviroment] Monthly Summary" if Time.now.day == 1 # first day of the month
    assert_equal r,@emails.collect {|e|e.subject}
    assert_equal [["foocash.oshman@epf.eclipse.org"],
 ["footony.clifton@epf.eclipse.org"], ['foogeorge.shapiro@epf.eclipse.org'],
 "[EPF Wiki - Test Enviroment] Your contribution has been processed",
 "[EPF Wiki - Test Enviroment] Your contribution has been processed",
 "[EPF Wiki - Test Enviroment] Your contribution has been processed"], [@emails[3].to, @emails[4].to, @emails[5].to, @emails[3].subject, @emails[4].subject, @emails[5].subject]
    assert IO.readlines(File.expand_path('test/unit/notifier_test/contributions_processed.html', Rails.root.to_s)).join.index('Hi Cash Oshman')
    # 3
    #v1, cmt1
    email = @emails[4]
    assert_equal ["footony.clifton@epf.eclipse.org"], email.to
    assert email.body.include?(v1.page.url), "URL #{v1.page.url} niet aanwezig in \n#{email.body}"
    assert email.body.include?(v1.page.presentation_name)
    assert email.body.include?(v1.reviewer.name)    
    assert email.body.include?(v1.review_note)    
    assert email.body.include?(cmt1.page.url)
    assert email.body.include?(cmt1.text)
    assert email.body.include?(cmt1.reviewer.name)    
    assert email.body.include?(cmt1.review_note)    
    # 4
    u = Upload.find(:first)
    email = @emails[3]
    assert_equal ["foocash.oshman@epf.eclipse.org"], email.to
    assert email.body.include?(u.url)
    assert email.body.include?(u.filename)
    assert email.body.include?(u.reviewer.name)    
    assert email.body.include?(u.review_note)    
  end
  
end
