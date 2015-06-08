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

# Text is a reserved word, so we use DaText
class DaText < ActiveRecord::Base
  
    belongs_to :reviewer, :class_name => "User", :foreign_key => "reviewer_id"  

    # CommentsController and FeedbacksController don't have own list actions, so we use this attribute
    # to redirect back to whereever we came from. 
    attr_accessor :request_referer
    #-- 
    # TODO problably there is a better way to do this
    #++    
  
end




