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

class NotificationPerSiteTest < ActionDispatch::IntegrationTest

  def setup
    #logger.debug "Test Case: #{name}"
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @emails = ActionMailer::Base::deliveries
  end
  
  def teardown
    [ENV['EPFWIKI_SITES_PATH'], ENV['EPFWIKI_WIKIS_PATH']].each do |p|
      FileUtils.rm_r(p) if File.exists?(p)
      FileUtils.makedirs(p)
    end
  end
  
  test "Notification per site" do
    assert_equal 0, Notification.count
    @wiki = Wiki.find(:first) # templates wiki
    @oup_20060721 = create_oup_20060721
    @oup_wiki = create_oup_wiki(@oup_20060721)
    get 'users/notification', :user_id => @andy.id, :id => @wiki.id, :notification_type => 'Daily'  
    assert_equal 0, Notification.count, "No session, shouldn't be possible to create a notification"
    post 'login/login', :user => {:email => @andy.email, :password => 'secret'}
    get 'users/notification', :user_id => @andy.id, :id => @wiki.id, :notification_type => 'Daily', :format => 'js'
    assert_response :success
    get 'users/notification', :user_id => @andy.id, :id => @wiki.id, :notification_type => 'Immediate', :format => 'js'
    assert_response :success
    assert_equal 2, Notification.count
    # version
    @emails.clear
    @page1 = WikiPage.find_by_presentation_name('Toolmentor Template')
    post 'pages/checkout', :user_version => {:version_id => @page1.current_version.id, :note => 'Changing toolmentor template'}
    assert_not_nil @page1.checkout
    assert_redirected_to :action => 'edit', :checkout_id => @page1.checkout.id
    assert_not_nil @page1.checkout
    assert_equal 2, Notification.count, "User has Notification Daily and Notification Immediate"
    post 'pages/checkin', :checkout_id => @page1.checkout.id
    assert_equal 3, Notification.count # also subscribed to the page
    assert_equal 1, @emails.size, "Andy should receive only one immediate email although he has Immediate and Page notification"
    v = @page1.current_version
    v.created_on = v.created_on - 1.day # back one day to send it in the report
    v.save!
    @emails.clear
    r = Report.new('D', @wiki) # 
    assert_equal 1, r.users.size
    reps = Site.reports # TODO test user
    assert_equal 1,@emails.size
    #assert assigns(:report)
    #rep = assigns(:report)
    assert_equal 1, reps.length
    assert reps.first.starttime < v.created_on
    assert reps.first.endtime > v.created_on
    assert_equal ["[EPF Wiki - Test Enviroment] Templates Daily Summary", ["fooandy.kaufman@epf.eclipse.org"]], 
      [@emails.first.subject, @emails.first.bcc]
    # user andy is only interested in the templates wiki and does not want to be notified of changes in other wikis
    @emails.clear
    post 'login/login', :user => {:email => @george.email, :password => 'secret'}
    p = @oup_wiki.pages.first
    post 'pages/checkout', :user_version => {:version_id => p.current_version.id, :note => 'Change of george'}
    assert_not_nil p.checkout
    post 'pages/checkin', :checkout_id => p.checkout.id
    assert_equal 1, @emails.size
    assert @emails.first.bcc.include? @george.email
    @george.notify_monthly = 1
    @george.save!
    @emails.clear
    Site.reports((Time.now + 1.month).at_beginning_of_month) # monthly report of next month should include/exclude the item
    assert_equal 1, @emails.size
    assert @emails.first.subject.include? 'Monthly Summary'
    assert @emails.first.bcc.include? @george.email
    assert !@emails.first.bcc.include?(@andy.email) # andy is not interested in oup_wiki 
    
    assert_equal 4, Notification.count, "Should unscribe user"
    get 'users/notification', :user_id => @andy.id, :id => @wiki.id, :notification_type => 'Daily', :format => 'js'
    assert_response :success
    assert_equal 3, Notification.count, "Should unscribe user"
  end
end
