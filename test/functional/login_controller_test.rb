# All testing of the correct working of cookies is in integration testing because
# cookies don't work as expected with functional tests, see for instance
# http://www.pluitsolutions.com/2006/08/02/rails-functional-test-with-cookie/

require 'test_helper'

class LoginControllerTest < ActionController::TestCase
  
  def setup
    #logger.debug "Test Case: #{name}"  
    @controller = LoginController.new
    #@request    = ActionController::TestRequest.new
    #@response   = ActionController::TestResponse.new
    @emails = ActionMailer::Base::deliveries
    @emails.clear
  end
  
  # Shows we can create the central admin
  test "Signup central admin" do 
    #User.delete_all
    assert User.count == 0
    get :index
    assert_redirected_to :action => 'login'
    get :login
    assert_redirected_to :action => 'new_cadmin'
    get :new_cadmin
    assert_field 'user_name'        
    assert_field 'user_email'   
    assert_field 'user_password'
    assert_field 'user_password_confirmation'
    assert_tag :tag => 'input', :attributes => {:type => 'submit'}    
    assert_tag :tag => 'form', :attributes => {:action => '/login/new_cadmin'} 
    post	:new_cadmin, :user => {:name => 'George Shapiro', :email=> 'george.shapiro@epf.eclipse.org', :password => 'pass2', :password_confirmation => 'pass2'}
    assert_equal LoginController::FLASH_CENTRAL_ADMIN_CREATED, flash['success']
    assert_redirected_to :action => 'login'
  end
  
  # Shows that a user can sign up by supplying name, email, password and password confirmation
  test "Sign up with pw" do
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @emails.clear
    get :sign_up 
    assert_response :success
    assert_field 'user_name'        
    assert_field 'user_email'
    assert_field 'user_password'
    assert_field 'user_password_confirmation'
    assert !ENV['EPFWIKI_DOMAINS'].blank?
    assert_tag :tag => 'select', :attributes => {:name => 'user[email_extension]'}
    post :sign_up, :user => {:name => "user1", :email=>"user1", :email_extension => "@somedomain.com"} # , :i_agree_to_the_terms_of_use => '1'
    assert_errors
    assert_not_nil assigns(:user)
    assert_equal 'Email domain not valid, Password can\'t be blank, Password confirmation can\'t be blank', assigns(:user).errors.full_messages.sort.join(', ')        
    post :sign_up, :user => {:name => "user1", :email=>"user1", :email_extension => "@epf.eclipse.org", :password => 'user1', :password_confirmation => 'user1'} # , :i_agree_to_the_terms_of_use => '1'
    assert_equal 'test.host', @request.host + (@request.port == 80 ? '' : ':' + @request.port.to_s)
    assert_redirected_to :action => 'login'
    assert_equal LoginController::FLASH_PW_CONFIRMATION_EMAIL_SENT, flash['success']
    assert_equal(1, @emails.size)
    email = @emails.first
    assert_equal("[#{ENV['EPFWIKI_APP_NAME']}] Welcome", email.subject)
    assert_equal("user1@epf.eclipse.org", email.to[0])
    assert_equal([ENV['EPFWIKI_REPLY_ADDRESS']], email.from)
    assert_redirected_to :action => 'login'
  end  
  
  # Shows:
  # 1. Request Lost password form
  # 2. Error on wrong email addresses  
  # 3. New password set, email sent with password and token
  # 4. Cannot logon with 'new' password (not activated yet)
  test	"Lost password" do
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @emails.clear
    # 1
    Rails.logger.info("As a user I can access a lost password form")
    get :lost_password
    assert_response :success
    assert_field 'user_email'
    assert_tag :tag => 'form', :attributes => {:action => '/login/lost_password'} 
    # 2
    Rails.logger.info("Email should exist")
    post :lost_password, :user => {:email => 'noneexisting email', :password => 'new_password', :password_confirmation => 'new_password'}
    assert_response :success
    assert_equal LoginController::FLASH_EMAIL_NOT_FOUND, flash['notice']
    # 3
    Rails.logger.info("As a user I can submit lost password form and have a new password sent to me")
    post :lost_password, :user => {:email => 'fooandy.kaufman@epf.eclipse.org'}
    user_by_email = assigns(:user_by_email)
    assert_not_nil user_by_email
    assert_equal LoginController::FLASH_PW_CONFIRMATION_EMAIL_SENT, flash['success']
    assert_equal(1, @emails.size)
    email = @emails.first
    assert_equal("[#{ENV['EPFWIKI_APP_NAME']}] New Password", email.subject)
    assert_equal("fooandy.kaufman@epf.eclipse.org", email.to[0])
    assert_equal([ENV['EPFWIKI_REPLY_ADDRESS']], email.from)
    #assert_match(assigns(:user_by_email).token_new, email.body) # TODO 
    assert_redirected_to :action => 'login'
    @emails.clear
    # 4
    Rails.logger.info("A new password needs to be confirmed")
    post :login, :user => {:email => user_by_email.email, :password => user_by_email.password}
    assert_equal LoginController::FLASH_INVALID_PW, flash['notice']  
  end
  
end
