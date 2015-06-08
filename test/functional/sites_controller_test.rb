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

class SitesControllerTest < ActionController::TestCase
  
  def setup
    #logger.debug "Test Case: #{name}"  
    @controller = SitesController.new
    #@request    = ActionController::TestRequest.new
    #@response   = ActionController::TestResponse.new
    #@andy, @george, @tony = users(:andy), users(:george), users(:tony) # admin, cadmin, user
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    @tony = Factory(:user, :name => 'Tony Clifton', :password => 'secret', :admin => 'N')
    @emails = ActionMailer::Base::deliveries
    @emails.clear
    #get :list     
  end
  
  def teardown
    [ENV['EPFWIKI_SITES_PATH'], ENV['EPFWIKI_WIKIS_PATH']].each do |p|
      FileUtils.rm_r(p) if File.exists?(p)
      FileUtils.makedirs(p)
    end
  end
  
  test "index" do 
    get :index
    assert_redirected_to :controller => 'login'
    session['user'] = @tony.id
    assert_not_nil(session['user'])
  end
  
  test "List" do 
    get :list
    assert_redirected_to :controller => 'login'
    session['user'] = @tony.id
    get :list
    assert_response :success
    assert_template 'list'
    assert_not_nil assigns(:baseline_processes)
    assert_not_nil assigns(:wikis)
  end
  
  # Shows:
  # 1. Need to be an admin to create a baseline process
  # 2. Admin get link to create baseline process
  # 3. Admin can upload baseline process
  test "New" do
    # 1
    session['user'] = @tony.id
    get :new
    assert_unot_admin_message
    # 2
    session['user'] = @andy.id
    get :list
    assert_response :success
    assert_tag :tag => 'a', :attributes => {:href => "/sites/new"}    
    # 3
    get :new
    assert_response :success
    assert assigns(:site)
    assert assigns(:baseline_processes)
    assert assigns(:folders)        
    assert assigns(:folders).empty?
    assert_equal 1, assigns(:baseline_processes).size
    assert_equal 'templates_20080828', assigns(:baseline_processes)[0].title
    assert_response :success
    #post :upload, :site => nil TODO how to test this here
    #assert_not_nil assigns(:site)
    #assert_errors
    #assert_equal "Folder can't be blank, File can't be blank", assigns(:site).errors.full_messages.join(", ")
    assert_equal 2, Site.count
    @oup_20060721 = create_oup_20060721
    @oup_20060728 = create_oup_20060728  
    @oup_20060825 = create_oup_20060825
    @oup_20060721.destroy
    @oup_20060728.destroy
    @oup_20060825.destroy
    get :new    
    assert_equal ['oup_20060721', 'oup_20060728', 'oup_20060825'].sort, assigns(:folders).sort
    assigns(:folders).each do |folder|
      assert_tag :tag => 'option', :content => folder
    end
    site_count = Site.count
    assert session_user.admin?
    post :new, :site => {:title => 'oup_20060721', :folder => assigns(:folders)[0], :description => 'test03_new'}
    assert_not_nil assigns(:baseline_processes)
    assert_not_nil assigns(:folders)
    site = assigns(:site)
    assert_not_nil site
    assert_no_errors(site)
    assert site.valid? 
    assert_redirected_to :action => 'list'
    assert_equal site_count + 1, Site.count    
    assert_equal Utils::FLASH_RECORD_CREATED, flash['success']
  end
  
  # Shows:
  # 1. Only admins can create wikis
  # 2. Admin can request form to create a new wiki
  test "New wiki" do 
    @oup_20060721 = create_oup_20060721
    # 1
    session['user'] = @tony.id
    get :new_wiki
    assert_unot_admin_message
    # 2
    session['user'] = @andy.id
    assert @andy.admin?
    get :new_wiki 
    assert_not_nil assigns(:wiki)
    assert_field 'wiki_folder' 
    assert_tag :tag => 'textarea', :attributes => {:id => 'wiki_description', :name => 'wiki[description]'}
    assert_field 'wiki_title'
  end
  
  # Shows:
  # 1. Admin can create a Wiki (note: the Wiki is empty after create)
  test "New wiki post" do 
    @emails.clear
    # 1
    get :new_wiki
    session['user'] = @andy.id
    @oup_20060721 = create_oup_20060721
    Rails.logger.debug('@oup_20060721' + @oup_20060721.inspect)
    post :new_wiki, :wiki => {:folder => 'openup', :title => 'OpenUP Wiki', 
      :description => 'Wiki for OpenUP created in test05_new_wiki_post'} #,       :baseline_process => @oup_20060721
    assert_not_nil assigns(:wiki)
    assert_redirected_to :action => 'description', :id => assigns(:wiki).id
    assert SitesController::FLASH_WIKI_SITE_CREATED, flash['success']
    wiki = assigns(:wiki)
    assert_not_nil wiki
    # 2
  end
  
  # Shows
  # 1. Ordinary users cannot do wikify now 
  # 2. Admin can wikify content directly
  test "Wikify now" do 
    @emails.clear
    get 'list'
    # 1.
    session['user'] = @tony.id
    @oup_20060721 = create_oup_20060721
    wiki = Wiki.new(:folder => 'openup', :title => 'OpenUP Wiki', :user_id => session['user'])
    assert wiki.save
    assert_equal 'Pending', wiki.status
    update = Update.new(:wiki => wiki, :baseline_process => @oup_20060721, :user => session_user)
    assert update.save
    get :update_now, :update_id => update.id
    assert_unot_admin_message
    # 2
    session['user'] = @andy.id
    post :update_now, :update_id => update.id 
    assert_equal(4, @emails.size) 
    assert_equal ["[EPF Wiki - Test Enviroment] SCHEDULED creation new Wiki OpenUP Wiki using Baseline Process oup_20060721",
 "[EPF Wiki - Test Enviroment] Autorisation Problem Detected",
 "[EPF Wiki - Test Enviroment] STARTED creating New Wiki OpenUP Wiki using Baseline Process oup_20060721",
 "[EPF Wiki - Test Enviroment] FINISHED creating new Wiki OpenUP Wiki using Baseline Process oup_20060721"], 
 [@emails[0].subject, @emails[1].subject, @emails[2].subject, @emails[3].subject]
    assert_equal 'Ready', wiki.status
    wiki.reload
    assert_equal wiki.baseline_process, @oup_20060721
  end
  
  # Shows
  # 1. Admin requests creation of Wiki
  # 2. Content is wikified using job_daily (an email is sent if the job fails)
  test "New wiki job daily" do 
    # 1
    get :new_wiki
    session['user'] = @andy.id
    #baseline_process = Site.find_by_title('openup0721')
    #assert_not_nil baseline_process
    @oup_20060721 = create_oup_20060721    
    post :new_wiki, :wiki => {:folder => 'openup2', :title => 'OpenUP Wiki2', :description => 'Wiki for OpenUP created in tst06_new_wiki2'}
    openupwiki2 = Site.find_by_folder('openup2')
    assert_not_nil openupwiki2
    assert_equal 'Pending', openupwiki2.status
    # 2
    @emails.clear
    update = Update.new(:user => @andy, :baseline_process => @oup_20060721, :wiki => openupwiki2)
    assert update.save
    Site.update # was job_daily
    Site.reports
    openupwiki2.reload
    assert_equal [], Update.find_todo
    #rep_cnt = 1 # daily
    #rep_cnt += 1 if Time.now.wday == 1 # weekly
    #rep_cnt += 1 if Time.now.day == 1 # monthly
    #assert_equal [], @emails.collect{|e|[e.subject, e.bcc]}
    assert_equal(3, @emails.size) # scheduled, started, finished, daily summary for 2 wikis and 1 global
    s = @emails.collect{|e|e.subject}.to_s
    assert (s.include?('SCHEDULED') and s.include?('FINISHED') and s.include?('STARTED')), "#{s}"
    assert_equal 'Ready', openupwiki2.status
  end
  
  # Shows
  # 1. Wikis can be updated from the 'description' page
  # 2. Admin can schedule an update (create an update record) (ordinary user cannot)
  # 3. Admin can cancel an update 
  # 4. Admin can do update_now
  test "Update wiki" do 
    # 1
    @oup_20060721 = create_oup_20060721
    @oupwiki = create_oup_wiki(@oup_20060721)    
    get :description, :id => @oupwiki.id
    assert_redirected_to :controller => 'login'
    session['user'] = @tony.id
    get :description, :id => @oupwiki.id
    # TODO enable.
    #BaselineProcess.find(:all).each do |bp|
    #  assert_match "/sites/update/#{@oupwiki.id}?baseline_process_id=#{bp.id}", @response.body
    #end
    # 2
    session['user'] = @tony.id
    post :schedule_update
    assert_unot_admin_message
    session['user'] =  @andy.id
    cnt = Update.count
    post :schedule_update, :id => @oupwiki.id, :baseline_process_id => @oup_20060721.id    
    assert_equal 1+cnt, Update.count
    assert_redirected_to :action => 'description', :id => @oupwiki.id
    # 3
    assert_equal 1, Update.find_todo.size
    update = Update.find_todo[0]
    session['user'] = @tony.id
    post :update_cancel, :id => @oupwiki.id , :update_id => update.id
    assert_unot_admin_message
    session['user'] = @andy.id
    post :update_cancel, :id => @oupwiki.id , :update_id => update.id
    assert_equal cnt, Update.count
    assert_equal 0, Update.find_todo.size
    # 4
    @emails.clear 
    update = Update.new(:wiki => @oupwiki, :baseline_process => @oup_20060721, :user => @andy)
    assert update.save
    assert_equal(1, @emails.size) # scheduled 
    session['user'] = @tony.id
    post :update_now, :update_id => update.id
    assert_unot_admin_message
    session['user'] = @andy.id
    @emails.clear    
    post :update_now, :update_id => update.id
    assert_equal SitesController::FLASH_WIKI_UPDATE_SUCCESS, flash['success']
    assert_equal [], Update.find_todo    
    assert_equal(2, @emails.size) # started, created
  end

  # Shows:
  # 1. Cannot make a Wiki obsolete with a get request
  # 2. Ordinary users cannot make a Wiki obsolete
  # 3. Admin users can make a Wiki obsolete
  test "Obsolete" do 
    wiki = Wiki.find(:first)
    assert wiki.obsolete_on.nil?
    # 1
    session['user'] = @george.id
    get :obsolete, :id => wiki.id
    assert_illegal_get
    # 2
    session['user'] = @tony.id
    get :obsolete, :id => wiki.id
    assert_unot_admin_message
    session['user'] = @andy.id
    post :obsolete, :id => wiki.id
    wiki.reload
    assert !wiki.obsolete_on.nil?
    assert_equal @andy.id, wiki.obsolete_by, "User #{User.find(wiki.obsolete_by).name}"
  end
  
  test "Comments and versions" do
    session['user'] = @george.id
    wiki = Wiki.find(:first)
    p = wiki.pages.first
    c = Comment.new(:text => 'Text of comment by user tony', :user => @tony, :version => p.current_version, :page => p, :site => p.site)
    assert c.save
    get :comments, :id => wiki.id
    assert_response :success
    
    # 25 comments
    
    get :versions, :id => wiki.id
    assert_response :success
  end
  
end
