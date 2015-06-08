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

class BaselineProcess < Site

  has_many :updates

  validate :validate_folder
  validate :validate_folder_not_used, :on => :create
  
  # during creation of a new static Site this stores the zip-file that contains the content
  attr_accessor :file 

  # Method #new_upload to process a upload of content for a baseline process
  def self.new_from_upload(params = nil)
    logger.info("Site.new_upload #{params.inspect}")
    site = BaselineProcess.new(params)
    unless site.file.blank?
      site.errors.add(:file, 'can\'t be blank') if  site.file.original_filename.blank?
      site.errors.add(:file, 'needs to be a zip file') if site.file.original_filename.downcase.reverse[0..3] != 'piz.'
      site.errors.add(:file, 'needs to be named using only characters, numbers, dots and underscores') unless site.file.original_filename =~ /\A[._a-zA-Z0-9]+\z/
      site.folder = File.basename(site.file.original_filename, '.zip')
      logger.info("Foldername for Baseline Process will be #{site.folder}")
      site.errors.add(:folder, 'already exists') if  File.exists?(site.path) && !site.folder.blank? 
      site.errors.add(:folder, 'is already being used by a Baseline Process') if  !BaselineProcess.find(:first, :conditions => ['folder =?', site.folder]).nil?
      if site.errors.empty?
        logger.debug("Writing upload zip to #{site.path2zip}")
        File.open(site.path2zip, "wb") { |f| f.write(site.file.read) }
        site.unzip_upload 
      end
    else
      site.errors.add(:file, 'no zip file was selected for upload') 
    end 
    return site
  end

  # Return collection of Baseline Processes that need to scanned
  def self.find_2scan
    return BaselineProcess.find(:all, :conditions => ['content_scanned_on is null'], :order => "title ASC")
  end

 # Method #scan4content scans the site folder for pages that can be wikified
  def scan4content
    logger.info("Scanning content in site #{self.title}")
    if self.content_scanned_on.nil?  
      self.pages = [] # Note: fixed bug with Rails 3 upgrade, moved with upgrade inside 'if'. 
      files = self.files_wikifiable
      self.wikifiable_files_count = files.size
      files.each do |f|
        page = BaselineProcessPage.new(:rel_path => f.gsub(self.path + '/', ''), :site => self, :tool => 'EPFC', :status => 'N.A.')
        self.pages << page
      end
      self.content_scanned_on = Time.now
      self.save!
    else
      logger.info("Content has already been scanned!")
    end
  end

  # Method #unused_folders returns folders with content that have not been used to create a BaselineProcess
  def self.unused_folders
    sites_path = "#{ENV['EPFWIKI_ROOT_DIR']}#{ENV['EPFWIKI_PUBLIC_FOLDER']}/#{ENV['EPFWIKI_SITES_FOLDER']}"
    FileUtils.makedirs(sites_path)
    entries = Dir.entries(sites_path) - ['.', '..', 'compare', '.svn']
    folders = []
    entries.each do |entry|
      if File.ftype(File.expand_path(entry, sites_path)) == 'directory' 
        folders << entry
      end
    end
    used_folders = BaselineProcess.find(:all, :conditions => ['obsolete_on is null']).collect {|bp| bp.folder}    
    return folders - used_folders
  end 

  def url
    "#{ENV['EPFWIKI_BASE_URL']}/#{ENV['EPFWIKI_SITES_FOLDER']}/#{self.folder}/index.htm"
  end 
  
  #--
  # TODO do this for Wikis as well, including status
  #++
  def export_csv
    path_csv = "#{self.path}.csv"
    logger.info("Exporting #{self.title} to csv #{path_csv}")
    self.scan4content if !self.content_scanned_on
    csv_file = File.new(path_csv, 'w')
    csv_file.puts("\"" + ['Plugin', 'UMA Type', 'Element Type', 'Presentation Name', 'Name', 'Relative path', 'URL'].join("\";\"") + "\"")
    self.pages.each do |page|
      plugin_name = page.rel_path.split('/')[0]
      type = page.name.uma_type
      name = page.uma_name
      url = "#{ENV['EPFWIKI_BASE_URL']}/#{self.rel_path}/#{page.rel_path}"
      csv_file.puts("\"" + [plugin_name, type, page.uma_type.name, page.presentation_name, name, page.rel_path, url].join("\";\"") + "\"")
    end
    csv_file.close
  end
  
  def validate_folder
    errors.add(:folder, 'doesn\'t exist') if self.folder.nil? || !File.exists?(self.path)
    errors.add(:folder, "does not seem to contain a valid site, no index.htm was found") if !File.exists?(self.path + '/index.htm') 
  end

  def validate_folder_not_used
    logger.debug('Validate on create')
    errors.add(:folder, 'was already used to create a baseline process') if !self.folder.nil? && BaselineProcess.find_all_by_folder(self.folder).size > 0
  end

end
