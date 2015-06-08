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

class OtherController < ApplicationController

  layout 'management'
  
  before_filter :authenticate_cadmin, :only => [:reset]

  protect_from_forgery :except => [:reset]
    
  FLASH_WARNING = "Click the link to reset the EPF Wiki database. All changes will be lost!"
  FLASH_SUCCESS = "Database reset complete!"
 
  # Action #info displays information this application
  def about
    @version = Utils.db_script_version(ENV['EPFWIKI_ROOT_DIR'] + "db/migrate")
    sql = 'select max(version) from schema_migrations'
    @database_schema = ActiveRecord::Base.connection.execute(sql).extend(Enumerable).to_a.first.first
    if  @database_schema.to_s == @version.to_s
      @version = nil
    else
      flash.now['warning'] = "Database seems out-of-date. Available scripts are of a higher version. Available is " + @version.to_s + ", installed is " + @database_schema.to_s 
    end
    config   = Rails.configuration.database_configuration
    @host     = config[Rails.env]["host"]
    @database = config[Rails.env]["database"]
    @username = config[Rails.env]["username"]
  end
    
  # Action #error is redirected to from ApplicationController.resque_action_in_public
  # to display a userfriendly error message
  def error
  end
  
  # See routes.rb
  def show404
      flash.now['error'] = 'The page you\'ve requested cannot be found.'
      render :action => 'error', :status => 404, :formats => [:html]
  end
 
  def reset
    if request.post?
      Site.reset
      reset_session
      expire_cookie
      flash['success'] = FLASH_SUCCESS
      redirect_to :controller => 'login', :action => 'new_cadmin'
    else
      flash['warning'] = FLASH_WARNING
    end
  end
  
end
