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

class PagesController < ApplicationController
  
  before_filter :authenticate, :except => [:view, :search]
  before_filter :authenticate_cadmin, :only => [:destroy]
  
  caches_page :view
  
  #--
  # TODO check that we really need this
  #++
  cache_sweeper :sweeper, :only => [:checkout, :checkin, :undocheckout, :destroy, :discussion]
  
  layout 'wiki'
  
  FLASH_CHECKIN_SUCCESS = "Check-in succesfull, please add or update the version note!"

  def view
    logger.debug("params[:url]:" + params[:url])
    parts = params[:url].sub(ENV['EPFWIKI_BASE_URL'] + '/', '').split('?').first.split('/') # url sometimes contains a parameter! 
    @wiki = Wiki.find_by_folder(parts.shift(2).second) # first part is folder that contains the Wiki sites, the second part is the Wiki folder
    @rel_path = parts.join('/') # rel path is parts that remain
    @page = WikiPage.find_by_rel_path_and_site_id(@rel_path, @wiki.id)
    if @page
      logger.debug("Page found")
      @version = @page.current_version 
      @comments = Comment.find(:all, :conditions => ["page_id=? and site_id=?", @page.id, @wiki.id], :order => 'created_on ASC') 
      @checkout = @page.checkout
      logger.debug("@version: #{@version.inspect}")
      @contributor_names = @page.contributors
    else
      logger.error("Page not found with @rel_path #{@rel_path} and @wiki.id #{@wiki.id}")
    end

    @checkout_text = "This page is currently being created or modified by #{@checkout.user.name}" if @checkout and @version
     
    respond_to do |format|
      format.js 
    end
  end

  def discussion
    if request.get?
      @wiki = Wiki.find_by_folder(params[:site_folder]) 
      @page = Page.find(params[:id])
      @comment = Comment.new(:site => @wiki, :page => @page) 
    else
      @comment = Comment.new(params[:comment].merge(:user => session_user))
      @page = @comment.page
      @wiki = @page.site 
      @comment.version = @page.current_version
      if @comment.save
        redirect_to :controller => 'pages', :site_folder => @wiki.folder, :id => @page.id, :action => 'discussion'
        users = (User.find(:all, :conditions => ['notify_immediate=?', 1]) + Notification.find_all_users(@page, Page.name)).uniq
        users += Notification.find_all_users(@wiki, 'Immediate')          
        unless users.empty?
          subject = "New comment about #{@page.presentation_name}"
          introduction = "User #{@comment.user.name} created a comment about <a href=\"#{@comment.page.url}\">#{@comment.page.presentation_name}</a> in site #{@comment.site.title}<br>"
          Notifier.notification(users.uniq,subject,introduction, @comment.text).deliver
        end
      end
    end
    @comments = Comment.find(:all, :conditions => ["page_id=? and site_id=?", @page.id, @wiki.id], :order => 'created_on ASC') 
  end

  def edit
    if params[:checkout_id]
      @checkout = Checkout.find(params[:checkout_id])
      v0 = @checkout.version.previous_version 
      if v0 and v0.version == 0 # v0 can be in nil in case of new page
        unless File.exists? v0.path(true) # we also want version 0 in TinyMCE format
          h = v0.html
          h = h.gsub(Page::BODY_TAG_PATTERN, '<body>') 
          h = h.gsub(Page::TREEBROWSER_PATTERN, Page::TREEBROWSER_PLACEHOLDER)
          h = h.gsub(Page::HEAD_PATTERN, '')
          @version0_html = h
        end
      end
      @page = @checkout.page 
      @wiki = @checkout.site
      render :layout => false
    else
      redirect_to :action => 'checkout', :id => params[:id], :site_folder => params[:site_folder]
    end
  end
  
  # Action #checkout to create a new checkout 
  def checkout
    if request.get?
      @version = UserVersion.new
      @page = Page.find(params[:id])
      @wiki = @page.site
      #--
      #@wiki = Wiki.find_by_folder(params[:site_folder]) 
      # TODO these kind of statement are no longer necessary, 
      # do global search and replace
      #++
      @version.wiki = @wiki
      co = @page.checkout 
      if co
        redirect_to :action => 'edit', :checkout_id => co.id
      else
        @version.source_version = @page.current_version
      end
    else
      logger.info("Creating new checkout using params #{params[:user_version].inspect}")
      @version = UserVersion.new(params[:user_version]) 
      @version.source_version = Version.find(@version.version_id) # TODO
      @page = @version.source_version.page
      @wiki = @page.site
      co = Checkout.new(:note => @version.note, :page => @page, :site => @wiki, :source_version => @version.source_version, :user => session_user, :version => @version )
      if co.save
        redirect_to :action => 'edit', :checkout_id => co.id 
      else
        logger.info("Failed to save checkout #{co.inspect}")
      end
    end
    @versions = @page.versions
  end

  # #save the HTML after checking that the User is the owner. The Page remains checked-out.
  def save
    @checkout = Checkout.find(params[:checkout_id])
    raise LoginController::FLASH_UNOT_CADMIN if !mine?(@checkout) && !cadmin?
    @checkout.version.html = params[:html]
    if params[:html_v0] # will only be present when previous version is version 0
      @version0 = @checkout.version.previous_version
      @version0.save_tinymce_html(params[:html_v0])    
    end
    @checkout.version.save
    if params[:action] == 'save'
      redirect_to :action => 'edit', :checkout_id => @checkout.id
    else
      redirect_to(url_for('/' + @checkout.version.rel_path_root))    
    end
  end
  
  def preview
    save
  end
  
  # Action #checkin to checkin a page that is checked-out
  # TODO force post method
  def checkin
    if params[:checkout_id]
      logger.info("Finding checkout with id #{params[:checkout_id]}")
      co = Checkout.find(params[:checkout_id])
      @version = co.version
      @wiki = co.site
      @page = co.page
      co.checkin(session_user, params[:html]) # will create Notification record
      if params[:html_v0] # will only be present when previous version is version 0
        @version0 = co.version.previous_version
        @version0.save_tinymce_html(params[:html_v0])    
      end      
      raise "Failed to checkin #{checkout.id}" if Checkout.exists?(co.id)
      flash.now['success'] = FLASH_CHECKIN_SUCCESS
      users = (User.find(:all, :conditions => ['notify_immediate=?', 1]) + Notification.find_all_users(@page, Page.name)).uniq
      users += Notification.find_all_users(@wiki, 'Immediate')
      unless users.empty?
          subject = "New version created of #{@version.page.presentation_name}"
          introduction = "User #{@version.user.name} created a version of <a href=\"#{@version.page.url}\">#{@version.page.presentation_name}</a> in site #{@version.wiki.title}<br>"
          Notifier.notification(users.uniq,subject,introduction, @version.note).deliver
      end
      #redirect_to :controller => 'versions', :action => 'edit', :id => version.id
      if @version.template?
        # Because we use note field to cache the brief description of a template
        # the field should be empty. # TODO Maybe we should rethink this use of the note field
        @version.note = ''
        @version.save!
        redirect_to @version.page.url
      end
    else
      logger.debug("Updating version note using params #{params.inspect}")
      @version = Version.find(params[:version][:id])
      @wiki = @version.wiki
      @page = @version.page
      if mine?(@version) || cadmin?
        #@version.note = params[:version][:note]
        if @version.update_attributes(params[:version])
          flash['notice'] = Utils::FLASH_RECORD_UPDATED # TODO test this
          redirect_to @version.page.url
        end    
      else
        flash.now['error'] = Utils::FLASH_NOT_OWNER # TODO test this
      end
    end
  end

  # Action #new to create a new Page based on a template or based on another page.
  def new
    @wiki = Wiki.find_by_folder(params[:site_folder])
    @page = Page.find(params[:id])
    @page_version = @page.current_version
    if  request.get?
      @new_page = Page.new
      @new_page.source_version = @page_version.id if @page_version # TODO a better name would be source_version_id?
    else
      logger.info("Creating new page with #{params.inspect}")
      #@templates = []
      version = nil
      version = Version.find(params[:page][:source_version]) if params[:page][:source_version]  
      @new_page, @checkout = WikiPage.new_using_template(params[:page].merge(:user=> session_user, :site => @wiki, :source_version => version))
      if @new_page.errors.empty?
        if @new_page.save
          if @checkout
            redirect_to :action => 'edit', :checkout_id => @checkout.id
          end
        end
      else
        logger.info("New page has errors: #{@new_page.errors.full_messages.join(', ')}")
      end
    end
    @templates = Site.templates
    @templates = ([@page_version] + @templates).compact.uniq # compact because @page_version can be nil
  end
  
  #--
  # TODO improved security - move authorisation check to Checkout.undo?
  #++
  def undocheckout
    co = Checkout.find(params[:checkout_id])
    page = co.page
    wiki = co.site
    if mine?(co) || cadmin?
      co.undo
      if  Checkout.exists?(co.id)
        raise "Failed to undo checkout #{co.id} of page #{co.page.presentation_name}"
      else
        if Page.exists?(page.id)
          redirect_to page.url
        else
          redirect_to wiki.pages[0].url
        end
      end
    else
      raise "This checkout is owned by #{co.user.name}. You cannot undo a checkout that belongs to another user"
    end
  end
  
  # TODO  Implement test
  def destroy 
    @page = Page.find(params[:id])
    #paths.each {|path| File.delete(path) if File.exists?(path)} # decided not to delete the files
    Checkout.destroy_all(['page_id=?', @page.id])
    Comment.destroy_all(['page_id=?', @page.id])
    Notification.destroy_all(['page_id=?', @page.id])
    Version.destroy_all(['page_id=?', @page.id])
    @page.destroy
    flash['success'] = "Page #{@page.presentation_name}deleted!"
    redirect_to request.referer
  end
  
  def history # TODO test
    @page = Page.find(params[:id])
    @wiki = Wiki.find_by_folder(params[:site_folder])
    @versions = @page.versions
    @versions << @page.checkout.version unless @page.checkout.nil?
    @other_versions = Version.find(:all, :conditions => ['wiki_id<>? and page_id=?', @wiki.id, @page.id], :order=> 'wiki_id, version ASC')
  end

  def search
    @page = Page.find(params[:id])
    @wiki = Wiki.find_by_folder(params[:site_folder])
    searcher
  end

  def rollback
    unless params[:version].nil?
      to = Version.find(params[:version][:version_id])
      if to.page.checkout.nil?
        co = Checkout.new(:user => session_user, :page => to.page, :site => to.wiki, :source_version => to, :note => "Rollback to version #{to.version}")
        if co.save
          co.checkin(session_user)
          flash['success'] = 'Rollback complete'
        else
          flash['error'] = 'Rollback failed'
        end
      else
        flash['error'] = 'Cannot rollback checked out page'
      end
      redirect_to :action => 'history', :id => to.page.id, :site_folder => to.wiki.folder
    end
  end

  def text
    @page = Page.find(params[:id])
    render :inline => "<%= (simple_format(strip_tags(@page.html))) %>", :layout => false
  end
  
end
