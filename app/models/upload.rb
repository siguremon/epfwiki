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

class Upload < ActiveRecord::Base

  belongs_to :user
  belongs_to :reviewer,              :class_name => 'User',    :foreign_key => 'reviewer_id'

  attr_accessor :file
  validates_presence_of :user
  #after_save :process

  def new_filename
    return  "#{self.id.to_s}.#{self.filename.split('.').last.downcase}"
  end
  
  def path
    return "#{ENV['EPFWIKI_ROOT_DIR']}public/uploads/#{self.new_filename}"
  end
  
  def file=(file)
    @file = file
    write_attribute 'filename', file.original_filename 
    write_attribute 'content_type', file.content_type.strip 
  end
  
  def save_file
    raise 'Cannot save without id' if self.id.nil?
    uploads_path = "#{ENV['EPFWIKI_ROOT_DIR']}public/uploads/"
    FileUtils.makedirs(uploads_path) if !File.exists?(uploads_path)
    self.rel_path = write_attribute 'rel_path', "uploads/#{self.id.to_s}.#{self.filename.split('.').last.downcase}"
    File.open(self.path, 'wb') do |file_date|
      file_date.puts file.read
    end
  end
  
  def url
    "#{ENV['EPFWIKI_BASE_URL']}/uploads/#{self.new_filename}"
  end
  
end
