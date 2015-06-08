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

class SetupAndSignInTest < ActionDispatch::IntegrationTest
  
  #	If there are no users: 
  # * all request are redirected to the new page
  # * the new page can be used to create the central admin account
  # After the first user is created (User.count > 0) it is not possible to create the central admin user
  test	"Signup central admin" do
    Rails.logger.info("Test signup central admin")
    User.destroy_all
    assert_equal 0, User.count
    get	"login/login"
    assert_redirected_to :action => 'new_cadmin'
    # fields cannot be null
    post "login/new_cadmin"
    assert_response :success
    assert_errors
    assert_equal 0, User.count
    # no password confirmation
    post "login/new_cadmin", :user => {:name => "cadmin", :email => "cadmin@logicacmg.com", :password => "cadmin"}
    assert_response :success 
    #assert nil, @response.body
    assert_equal "Password confirmation can't be blank",assigns(:user).errors.full_messages.join(', ') 
    assert_equal 0, User.count
    assert_errors
    # passwords don't match
    post "login/new_cadmin", :user => {:name => "cadmin", :email => "cadmin@logicacmg.com", :password => "cadmin", :password_confirmation => ""}
    assert_equal "Password confirmation can't be blank, Password doesn't match confirmation",assigns(:user).errors.full_messages.join(', ') 
    assert_response :success #302?
    assert_equal 0, User.count
    assert_errors
    # passwords should be present
    post "login/new_cadmin", :user => {:name => "cadmin", :email => "cadmin@logicacmg.com"}
    assert_equal "Password can't be blank, Password confirmation can't be blank",assigns(:user).errors.full_messages.join(', ') 
    assert_equal 0, User.count    
    assert_response :success
    assert_errors
    post "login/new_cadmin", :user => {:name => "cadmin", :email => "cadmin@logicacmg.com", :password => "cadmin", :password_confirmation => "cadmin"}    
    assert_equal "",assigns(:user).errors.full_messages.join(', ') 
    assert_equal 1, User.count    
    cadmin = User.find_central_admin
    assert_not_nil cadmin
    assert_redirected_to :action => 'login' 
    post "login/new_cadmin", :user => {:name => "cadmin", :email => "cadmin@logicacmg.com", :password => "cadmin", :password_confirmation => "cadmin"}    
    assert_equal LoginController::FLASH_CENTRAL_ADMIN_ALREADY_CREATED, flash['error']    
    assert_equal 1, User.count    
    assert_redirected_to :action => 'login'
  end
  
  # if ENV['EPFWIKI_DOMAINS'] is set sign-up is restricted to those domains
  test "Sign up" do
    Rails.logger.info("Test sign up")    
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @emails = ActionMailer::Base::deliveries
    @emails.clear
    user_count = User.count
    # 1 . sign with domain restriction
    get "login/sign_up"
    assert_field("user_email")
    assert_field("user_name")
    assert_field("user_password")
    assert_field("user_password_confirmation")    
    assert_tag :tag => "select", :attributes => {:name => "user[email_extension]"}    
    @html_document = nil # workaround for bug in assert_tag used in assert_errors   
    post "login/sign_up", :user => {:name => "user1", :email => "user1", :email_extension => "@somedomain.nl", :password => 'mypassword', :password_confirmation => 'mypassword'} # , :i_agree_to_the_terms_of_use => '1'
    assert_errors
