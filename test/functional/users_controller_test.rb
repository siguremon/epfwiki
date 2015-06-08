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

class UsersControllerTest < ActionController::TestCase
  
  def setup
    #logger.debug "Test Case: #{name}"
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    @tony = Factory(:user, :name => 'Tony Clifton', :password => 'secret', :admin => 'N')
    @controller = UsersController.new
    @emails = ActionMailer::Base::deliveries
    @emails.clear        
  end
  
  test "List" do 
    get :list
    assert_tologin
    get :index
    assert_tologin
  end
  
  test "List cadmin" do 
    # get the central admin
    get :list
    session['user'] = @george.id
    get :list
    assert_not_nil assigns(:users)
    assert_not_nil assigns(:admins)
    assert_not_nil assigns(:cadmin)     
  end
  
  test "List admin" do 
    get :index
    session['user'] = @andy.id
    get :list
    assert_not_nil assigns(:users)
    assert_not_nil assigns(:admins)
    assert_not_nil assigns(:cadmin)     
  end
  
  # Shows:
  # 1. Only admins can request users list
  # 2. User cannot access account details
  test "List normal user" do 
    # 1
    get :list
    session['user'] = @tony.id
    get :list
    assert_unot_admin_message
    # 2
    post :account, :id => @george.id
    assert_equal session_user, assigns(:user)
    assert_equal LoginController::FLASH_UNOT_ADMIN, flash['notice']
  end
  
  # Shows:
  # 1. user can edit his details
  # 2. user cannot edit another users details
  # 3. admin cannot edit another users details
  # 4. cadmin can edit another users details
  test "Edit" do
    # 1
    get :index
    session['user'] = @tony.id
    saved_name = @tony.name
    post :edit, :id => @tony.id, :user => {:name => 'test06_edit'}
    assert_response :success
    @tony.reload
    assert_equal 'test06_edit', @tony.name
    @tony.name = saved_name
    @tony.save!
    # 2
    session['user'] = @cash.id
    post :edit, :id => @tony.id, :user => {:name => 'test06_edit'}
    assert_response :success
    @tony.reload
    assert_equal saved_name, @tony.name # unchanged
    # 3
    session['user'] = @andy.id
    post :edit, :id => @tony.id, :user => {:name => 'test06_edit'}
    assert_response :success
    @tony.reload
    assert_equal saved_name, @tony.name # unchanged
    # 4
    session['user'] = @george.id
    post :edit, :id => @tony.id, :user => {:name => 'test06_edit'}
    assert_response :success
    @tony.reload
    assert_equal 'test06_edit', @tony.name # changed
    @tony.name = saved_name
    @tony.save!
  end
  
  test "Send report" do 
    get :index
    session['user'] = @cash.id
    rt = Time.now
    rep = Report.new('M',nil,rt)
    assert_equal rt, rep.runtime
    assert_equal (rep.runtime - 1.month).at_beginning_of_month, rep.starttime
    assert_equal rep.runtime.at_beginning_of_month, rep.endtime
    post :send_report, :type => 'M'
    #assert_equal UsersController::FLASH_REPORT_SENT, flash['success']
    assert_redirected_to :action => 'account', :id => @cash.id
    assert_equal 1, @emails.size
    assert_equal [],  rep.items, "Report shouldn't have any data to send"
    assert_equal UsersController::FLASH_NO_ITEMS, flash['notice']
    assert @emails.first.subject.index('Monthly Summary')
    assert_equal @cash.email, @emails.first.bcc.first 
    assert @emails.first.body.include? 'Monthly Summary'
    assert_equal([ENV['EPFWIKI_REPLY_ADDRESS']], @emails.first.from)
    post :send_report, :type => 'D'
    assert_equal UsersController::FLASH_NO_ITEMS, flash['notice']
    post :send_report, :type => 'W'
    assert_equal UsersController::FLASH_NO_ITEMS, flash['notice']
  end

  # Show:
  # 1. User can access details 
  # 2. Cadmin is shown links 'list'
  # 3. User with data (comments, pages, uploads)
  test "Show" do 
    get :index
    # 1
    session['user'] = @tony.id
    get :show, :id => @tony.id
    assert_response :success
    assert_template 'show'
    assert_not_nil assigns(:user)
    assert_not_nil assigns(:versions)
    assert_not_nil assigns(:comments)
    assert_not_nil assigns(:uploads)
    assert_not_nil assigns(:pages)    
    assert_equal @tony.id, assigns(:user).id
    # 2
    session['user'] = @george.id
    get :show, :id => @tony.id
    assert_equal @tony.id, assigns(:user).id # cadmin sees details of user
    assert_tag :tag => 'a', :attributes => {:href => '/users/list'}    
    assert_tag :tag => 'a', :attributes => {:href => '/sites/list'}        
    # 3
    p = WikiPage.find(:first)
    create_some_data(p)    
    get :show, :id => @andy.id
  end

  test "Edit user" do 
    get :list
    session['user'] = @tony.id
    post :edit, :id => session['user'], :user => { :name => 'Tony Renamed'}
    assert_response :success
    assert_template 'edit'    
    assert_not_nil assigns(:user)
    assert_equal User.find(assigns(:user).id).name, 'Tony Renamed' 
  end
  
  # Shows:
  # 1. George is central admin, Tony an ordinary user
  # 2. list of users contains links to make other admins the cadmin, and links to make other users admins
  # 3. George can make another Tony the central admin
  # 4. George can make another user cadmin after making Tony the central admin (untill his session expires) 
  # 5. Tony can make another user the cadmin after becoming central admin
  # 6. This is all one transaction (we cannot end up with having no cadmin)
  test "Cadmin" do 
    # 1
    assert @george.cadmin?
    assert @tony.user?
    # 2
    get :list    
    session['user'] = @george.id
    get :list
    assert_response :success
    assert_template 'list'
    User.find_all_by_admin('Y').each do |user|
      assert_tag :tag => 'a', :attributes => {:href => "/users/cadmin/#{user.id}"}     
      assert_tag :tag => 'a', :attributes => {:href => "/users/admin/#{user.id}?admin=N"}           
    end
    User.find_all_by_admin('N').each do |user|
      assert_tag :tag => 'a', :attributes => {:href => "/users/admin/#{user.id}?admin=Y"}     
    end
    # 3
    assert_not_nil @george
    assert_not_nil @tony
    get :list
    post :cadmin, :id => @tony.id
    assert_redirected_to :action => 'list'
    assert_equal '', assigns(:cadmin).errors.full_messages.join(", ")        
    assert_equal '', assigns(:user).errors.full_messages.join(", ")
    @george.reload
    @tony.reload
    assert !@george.cadmin?
    assert @george.admin?
    assert @tony.cadmin?
    # 4
    post :cadmin, :id => @tony.id
    assert_unot_cadmin_message
    # 5
    session['user'] = @tony.id
    post :cadmin, :id => @george.id
    assert_redirected_to :action => 'list'
    @george.reload
    @tony.reload
    assert @george.cadmin?
    assert @george.admin?
    assert !@tony.cadmin?
    assert @tony.admin?
    # 6
    @george.name = nil # will cause save of this user to fail
    User.cadmin(@george, @tony)
    @george.reload
    @tony.reload
    assert @george.cadmin?
    assert @george.admin?
    assert !@tony.cadmin?
    assert @tony.admin?
    assert !@george.name.nil?
  end

  test "Account" do 
    # TODO implement test
    #assert_tag :tag => 'a', :attributes => {:href => "/users/edit/#{@tony.id.to_s}"}
    #assert_tag :tag => 'a', :attributes => {:href => '/login/change_password'}

  end
  
  test "Adminmessage" do
    session['user'] = @george.id
    am = AdminMessage.create(:guid => 'Welcome', :text => 'Welcome to EPF Wiki, the Wiki technology for Eclipse Process Framework Composer.' )
    assert_equal 1, AdminMessage.count
    get :account
    assert_response :success
    assert_tag :tag => 'a', :attributes => {:href => "/users/admin_message?id=#{am.id}"}
    get :admin_message, :id => am.id
    post :admin_message, :id => am.id, :admin_message => {:id => am.id, :guid => 'Welcome2', :text => 'New text'}
    assert_response :success
    assert_equal Utils::FLASH_RECORD_UPDATED, flash['success']
    am.reload
    assert_equal 'New text', am.text
    assert_equal 'Welcome2', am.guid
  end
  
end
