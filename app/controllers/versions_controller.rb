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

class VersionsController < ApplicationController
  
  before_filter :authenticate, :except => [:list]
  before_filter :authenticate_admin, :only => [:note]
  
  cache_sweeper :sweeper, :only => [:rollback]
  
  FLASH_FILES_IDENTICAL = "The two selected files are identical"
  
  layout 'wiki'
  
  protect_from_forgery :except => :note 
  
  def show
    @version = Version.find(params[:id])
    @page = @version.page
    @wiki = @page.site
    @baseversion = @version.baseversion
    @last_version = @page.last_version
    @current_version = @version.current_version
    @source_version = @version.source_version
    @previous_version = @version.previous_version
  end
  
  def diff
    if params[:user_version]
      @version = Version.find(params[:user_version][:id])
      @version.source_version = Version.find(params[:user_version][:version_id]) 
    else
      @version = Version.find(params[:id])
      @version.source_version = @version.previous_version || @version
    end 
    @versions = @version.page.versions
    @page = @version.page
    @wiki = @page.site
    @version.xhtmldiffpage(@version.source_version)
  end
  
  def text
    @version = Version.find(params[:id])
    render :inline => "<%= (simple_format(strip_tags(@version.html))) %>", :layout => false
  end
  
  # Action #note to update the version note by the reviewer, cadmin or 
  # an admin when there is no reviewer defined yet.
  def note
    v = Version.find(params[:id])
    if v.reviewer.nil? || v.reviewer == session_user || cadmin?
      v.note = params[:value]
      v.reviewer = session_user 
      v.save!
      v.reload
    end
    render :text => v.note
  end  
  
end