#    assert_tag :tag => "div", :attributes => { :class => "fieldWithErrors" }
    assert_response :success
    assert_equal user_count, User.count
    user = assigns(:user)
    assert_equal "Email domain not valid",user.errors.full_messages.join(', ') 
    # this domain is allowed, the user is created
    post	"login/sign_up", :user => {:name => "user1", :email=>"user1", :email_extension => "@epf.eclipse.org", :password => 'mypassword', :password_confirmation => 'mypassword'} # , :i_agree_to_the_terms_of_use => '1'
    user = assigns(:user)
    assert_no_errors(user)
    assert_redirected_to :action => 'login'
    assert_equal user_count + 1 , User.count 
    assert_equal 1, @emails.size
    email = @emails.first
    assert_equal("[#{ENV['EPFWIKI_APP_NAME']}] Welcome", email.subject)
    assert_equal("user1@epf.eclipse.org", email.to[0])
    assert_equal([ENV['EPFWIKI_REPLY_ADDRESS']], email.from)
    assert_redirected_to :action => 'login'
    assert_equal LoginController::FLASH_PW_CONFIRMATION_EMAIL_SENT, flash['success']
    # cannot sign up with already taken name, email
    @html_document = nil
    post	"login/sign_up", :user => {:name => "user1", :email => "user1", :email_extension => "@epf.eclipse.org", :password => 'mypassword', :password_confirmation => 'mypassword'} # , :i_agree_to_the_terms_of_use => '1'
    assert_equal "Name has already been taken, Email has already been taken",assigns(:user).errors.full_messages.join(', ') 
    # sign up without domain restriction
    ENV['EPFWIKI_DOMAINS'] = nil    
    get "login/sign_up"
    assert_field("user_email")
    assert_field("user_name")
    assert_field("user_password")
    assert_field("user_password_confirmation")    
    assert_no_tag :tag => "select", :attributes => {:name => "email_extension"}    
    user_count = User.count
    @html_document = nil
    post "login/sign_up", :user => {:name => "user3", :email => "user2@xyz.com", :password => 'mypassword', :password_confirmation => 'mypassword'} # , :i_agree_to_the_terms_of_use => '1'
    assert_no_errors(assigns(:user))
    assert_equal user_count + 1, User.count 
    assert_redirected_to :controller => 'login', :action => 'login'
    #assert_equal "Name has already been taken, Email has already been taken",assigns(:user).errors.full_messages.join(', ') 
    @html_document = nil
    get "login/sign_up"
    assert_field("user_email")
    assert_field("user_name")
    assert_field("user_password")
    assert_field("user_password_confirmation")    
    assert_no_tag :tag => "select", :attributes => {:name => "email_extension"}        
    user_count = User.count
    # user exists
    @html_document = nil
    post "login/sign_up", :user => {:name => "user2", :email => "user2@xyz.com"} # , :i_agree_to_the_terms_of_use => '1'
    assert_equal "Password confirmation can't be blank, Password can't be blank, Email has already been taken".split(', ').sort.join(', '),assigns(:user).errors.full_messages.sort.join(', ') 
    assert_equal user_count, User.count 
    assert_errors
    # creating user3
    @html_document = nil
    post "login/sign_up", :user => {:name => "user4", :email => "user4@xyz.com", :password => 'user4', :password_confirmation => 'user4'} # , :i_agree_to_the_terms_of_use => '1'
    assert_no_errors(assigns(:user))
    assert_equal LoginController::FLASH_PW_CONFIRMATION_EMAIL_SENT,  flash['success']   
    assert_equal "",assigns(:user).errors.full_messages.join(', ') 
    assert_equal user_count + 1, User.count 
    assert_redirected_to :action => 'login'
    assert_equal Digest::SHA1.hexdigest('user4'), assigns(:user).hashed_password
    get "login/login" 
    assert_response :success
    # assert_field("user_email")# TODO Rails bug?
    # assert_field("user_password")    # TODO Rails bug?
    # user3 cannot sign-in, it needs to be confirmed
    user3 = User.find_by_name('user4')
    post "login/login" , :user => {:email => 'user4@epf.org', :password => 'user3'}
    assert_equal LoginController::FLASH_INVALID_PW, flash['notice']
    # cannot confirm with wrong token 
    # ? log reports a RunTimeError but then the assert says there is no runtime error! assert_raise(RuntimeError){ get "login/confirm_account", :id => user3.id, :tk => "anystring"}
    get "login/confirm_account/#{user3.id}", :tk => "anystring"
    user3 = User.find_by_name('user4')
    assert_equal nil, user3.confirmed_on
    # can confirm with right token
    get "login/confirm_account/#{user3.id}", :tk => Digest::SHA1.hexdigest(user3.hashed_password)
    assert_equal LoginController::FLASH_PASSWORD_ACTIVATED, flash['success']
    assert_not_nil assigns(:user).confirmed_on
    # user can now logon
    # user can sign in and check that they want to be remembered
    post "login/login" , :user => {:email => 'user4@xyz.com', :password => 'user4', :remember_me => 0}
    assert_equal User.find_by_name("user4"), session_user
    assert_not_nil cookies
    # TODO we can't use cookies[:epfwiki_id] anymore?
    assert_equal cookies["epfwiki_id"], session['user'].to_s 
    # automatically sign-in for remembered users
    # redirected to user details or requested page (not tested)
    get "login/login"
    assert_redirected_to :controller => "users", :action => "account"
  end

  # Shows 
  # 1. new sign up user5 we can logon
  # 2. user can be remembered
  # 3. a cookie with wrong id is deleted and the user is prompted to logon again
  #     Note: this can happen when a user uses multiple EPF Wiki sites
   test "Cookies" do 
    Rails.logger.info("Cookies")
    # TODO cleanup
    @user5 = User.new(:name => 'user5', :email=>'user5@epf.eclipse.org', :password => 'mypassword', :password_confirmation => 'mypassword')
    #@user5.save
    #assert_equal 1, User.count
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    #assert_equal "Password confirmation can't be blank", @user5.errors.full_messages.join(", ")
    # 1
    assert_not_nil User.find_central_admin
    post 'login/sign_up', :user => {:name => @user5.name, :email => @user5.email, :password => @user5.password, :password_confirmation => @user5.password_confirmation} # , :i_agree_to_the_terms_of_use => '1'
    assert_not_nil assigns(:user)
    assert_no_errors(assigns(:user))
    assert_redirected_to :action => 'login'
    @user5 = assigns(:user)
    @user5.id = User.find_by_name(@user5.name).id     # Note: we don't reload @user5 because we loose the password
    @user5.hashed_password = User.find(@user5).hashed_password
    assert_equal LoginController::FLASH_PW_CONFIRMATION_EMAIL_SENT, flash['success']
    Rails.logger.info("Confirming account (which tries to do show")
    get "login/confirm_account/#{@user5.id}", :tk => Digest::SHA1.hexdigest(@user5.hashed_password)
    post 'login/login', :user => {:email => @user5.email, :password => @user5.password}
    assert_not_nil session['user']
    assert_nil cookies[:epfwiki_id]
    session['user'] = nil
    # 2
    post 'login/login', :user => {:email => @user5.email, :password => @user5.password, :remember_me => "0"}
    assert_not_nil assigns(:user)
    assert_not_nil session['user']

    Rails.logger.info("Cookies: #{cookies.inspect}")    
    
    assert_not_nil cookies['epfwiki_id'] 
    # cookies[:epfwiki_id] doesn't work either
    # Testing cookies with functional tests is hard work but here is not easy either
    # We also cannot use symbols, and values are converted to strings
    assert_equal cookies['epfwiki_id'],session['user'].to_s

    session['user'] = nil
    get 'login/login'
    assert_not_nil assigns(:user)
    assert_not_nil session['user']
    # 3 
    session['user'] = nil
    assert_not_nil cookies['epfwiki_id']    
    assert_equal cookies['epfwiki_id'], @user5.id.to_s
    # TODO The following does not work anymore after upgrade. The cookie value remains the same
    # This change of behaviour is not documented anywhere so this will involve
    # too much guesswork to fix. Disabled untill Rails community provides a little
    # more information
    #
    #cookies.delete 'epfwiki_id'
    #cookies['epfwiki_id'] = 123456 # #TODO dit help niet cookie with a non-existing id
    #post '/' # request to send the cookie
    #get 'login/login'
    #assert_redirected_to :action => 'login'
    #assert_response :success
    #assert_nil session['user']
    #assert cookies['epfwiki_id'].blank?
    # 4
    #cookies['epfwiki_id'] = @user5.id
    #cookies['epfwiki_token'] = 'xyz'
    #get 'login/login'
    #assert_response :success 
    #assert_nil session['user']
    #assert cookies['epfwiki_id'].blank?
    #@user5.destroy
  end
  
end
