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

class SitesController < ApplicationController
  
  layout 'management'
  
  protect_from_forgery :except => [:schedule_update, :update_cancel, :update_now, :csv, :obsolete]
  
  before_filter :authenticate
  before_filter :authenticate_admin, :only => [:csv, :new, :compare, :new_wiki, :create, :schedule_update, :upload, :edit, :update_now, :obsolete, :update_cancel]
  before_filter :authenticate_cadmin, :only => [:scan4content]
  
  cache_sweeper :sweeper, :only => [:schedule_update, :update_cancel, :update_now, :new, :new_wiki]
  
  #verify :method => :post, :only => [:update, :update_cancel, :update_now, :obsolete, :csv],:add_flash => {'error' => Utils::FLASH_USE_POST_NOT_GET}, :redirect_to => { :controller => 'other', :action => 'error' }  
  
  FLASH_WIKI_SITE_CREATED = 'An empty Wiki site has been created. Now you can schedule a job to update the Wiki with a Baseline Process'  
  FLASH_WIKI_UPDATE_SUCCESS  = 'The Wiki is being updated. You will be notified via email when it is done.'
  
  # TODO In the console when running built-in server the message ERROR Errno::EINVAL: Invalid argument is displayed
  def index
    list
    render :action => 'list'
  end
  
  def list
    @baseline_processes = BaselineProcess.find(:all)
    @wikis = Wiki.find(:all)
    @pages_count = Page.count(:group => :site_id) # {1=>26, 2=>26}
    @versions_count = Version.count(:group => :wiki_id, :conditions => ['baseline_process_id is null'])
    @comments_count = Comment.count(:group => :site_id)
  end
  
  # Action #new creates a BaselineProcess. A BaselineProcess is created from content in a server folder 
  # (that you uploaded with FTP or a folder share or something) or from a zip file submitted with the form
  def new
    @baseline_processes = BaselineProcess.find(:all, :conditions => ['obsolete_on is null'])
    @folders = BaselineProcess.unused_folders
    if request.get?
      @site = Site.new
      flash['notice'] =  "<p>Although you can upload zip files with EPFC published sites here, it is recommended to upload content using some other means (FTP, SCP).  You need to upload to the location #{ENV['EPFWIKI_ROOT_DIR']}#{ENV['EPFWIKI_PUBLIC_FOLDER']}/#{ENV['EPFWIKI_SITES_FOLDER']}. Server folder created there can be used to create a new Baseline Process.</p>"
      flash['notice'] += "<p>It is also recommended to use version info or baseline info in your zip file names. The name is used to derive other attributes (server folder and title). Example: oup_20060721.zip</p>"
    else
      logger.info("Creating a new Baseline Process with params #{params.inspect}")
      if params[:site][:file].nil?
        logger.info("Creating a new Baseline Process from server folder")
        @site = BaselineProcess.new(params[:site].merge(:user => session_user))       
      else  
        logger.info("Creating a new Baseline Process using zip")
        @site = BaselineProcess.new_from_upload(params[:site].merge(:user => session_user))        
      end
      if @site.errors.empty? && @site.save
        flash['success'] = Utils::FLASH_RECORD_CREATED 
        redirect_to :action => 'list'
      end
    end
  end
  
  def create
    raise "We hebben geen create, alleen een new"
  end
  
  # Action #new_wiki creates a new Wiki. The typical next step is to schedule an #update to add content to this empty Wiki
  def new_wiki
    if request.get?
      @wiki = Wiki.new
    else
      @wiki = Wiki.new(params[:wiki].merge(:user => session_user))
      if  @wiki.save
        flash['success'] = FLASH_WIKI_SITE_CREATED
        redirect_to :action => 'description', :id => @wiki.id
      end
    end
  end

  # Action #update schedules an update. The actual update is typically performed
  # with a job ('job_daily') but could also be forced by #update_now
  def schedule_update
    site = Site.find(params[:id])
    bp = BaselineProcess.find(params[:baseline_process_id])
    u = Update.new(:user => session_user, :wiki => site, :baseline_process => bp)
    u.save!
    flash['success'] = "Update of #{site.title} to #{u.baseline_process.title} scheduled"
    redirect_to :action => 'description', :id => site.id
  end
  
  # Action #update_cancel to cancel an scheduled updated
  def update_cancel
    site = Site.find(params[:id])
    u = Update.find(params[:update_id])
    u.destroy
    flash['success'] = "Cancelled update of #{site.title} to #{u.baseline_process.title}"
    redirect_to :action => 'description', :id => site.id
  end
  
  # action #update_now allows the administrator to do the update immediately, see also #update_wiki 
  def update_now
    u = Update.find(params[:update_id])
    if Rails.env == 'test' # testability in sites_controller_test
      u.do_update
    else
      Spawn.new(:argv => "spawn-update #{params[:update_id]}") do
        u.do_update
      end
    end
    flash['success'] = FLASH_WIKI_UPDATE_SUCCESS            
    redirect_to :action => 'description', :id => u.wiki.id
  end
  
  def description
    @site = Site.find(params[:id])
  end

  def versions
    @site = Site.find(params[:id])
    logger.debug("params.inspect: #{params.inspect}")
    @filter = UserVersion.new(params[:filter]) # done is default 'N'
    @filter.type_filter = 'UserVersion' if @filter.type_filter.blank?
    logger.debug("@filter: #{@filter.inspect}")
    case @filter.done + @filter.type_filter
    when 'NAll' 
	cond = ['wiki_id = ? and done = ?', @site.id, 'N',] # default 
    when 'AllUserVersion' 
	cond = ['wiki_id = ? and type = ?', @site.id, 'UserVersion' ] # all userversions
    when 'AllAll' 
	cond = ['wiki_id = ?', @site.id] # all versions
    when 'NUserVersion' 
	cond = ['wiki_id = ? and done = ? and type = ?', @site.id, 'N', 'UserVersion' ] # all todo userversions      
    end
    logger.debug("cond: #{cond.inspect}")
    @versions = Version.where(cond).order("created_on DESC").paginate(:per_page => Rails.application.config.per_page, 
      :page => params[:page])
    render :action => 'description'
  end
 
  def pages
    @site = Site.find(params[:id])
    cond = ['site_id=?', @site.id]
    @pages = Page.where(cond).paginate(:per_page => Rails.application.config.per_page,
      :page => params[:page])  
    render :action => 'description'
  end
  
  def comments
    @site = Site.find(params[:id])
    #logger.debug("params.inspect: #{params.inspect}")
    @filter = Comment.new(params[:filter]) # done is default 'N'
    cond = ['site_id = ?', @site.id ] 
    cond = ['site_id = ? and done = ?', @site.id, 'N' ] if @filter.done == 'N' 
    #@uploads = Upload.order("created_on DESC").paginate(:per_page => 10, :page => params[:page]) # Rails 3 preferred way
    #end
    @comments = Comment.where(cond).order("created_on DESC").paginate(:per_page => Rails.application.config.per_page, 
      :page => params[:page])
    #@comment_pages, @comments = paginate :comment, :per_page => 25, :order => 'created_on DESC', :conditions => cond
    render :action => 'description'
  end
  
  def uploads
    @site = Site.find(params[:id])
    @uploads = Upload.order("created_on DESC").paginate(:per_page => Rails.application.config.per_page,
    :page => params[:page]) 
    render :action => 'description'
  end
 
  def feedback
    @site = Site.find(params[:id])
    @feedbacks = Feedback.order("created_on DESC").paginate(:per_page => Rails.application.config.per_page,
      :page => params[:page])
    #end
    #@feedback_pages, @feedbacks = paginate :feedbacks, :order => 'created_on DESC',  :per_page => 25
    render :action => 'description'
  end
 
  def edit
    @site = Site.find(params[:id])
    if request.get?
      flash.now['warning'] = 'Updating the folder here won\'t update the file system. If you want to change the folder you will have to rename the folder manually on the filesystem' 
    else 
      @site = Site.find(params[:id])
      if @site.update_attributes(params[:site])
        flash['success'] = 'Site was successfully updated.'
        redirect_to :action => 'description', :id => @site
      else
        render :action => 'edit'
      end
    end
  end
  
  def obsolete
    if request.post?
     site = Site.find(params[:id])
      site.obsolete_by = session_user.id 
      if site.obsolete_on.nil?
	site.obsolete_on = Time.now
	flash.now['success'] = "#{site.title} succesfully made obsolete"
      else
	site.obsolete_on = nil
	flash.now['success'] = "#{site.title} is no longer obsolete"      
      end
      site.save!
      list
      render :action => 'list'
    else
      flash['error'] = Utils::FLASH_USE_POST_NOT_GET
      redirect_to :controller => 'other', :action => 'error'
    end
  end
  
  def csv
    site = Site.find(params[:id])
    content_type = if request.user_agent =~ /windows/i
      'application/vnd.ms-excel'
    else
      'text/csv'
    end
    site.export_csv if !File.exists?(site.path + '.csv')
    send_data(IO.readlines(site.path + '.csv').join, :type => content_type, :filename => site.folder + '.csv')
  end
  
end
