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

require 'open-uri'

class PortalController < ApplicationController

  before_filter :sidebar
  
  caches_page :home, :about, :archives, :wikis, :users, :privacypolicy, :termsofuse
  
  layout 'portal'

  # See also #RssController.index
  def home
    if User.count > 0
      @cadmin = User.find_central_admin
      #@versions = Version.find(:all, :order => 'created_on DESC', :conditions => ['version <> 0 and created_on > ?',Time.now - 1.month])
      @versions = Version.find(:all, :order => 'created_on DESC', :conditions => ['baseline_process_id is null and version is not null'], :limit => 15)
      #@comments = Comment.find(:all, :order => 'created_on DESC', :conditions => ['created_on > ?',Time.now - 1.month])
      @comments = Comment.find(:all, :order => 'created_on DESC', :limit => 15)
      @templates = Site.templates
      @uploads = Upload.find(:all, :order => 'created_on DESC', :limit => 15)
      @pages = WikiPage.find(:all, :order => 'created_on DESC', :limit => 15, :conditions => ['tool = ?', 'Wiki'])
      @welcome = AdminMessage.text('Welcome')
      @tabitems = []
      @tabitems << {:text => "Discussion", :id => 'discussion'} 
      @tabitems << {:text => "Changes", :id => 'changes'} 
      @tabitems << {:text => "Uploads", :id => 'uploads'} 
      @tabitems << {:text => "Pages", :id => 'pages'} 
    else
      redirect_to :controller => 'login'
    end
  end  

  def wikis
    @wikis = Wiki.find(:all, :conditions => ['obsolete_on is null'])
  end
  
  def users
    version_counts = UserVersion.count(:group => 'user_id')
    comment_counts = Comment.count(:group => 'user_id')
    upload_counts = Upload.count(:group => 'user_id')
    new_page_counts = WikiPage.count(:group => 'user_id', :conditions => ['tool=?','Wiki'])
    @contributors = []
    User.find(:all).each do |user|
      version_count = 0
      comment_count = 0
      upload_count = 0
      new_page_count = 0
      count = 0
      version_count = version_counts.assoc(user.id)[1] unless version_counts.assoc(user.id).nil?
      comment_count = comment_counts.assoc(user.id)[1] unless comment_counts.assoc(user.id).nil?      
      upload_count = upload_counts.assoc(user.id)[1] unless upload_counts.assoc(user.id).nil?
      new_page_count = new_page_counts.assoc(user.id)[1] unless new_page_counts.assoc(user.id).nil?
      count = version_count + comment_count + upload_count + new_page_count
      @contributors << {:user => user, :version_count => version_count, :comment_count => comment_count, :upload_count => upload_count, :new_page_count => new_page_count, :count => count}
    end
    @contributors = @contributors.sort_by {|c|-c[:count]}
  end

  def about
    @about = AdminMessage.text('About')
  end 
  


  def archives
    @cadmin = User.find_central_admin
    @year = params[:year]
    @month = params[:month]
    month_start = Time.gm(@year, @month)
    month_end = month_start.at_end_of_month
    logger.debug("Versions for archives #{['version <> 0 and created_on >= ? and created_on < ?', month_start, month_end].inspect}")
    @versions = UserVersion.find(:all, :order => 'created_on ASC', :conditions => ['created_on >= ? and created_on < ?',month_start, month_end])
    @comments = Comment.find(:all, :order => 'created_on ASC', :conditions => ['created_on >= ? and created_on < ?',month_start, month_end])
    @uploads = Upload.find(:all, :order => 'created_on ASC', :conditions => ['created_on >= ? and created_on < ?',month_start, month_end])
    @updates = Update.find(:all, :order => 'created_on ASC', :conditions => ['created_on >= ? and created_on < ?',month_start, month_end])
    @pages = WikiPage.find(:all, :order => 'created_on ASC', :conditions => ['created_on >= ? and created_on < ? and tool = ?',month_start, month_end, 'Wiki'])    
    @tabitems = []
    @tabitems << {:text => "Discussion (#{@comments.size.to_s})", :id => 'discussion'} 
    @tabitems << {:text => "Changes (#{@versions.size.to_s})", :id => 'changes'} 
    @tabitems << {:text => "Uploads (#{@uploads.size.to_s})", :id => 'uploads'} 
    @tabitems << {:text => "Updates (#{@updates.size.to_s})", :id => 'updates'} 
    @tabitems << {:text => "Pages (#{@pages.size.to_s})", :id => 'pages'}     
  end
  
  def feedback
    @help = AdminMessage.text('Help')
    if request.get?
      @feedback = Feedback.new
    else  
      @feedback = Feedback.new(params[:feedback].merge(:user => session_user))
      if @feedback.save
        Notifier.feedback(@feedback).deliver
        flash['success'] = "Your feedback or question was succesfully sent. Thanks for your interest in #{ENV['EPFWIKI_APP_NAME']}!"
        redirect_to '/'
      end
    end
  end
  
  def privacypolicy
    render :inline => "<% @heading = 'Privacy Policy'  %><h2>Privacy Policy</h2><%= raw @privacypolicy %>", :layout => 'portal'
  end
  
  def termsofuse
    render :inline => "<% @heading = 'Terms of Use' %><h2>Terms of Use</h2><%= raw @termsofuse %>", :layout => 'portal'
  end
  
  #######
  private
  #######
  
  def sidebar
    @privacypolicy = AdminMessage.text('Privacy Policy')
    @termsofuse = AdminMessage.text('Terms of Use')    
    @wikis = Wiki.find(:all, :conditions => ['obsolete_on is null and baseline_process_id is not null'])
    @updates_sidebar = Update.find(:all, :order => 'created_on ASC', :conditions => ['finished_on > ? and finished_on is not null and started_on is not null',Time.now - 14.days])
    @checkouts = Checkout.find(:all, :order => 'created_on DESC')
    version_counts = UserVersion.count(:group => 'month(created_on)', :conditions => ['year(created_on)=?', Time.now.year])
    comment_counts = Comment.count(:group => 'month(created_on)', :conditions => ['year(created_on)=?', Time.now.year])
    upload_counts = Upload.count(:group => 'month(created_on)', :conditions => ['year(created_on)=?', Time.now.year])
    logger.debug([version_counts, comment_counts, upload_counts].inspect)
    @archives_count = []
    for i in 1..12
      cnt = 0
      [comment_counts.assoc(i.to_s), upload_counts.assoc(i.to_s), version_counts.assoc(i.to_s)].each {|c|  cnt += c[1] unless c.nil? } #cnt += c unless c.nil?
      @archives_count << [i, cnt] if cnt > 0
    end
    @monthly_top = User.find(:all).collect {|u|[u, Version.count(:conditions => ['user_id = ? and baseline_process_id is null and created_on > ?',u.id, Time.now - 1.month]) + u.comments.count(:conditions => ['created_on > ?', Time.now - 1.month]) + u.uploads.count(:conditions => ['created_on > ?', Time.now - 1.month])]}
    @monthly_top = @monthly_top.sort_by{|t|-t[1]}
    @overall_top = User.find(:all).collect {|u|[u, Version.count(:conditions => ['user_id = ? and baseline_process_id is null',u.id]) + u.comments.count + u.uploads.count]}
    @overall_top = @overall_top.sort_by{|t|-t[1]}
    @overall_top = @overall_top[0..14]
    @monthly_top = @monthly_top[0..14]
  end 
 
end
