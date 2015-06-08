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

class Notifier < ActionMailer::Base

  default :from => ENV['EPFWIKI_REPLY_ADDRESS']
  
  def welcome_pw_confirmationlink(user, request_host = ENV['EPFWIKI_BASE_URL'])
    @recipients = user.email
    @from = ENV['EPFWIKI_REPLY_ADDRESS']
    @subject =  "[" + ENV['EPFWIKI_APP_NAME'] + "] Welcome" 
    @user = user
    @cadmin = User.find_central_admin
    @subject = @subject
    @request_host = request_host
    mail(:to => @recipients, :subject =>  @subject, :content_type => 'text/html')
  end
  
  def lost_password(user, urls)
    @recipients = user.email
    @from = ENV['EPFWIKI_REPLY_ADDRESS']
    @subject = "[" + ENV['EPFWIKI_APP_NAME'] + "] New Password"
    @user = user
    @admin = User.find_central_admin
    @cnt = User.count
    @urls = urls
    mail(:to => @recipients, :subject =>  @subject, :content_type => 'text/html')
  end

  def error_report(exception, trace, session, params, env, sent_on = Time.now)
    logger.info("Sending error report")
    ca = User.find_central_admin
    if ca
      @recipients         = ca.email
    else
      @recipients         = ENV['EPFWIKI_ADMIN_EMAIL']
    end
    @from               = ENV['EPFWIKI_REPLY_ADDRESS']
    @subject            = "[Error] exception in #{env['REQUEST_URI']}" 
    @sent_on            = sent_on
    @exception  = exception
    @trace      = trace
    @session    = session
    @params     = params
    @env        = env
    mail(:to => @recipients, :subject =>  @subject, :content_type => 'text/html')
  end
  
  #def summary(params, runtime = Time.now, report = nil)
  def summary(rep)
    @bcc = Utils.email_addresses_4_report(rep.users)
    #@bcc = Utils.email_addresses_4_report(params[:user]) unless params[:user].blank?
    @wikis = []
    rep.items.each do |item|
      logger.debug("item: #{item.inspect}")
      w = nil
      case item.class.name
      when Comment.name then w = item.site
      when Wiki.name then w = item
      when Update.name then w = item.wiki
      when Checkout.name then w = item.site
      when Version.name then w = item.wiki
      end
      @wikis << w if !w.nil?
    end
    @wikis = @wikis.uniq    
    @report = rep
    @from = ENV['EPFWIKI_REPLY_ADDRESS']
    @subject2 = rep.subject # @subject cannot be used, will always be nil in the view
    @sent_on = Time.now
    @contributions = rep.items
    @cadmin = User.find_central_admin
    @host = ENV['EPFWIKI_BASE_URL']
    mail(:bcc => @bcc, :subject =>  @report.subject, :content_type => "text/html")
  end 

  def env_to(user, session, params, env, sent_on = Time.now)
    content_type "text/html" 
    @recipients         = user.email
    @from               = ENV['EPFWIKI_REPLY_ADDRESS']
    @subject            = "[" + ENV['EPFWIKI_APP_NAME'] + "] " + params[:action]
    @sent_on            = sent_on
    @session    = session
    @params     = params
    @env        = env
  end
  
  def site_status(update, s)
    @cadmin = User.find_central_admin
    @update = update
    @s = s
    mail(:cc => @cadmin.email, :to => update.user.email, :subject =>  "[#{ENV['EPFWIKI_APP_NAME']}] #{s}", :content_type => 'text/html')
  end
  
  def notification(theUsers, subject, introduction, text)
    @link = "<a href=\"#{ENV['EPFWIKI_BASE_URL']}/users/account\">#{ENV['EPFWIKI_APP_NAME']}</a>"
    @introduction = introduction
    @text = text
    @cadmin = User.find_central_admin
    mail(:bcc => Utils.email_addresses_4_report(theUsers), :subject => "[#{ENV['EPFWIKI_APP_NAME']}] #{subject}", :content_type => "text/html") do |format|
      format.html
      #format.text
    end
  end
  
  # TODO replace with notification
  def email(theUsers, theSubject, theFilePaths, theText, cc = nil)
    @from = ENV['EPFWIKI_REPLY_ADDRESS']
    @cc = Utils.email_addresses_4_report(cc) unless cc.nil?
    @subject = "[" + ENV['EPFWIKI_APP_NAME'] + "] " + theSubject
    @recipients = Utils.email_addresses_4_report(theUsers)
    @text = theText
    @admin = User.find_central_admin
    mail(:cc => @admin.email, :to => @recipients, :subject =>  @subject, :content_type => 'text/html')
    #for filePath  in theFilePaths # TODO enable
    #  attachment :content_type => "application/zip",   :body => File.open(filePath, "rb") {|io| io.read}, :filename => filePath.split("/").last
    #end
  end
  
  def contributions_processed(user, contributions)
    @recipients = Utils.email_addresses_4_report(user)
    @contributions = contributions
    @cadmin = User.find_central_admin
    @user = user
    @from = ENV['EPFWIKI_REPLY_ADDRESS']
    @bcc = Utils.email_addresses_4_report(@cadmin)
    @subject = "[#{ENV['EPFWIKI_APP_NAME']}] Your contribution has been processed"   
    mail(:cc => @cadmin.email, :to => @recipients, :subject =>  @subject, :content_type => 'text/html') 
  end
  
  def authorisation_problem(user, session, params, env)
    user = User.new(:name => 'Unknown', :email => 'Unknown') if user.nil?
    @cadmin     = User.find_central_admin 
    @recipients         = Utils.email_addresses_4_report(@cadmin)
    @from               = ENV['EPFWIKI_REPLY_ADDRESS']
    @subject            = "[#{ENV['EPFWIKI_APP_NAME']}] Autorisation Problem Detected"
    @session    = session
    @params     = params
    @env        = env
    @subject    = @subject
    @user       = user
    mail(:cc => @cadmin.email, :to => @recipients, :subject =>  @subject, :content_type => 'text/html')
  end
  
  def feedback(feedback) # TODO implement test
    @cadmin     = User.find_central_admin 
    @recipients         = Utils.email_addresses_4_report(@cadmin)
    @from               = ENV['EPFWIKI_REPLY_ADDRESS']
    @subject            = "[#{ENV['EPFWIKI_APP_NAME']}] Feedback Posted"
    @subject    = @subject
    @feedback   = feedback
    @anywiki    = Wiki.find(:first, :conditions => ['obsolete_on is null'])
    mail(:cc => @cadmin.email, :to => @recipients, :subject =>  @subject, :content_type => 'text/html')
  end

end
