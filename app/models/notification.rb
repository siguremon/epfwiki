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

# More information:
# * {EPF Wiki Data model}[link:files/doc/DATAMODEL.html]
class Notification < ActiveRecord::Base

    belongs_to :user
    belongs_to :page
    belongs_to :site

    #--
    # TODO user class as third parameter?
    #++ 
    def self.find_all_users(page, class_name)
      Notification.find(:all, :conditions => ["page_id=? and notification_type=?", page.id, class_name]).collect {|n|n.user}
    end
    
    def self.find_or_create(page, user, class_name)
      logger.info("Finding or creating notification for #{user.name} for #{page.presentation_name} and type #{class_name}")
      n = Notification.find(:first, :conditions => ['page_id=? and notification_type=? and user_id=?',page.id, class_name, user.id])   
      if n.nil?
        logger.info("No")
        n = Notification.create(:notification_type => class_name, :user => user, :page => page)
      end
      return n
    end

end
    
