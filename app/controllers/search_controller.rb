# Copyright (c) 2006-2013 OnKnows.com
#  
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
#Contributors:
#* Onno van der Straaten:: initial implementation

class SearchController < ApplicationController
  
  layout 'management'
  
  before_filter :authenticate_admin, :only => [:tasks]
  
  #--
  # See also FIXME Bugzilla 231125
  #++
  def index
    searcher # see application controller
  end
  
  def tasks
    if params[:cmd]
      case params[:cmd]
      when 'start'
        Sphinx.start
        flash.now['notice'] = "Starting Sphinx"
      when 'index'
        Spawn.new(:argv => "Indexing") do
          logger.info('Sphinx: starting indexer')
          Sphinx.index
          logger.info('Sphinx: finished creating index')
        end
        flash.now['notice'] = "Indexer started, depending on the size of the database this can take some time"
      when 'stop'
        Sphinx.stop
        flash.now['notice'] = "Stoping Sphinx"
      else
        raise "Unknown command #{params[:cmd]}"
      end
    else
      flash.now['notice'] = "<p>#{Sphinx.status}</p>" 
    end
  end

end