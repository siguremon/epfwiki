class LoginController < ApplicationController
  
  layout 'management'
  
  before_filter :authenticate, :except => [:index, :sign_up2, :sign_up, :login, :lost_password, :new_cadmin,
  :confirm_account, :report_password_reset_attempt, :auto_complete_for_user_email, :resend]
  before_filter :authenticate_admin, :only => [:resend]
  
  FLASH_CENTRAL_ADMIN_ALREADY_CREATED = 'You can only create the central admin if this user has not been created yet!'
  FLASH_INVALID_PW = 'Invalid combination of username password!'
  FLASH_NO_VALID_TOKEN = 'Not a valid token!'
  FLASH_PASSWORD_ACTIVATED  = 'New password activated!'
  FLASH_LOST_PASSWORD_ABUSE = 'A notification was sent to the administrator reporting the abuse of your email address'
  FLASH_CENTRAL_ADMIN_CREATED = 'Central admin user created!' 
  FLASH_PW_CONFIRMATION_EMAIL_SENT = 'A confirmation email has been sent to your email address. Please confirm your account by clicking on the hyperlink in this email'
  FLASH_EMAIL_NOT_FOUND = 'Email address not found!'
  FLASH_UNOT_ADMIN = "You are not an admin user!"
  FLASH_UNOT_CADMIN = "You are not the central administrator!"
  
  # Is be used to create the first user, the central admin account
  def new_cadmin
    if  User.count > 0
      flash['error'] = FLASH_CENTRAL_ADMIN_ALREADY_CREATED
      redirect_to :action => 'login'
    else
      if request.get?
        @user = User.new      
      else
        @user = User.new_cadmin(params[:user])
        if  @user.save
          flash['success'] = FLASH_CENTRAL_ADMIN_CREATED
          redirect_to :action => 'login'
        else
          render :action => 'new_cadmin'
        end
      end
    end
  end
  
  # Action #sign_up creates the account or displays the form to create the account.
  # Passwords can be generated or supplied by the user. 
  # If passwords are supplied by the user the account needs to be confirmed, 
  # see #confirm_account
  def sign_up
    if request.get?
      @user = User.new
    else
      @user = User.new_signup(params[:user])
      if @user.save
        flash['success'] =  FLASH_PW_CONFIRMATION_EMAIL_SENT
        Notifier.welcome_pw_confirmationlink(@user, ENV['EPFWIKI_BASE_URL']).deliver
        redirect_to :action => "login" 
      else
        logger.info("Failed to save user on signup #{@user.inspect}")
        @user.email = @user.email.gsub(@user.email_extension,"") if @user.email && @user.email_extension
        @user.password = ""
        @user.password_confirmation = ""
      end
    end
  end
  
  # Action #confirm_account is used to confirm a new password send by email. Without confirmation anyone could reset passwords. 
  # The token used for confirmation is just the new password hashed twice. The new password is stored in the column <tt>confirmation_token</tt>.
  # Action #resend_password is used to request a new password. 
  def confirm_account
    logger.info("In LoginController.confirm_account")
    @user = User.find(params[:id])
    if  @user.confirm_account(params[:tk])
      if  @user.save
        flash['success'] = FLASH_PASSWORD_ACTIVATED 
      else
        raise "Failed to activate account for #{@user.email}"
      end
    else
      flash['error'] = FLASH_NO_VALID_TOKEN
    end
    redirect_to :action => 'login'
  end
  
  # Action #change_password allows a user to change the password 
  #-- 
  # ENHANCEMENT security enhancement: require the old password
  # TODO Like to use flash.now here but functional tests will fail! Is a bug?
  #++
  def  change_password
    @user= User.find(session['user'])
    if  request.get?
    else
      @user.errors.add(:password, "Can't be blank") if params[:user][:password].blank? # blank? returns true if its receiver is nil or an empty string
      @user.change_password(User.new(params[:user]))
      if  @user.save
        flash['success'] = 'Password was succesfully changed'
      else
        @user= User.find(session['user'])
      end
    end
  end
  
  def     index
    redirect_to :action => 'login'
  end
  
  # Generate a new password for a user and sends it in a email. 
  # The new password is activated after the user confirms it. The old passwords remains
  # active, otherwise any user can disable accounts!
  def lost_password
    if  request.get?
      @user = User.new
    else
      @user = User.new(params[:user])
      logger.info('Finding user with email: ' + @user.email.downcase)
      @user_by_email = User.find_by_email(@user.email.downcase)
      if @user_by_email
        @user_by_email.password = @user.password
        @user_by_email.password_confirmation = @user.password_confirmation
        if @user_by_email.valid?
          @user_by_email.set_new_pw(@user_by_email.password)
          if  @user_by_email.save
            urls = [url_for(:controller => 'login', :action => 'confirm_account', :id => @user_by_email.id, :tk => @user_by_email.token_new)]
            Notifier.lost_password(@user_by_email, urls).deliver
            flash['success'] = FLASH_PW_CONFIRMATION_EMAIL_SENT
            redirect_to :action => "login"
          end
        else
        end
      else
        @user.email = ""
        flash['notice'] = FLASH_EMAIL_NOT_FOUND
      end
    end
  end
  
  # Action #login checks if there is a cookie. With 'posts' we try to login using User.try_to_login. If the user 
  # wants to be remembered a cookie is created. 'Gets' can login the user if the user has a good cookie.
  def login
    @wikis = Wiki.find(:all, :conditions => ['obsolete_on is null'])
    @login_message = AdminMessage.text('Login')    
    if request.get?
      if  cookies[:epfwiki_id] && User.exists?(cookies[:epfwiki_id])
        logger.info("Found cookie and user with id " + cookies[:epfwiki_id])
        @user = User.find(cookies[:epfwiki_id])         
        token = cookies[:epfwiki_token]
        if @user.confirm_account(token)
          logger.info("Token good, refresh cookies and login user")
          create_cookie(@user) # refresh van cookie
          @user.update_attributes({:http_user_agent => request.env['HTTP_USER_AGENT'], :ip_address => request.env['REMOTE_ADDR'] , :last_logon => Time.now, :logon_count => @user.logon_count + 1, :logon_using_cookie_count => @user.logon_using_cookie_count + 1})
          session['user'] = @user.id
          redirect2page
        else
          logger.info("An account was found but the token was not correct #{request.env.inspect}")        
          expire_cookie
          session['user'] = nil
          @user = User.new
        end
      else
        logger.debug("Cookie not found, or user not found with id in cookie: #{cookies.inspect}, cookies['epfwiki_id']: #{cookies['epfwiki_id']}, User.exists?(cookies[:epfwiki_id]): #{User.exists?(cookies[:epfwiki_id])}")
        expire_cookie # if it exists, it is invalid
        @cadmin = User.find_central_admin
        if  @cadmin
		  logger.debug('Cadmin found, displaying the login form')
          session['user'] = nil
          @user = User.new
        else
          logger.debug('Cadmin not found, displaying form to create cadmin user')
          redirect_to :action => 'new_cadmin'
        end
      end
    else
      @user = User.new(params[:user])
      @logged_in_user = @user.try_to_login
      if @logged_in_user
        logger.info("Login succesfull")
        session['user'] = @logged_in_user.id
        if @user.remember_me == "0" # remember_me = 0, do not remember_me is 1
          create_cookie(@logged_in_user)
        end
        @logged_in_user.update_attributes({:http_user_agent => request.env['HTTP_USER_AGENT'], :ip_address => request.env['REMOTE_ADDR'] , :last_logon => Time.now, :logon_count => @logged_in_user.logon_count + 1})
        redirect2page
      else
        @user = User.new
        flash['notice'] = FLASH_INVALID_PW
        logger.info("Invalid combination of username password for #{@user.email}")
      end
    end
  end
  
  # destroy the session and cookie redirect to #login
  def logout
    session['user'] = nil
    flash[:notice] = "Logged out"
    redirect_to :action => "login"
    expire_cookie
  end
  
  def redirect2page
    if session["return_to"]
      redirect_to(session["return_to"])
      session["return_to"] = nil
    else
      redirect_to :controller => "users", :action => "account"
    end
  end
  
  def auto_complete_for_user_email
    search = params[:user][:email]
    logger.debug("search:" + search)
    @users = User.find(:all, :conditions => ["email like ?", search + "%"], :order => "email ASC") unless search.blank?
    if @users.length == 1
      render :inline => "<ul class=\"autocomplete_list\"><li class=\"autocomplete_item\"><%= @users[0].email %></li></ul>" 
    else
      render :inline => "<ul class=\"autocomplete_list\"></ul>"
    end
  end

end
