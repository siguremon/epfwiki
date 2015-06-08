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

class PortalControllerTest < ActionController::TestCase

  def setup
    @controller = PortalController.new
  end
  
  def teardown
    [ENV['EPFWIKI_SITES_PATH'], ENV['EPFWIKI_WIKIS_PATH']].each do |p|
      FileUtils.rm_r(p) if File.exists?(p)
      FileUtils.makedirs(p)
    end
  end

  # Shows:
  # 1. We can access home, wikis, users ... when there is no data
  # 2. We can access ... with data
  test "All" do 
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    # 1.
    @wiki = Wiki.find(:first)
    get :home
    assert_response :success
    get :wikis
    assert_response :success
    get :users
    assert_response :success
    get :about
    assert_response :success
    get :feedback
    assert_response :success
    get :privacypolicy
    assert_response :success
    get :termsofuse
    assert_response :success
    get :archives, :year => Time.now.year, :month => Time.now.month
    assert_response :success

    # 2. 
    create_some_data(WikiPage.find(:first))  
    get :home
    assert_response :success
    get :wikis
    assert_response :success
    get :users
    assert_response :success
    get :about
    assert_response :success
    get :feedback
    assert_response :success
    get :privacypolicy
    assert_response :success
    get :termsofuse
    assert_response :success
    get :archives, :year => Time.now.year, :month => Time.now.month
    assert_response :success
  end 

  # Shows that if there no users, the user is redirected to create the first user
  test "Home" do 
    get :home
    assert_redirected_to :controller => 'login'
  end  
  
  # Shows:
  test "Different status wikis" do 
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    # 1.
    get :home
    assert_response :success
    get :about
    assert_response :success
    get :wikis
    assert_response :success
    get :feedback
    assert_response :success    
    # 2.
    w1 = Wiki.create(:folder =>'test_with_different_status_wikis', :user => @andy, :title => 'test_with_different_status_wikis', :description => 'test_with_different_status_wikis' )
    assert_equal 'Pending', w1.status 
    w2 = Wiki.create(:folder =>'test_with_different_status_wikis2', :user => @andy, :title => 'test_with_different_status_wikis2', :description => 'test_with_different_status_wikis2' )    
    assert_equal 'Pending', w2.status
    bp = BaselineProcess.find(:first)
    update = Update.create(:baseline_process => bp, :wiki => w2, :user => @andy)
    assert_equal 'Scheduled', w2.status
    update.do_update
    w2.reload
    assert_equal 'Ready', w2.status
    w3 = Wiki.create(:folder =>'test_with_different_status_wikis3', :user => @andy, :title => 'test_with_different_status_wikis3', :description => 'test_with_different_status_wikis3' )    
    update = Update.create(:baseline_process => bp, :wiki => w3, :user => @andy)
    update.do_update
    update = Update.create(:baseline_process => bp, :wiki => w3, :user => @andy)
    w3.reload
    assert_equal 'Scheduled', w3.status 
    get :home
    assert_response :success
    get :about
    assert_response :success
    get :wikis
    assert_response :success
    get :feedback
    assert_response :success     
  end
  
  # TODO more advanced archives test
  #def tst_archives
  #  create_templates
  #  get :home
  #  archive_links = @response.body.scan(/<a href="\/archives.+<\/a>/)
  #  archive_links.each do |archive_link|
  #    year = archive_link.split('/')[2]
  #    month = archive_link.split('/')[3].split('"')[0]
  #    FileUtils.rm_rf File.expand_path("public/archives/#{year}/#{month}.html", RAILS_ROOT)
  #    logger.info "get request archives/#{year}/#{month}"
  #    get :archives, :year => year, :month => month
  #    assert_response :success
  #    assert File.exists?(File.expand_path("public/archives/#{year}/#{month}.html", RAILS_ROOT))
  #    job_daily
  #    assert !File.exists?(File.expand_path("public/archives/#{year}/#{month}.html", RAILS_ROOT))
  #  end
  #end
  
end
