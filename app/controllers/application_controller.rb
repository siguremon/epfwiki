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

# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base

  protect_from_forgery

  # http://mrchrisadams.tumblr.com/post/333036266/catching-errors-in-rails-with-rescue-from
  # http://techoctave.com/c7/posts/36-rails-3-0-rescue-from-routing-error-solution
  #rescue_from ActionController::RoutingError, :with => :render_404
  
  rescue_from Exception, :with => :render_exception unless ENV['EPFWIKI_RESCUE_FROM_EXCEPTION'] == 'N'
  
  #########
  protected   
  #########


  def user?
    if session and session['user']
      true
    else
      false
    end
  end

  def admin?
    if user? and session_user.admin?
      true
    else
      false
    end
  end

  def cadmin?
    if user? and session_user.cadmin?
      true
    else
      false
    end
  end

  def mine?(obj)
    if obj.class.name == User.name
      obj.id == session_user.id
    else
      obj.user_id == session_user.id
    end
  end
  
  #def log_error(exception) #:doc:
  #  super(exception)
  #  begin
      # ENHANCEMENT don't send error email when action error causes an error 
  #    Notifier.deliver_error_report(exception, clean_backtrace(exception), 
  #    session.instance_variable_get("@data"), 
  #    params, 
  #   request.env)
  #  rescue => e
  #    logger.error(e)
  #  end
  #end
  

  
  # instead of an error stack we want to display a nice user friendly error message
  #def local_request? #:doc:
  #  false
  #end
  
  # The #authenticate method is used as a <tt>before_hook</tt> in
  # controllers that require the user to be authenticated. If the
  # session does not contain a valid user, the method
  # redirects to the LoginController.login.
  #-- 
  # ENHANCEMENT to have caching of pages per user group add something like :params => params.merge( :utype=> 'admin' ) 
  #++
  def authenticate #:doc:
    unless session['user']
      logger.debug('No session, redirecting to login')
      session['return_to'] = request.fullpath
      redirect_to :controller => 'login' 
      return false
    end
  end
  
  def authenticate_admin #:doc:
    logger.debug("Authenticate admin #{session['user']}")
    if !admin?
      logger.debug("User not authenticated as admin")
      flash['notice'] = 'Administrators privileges are required to access this function'
      flash['error'] = LoginController::FLASH_UNOT_ADMIN # TODO should be flash.now?
      Notifier.authorisation_problem(session_user, session.instance_variable_get("@data"), params, request.env).deliver
      redirect_to :controller => 'other', :action => 'error'
      return false        
    end
  end
  
  def authenticate_cadmin #:doc:
    unless session and session['user'] and session_user.cadmin?
      flash['notice'] = 'You need to be the central administrator to access this function'
      flash['error'] = LoginController::FLASH_UNOT_CADMIN
      Notifier.authorisation_problem(session_user, session.instance_variable_get("@data"), params, request.env).deliver
      redirect_to :controller => 'other', :action => 'error'
      return false
    end
  end
  
  def create_cookie(theUser)
    cookies[:epfwiki_id] = {:value => theUser.id.to_s, :expires => Time.now+31536000}
    cookies[:epfwiki_token] = {:value => Utils.hash_pw(theUser.hashed_password),:expires => Time.now+31536000}
  end
  
  def expire_cookie
    cookies.delete :epfwiki_id
    cookies.delete :epfwiki_token
  end
  
  def session_user
    User.find(session['user']) if session and session['user']
  end
  
  # See pages controller and search controller
  def searcher
    respond_to do |format|
      format.js {
        with = {}
        if @wiki # if defined, search only in this site
          params[:site] = @wiki.id.to_s
        end
        ['site','type'].each do |filter|
          if params[filter]
            with[filter] = params[filter]
          end
        end 
        #binding.pry
        @pages = Page.search params[:text], :with => with, :page => params[:page], :per_page => Rails.application.config.per_page
      }
      format.html {
        @wikis = Wiki.order('title ASC')
        @baselines = BaselineProcess.where(:obsolete_on => nil).order('title ASC')
        @types = UmaType.order('name ASC')
      } 
    end
  end
  
  #######
  private
  #######
  
  def render_exception(exception = nil)
    
    flash['notice'] = case exception
    when ThinkingSphinx::ConnectionError
      "We\'re sorry, the search engine Sphinx is not running or could not be reached. We\'ve been notified about this issue and we\'ll take a look at it shortly."
    else
      "We\'re sorry, but something went wrong. We\'ve been notified about this issue and we\'ll take a look at it shortly."
    end
    flash['error'] = exception.message

    if Rails.env == 'development'
      flash['error'] = "<p>" + exception.message + "</p><p>" + Rails.backtrace_cleaner.clean(exception.backtrace).join("<br/>") + "</p>"
    end

    Rails.backtrace_cleaner.clean(exception.backtrace)

    Notifier.error_report(exception, Rails.backtrace_cleaner.clean(exception.backtrace),
      session.instance_variable_get("@data"),
      params,
      request.env).deliver
    logger.error(flash['error'])  
    if request.xhr? # TODO does not work anymore?
      render js: "alert('Something went wrong. We have been notified about this issue and we will take a look at it shortly. The error message is: #{exception.message}.');"
    else  
      redirect_to :controller => 'other', :action => 'error'
    end

  end
  
end
