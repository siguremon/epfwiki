# Copyright (c) 2013 OnKnows.com
#  
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
#Contributors:
#* Onno van der Straaten:: initial implementation

ThinkingSphinx::Index.define :page, :with => :active_record do
  # fields
  indexes presentation_name, :sortable => true
  indexes body_text
  indexes uma_name, :sortable => true
  indexes uma_type.name, :as => :uma_type_name, :sortable => true
  indexes user_versions.note, :as => :version_notes
  indexes user_versions.user.name, :as => :version_username
  indexes comments.text, :as => :comments
  indexes comments.user.name, :as => :comment_username

  # attributes
  has site_id, :as => :site
  has uma_type_id, :as => :type
  has updated_on, :as => :updated_on

end