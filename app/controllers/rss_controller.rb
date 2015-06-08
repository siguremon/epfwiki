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

class RssController < ApplicationController

  caches_page :list
  
  def list
    @cadmin = User.find_central_admin
    @updates = Update.find(:all, :order => 'finished_on DESC', :conditions => ['finished_on > ?', Time.now - 14.days], :limit => 14)
    @uploads = Upload.find(:all, :order => 'created_on DESC', :conditions => ['created_on > ?', Time.now - 14.days], :limit => 14)
    unless params[:site_folder] == 'all' then
      #logger.debug("Rss for wiki in folder #{params[:site_folder]}")
      @wiki = Wiki.find_by_folder(params[:site_folder])
      @versions = UserVersion.find(:all, :order => 'created_on DESC', :conditions => ['wiki_id=? and baseline_process_id is null and created_on > ? and not exists (select * from checkouts c where c.version_id=versions.id)', @wiki.id, Time.now - 14.days ], :limit => 14)
      @comments = Comment.find(:all, :order => 'created_on DESC', :conditions => ['site_id=? and created_on > ?', @wiki.id, Time.now - 14.days], :limit => 14)
    else
      #logger.debug("Rss for all wiki")
      @versions = UserVersion.find(:all, :order => 'created_on DESC', :conditions => ['baseline_process_id is null and created_on > ? and not exists (select * from checkouts c where c.version_id=versions.id)',Time.now - 14.days], :limit => 14)
      @comments = Comment.find(:all, :order => 'created_on DESC', :conditions => ['created_on > ?',Time.now - 14.days], :limit => 14)
    end
    
    @records =  @uploads + @comments + @updates + @versions

    @records = @records.sort_by{|e| e.created_on}.reverse

    # @updated will be our Feed's update timestamp
    @updated = @records.first.created_on unless @records.empty?
    
    respond_to do |format|
      format.atom { render :layout => false }
      # we want the RSS feed to redirect permanently to the ATOM feed
      format.rss { redirect_to feed_path(:format => :atom), :status => :moved_permanently }
    end
  end
   
end

