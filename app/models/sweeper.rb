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

class Sweeper < ActionController::Caching::Sweeper
  
  observe WikiPage, Checkout, Comment, Wiki, UserVersion, Upload 
  
  # TODO more advanced expiration
  def after_create(record)
    if record.is_a?(Wiki) || record.is_a?(Checkout) || record.is_a?(Comment) || record.is_a?(UserVersion) || record.is_a?(Wiki) || record.is_a?(Upload)
      Wiki.expire_all_pages
    elsif record.is_a?(WikiPage)
      Wiki.expire_all_pages if record.tool = 'Wiki'
    end
  end
  
  def after_destroy(record)
    if record.is_a?(Checkout)
      Wiki.expire_all_pages
    end
  end
  
end