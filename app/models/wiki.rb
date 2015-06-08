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

class Wiki < Site

  has_many :versions, :foreign_key => 'wiki_id' 
  has_many :user_versions, :foreign_key => 'wiki_id'
  has_many :baseline_process_versions, :foreign_key => 'wiki_id'
  has_many :comments, :foreign_key => 'site_id'
  has_many :checkouts, :foreign_key => 'site_id'

  # Current BaselineProcess: the BaselineProcess used to create the Wiki or 
  # the BaselineProcess used last time the Wiki was updated
  belongs_to :baseline_process, :foreign_key => "baseline_process_id"

  # Baseline processes are used to create and update the Wiki
  has_many :updates, :order => 'finished_on DESC, created_on DESC'
  has_many :updates_todo, :class_name => 'Update', :order => 'created_on ASC', :foreign_key => 'wiki_id', :conditions => 'started_on is null'
  has_many :updates_done, :class_name => 'Update', :order => 'finished_on ASC', :foreign_key => 'wiki_id', :conditions => 'finished_on is not null'
  has_many :updates_inprogress, :class_name => 'Update', :order => 'started_on ASC', :foreign_key => 'wiki_id', :conditions => 'started_on is not null and finished_on is null'
  
  validates_format_of :folder, :with => /^([0-9a-zA-Z]|_)*$/, :message => 'Folder name can only have characters,digits and underscores'
  
  validate :validate_folder_exist, :on => :create
  
  # Used only for Notifier.report TODO a better solution
  attr_accessor :contributors
  

  # HTML Editors remove the nowrap attribute, so we add it to the CSS-file, see Wiki.enhance_files
  DEFAULT_CSS = 'css/default.css'
  
  def self.expire_all_pages
    # expire cached pages
    FileUtils.rm_rf File.expand_path("public/index.html", Rails.root.to_s)
    FileUtils.rm_rf File.expand_path("public/portal/home.html", Rails.root.to_s)
    FileUtils.rm_rf File.expand_path("public/portal/about.html", Rails.root.to_s)
    #FileUtils.rm_rf File.expand_path("public/portal/search.html", Rails.root.to_s)
    FileUtils.rm_rf File.expand_path("public/portal/wikis.html", Rails.root.to_s)
    FileUtils.rm_rf File.expand_path("public/portal/users.html", Rails.root.to_s)  
    FileUtils.rm_rf File.expand_path("public/portal/privacypolicy.html", Rails.root.to_s)  
    FileUtils.rm_rf File.expand_path("public/portal/termsofuse.html", Rails.root.to_s)  
    
    # remove cache folders 
    ['public/archives', 'public/pages/view', 'public/rss'].each do |f|
      p = File.expand_path(f, Rails.root.to_s)
      FileUtils.rm_r(p) if File.exists?(p)
    end
  end
  
  
  def status
    logger.debug("Determining status of wiki #{self.title}")
    s = 'Ready' 
    if self.updates.count == 0
      logger.debug("Wiki #{self.title} does not have any update records")
      s = 'Pending' 
    elsif self.updates_todo.count > 0
      logger.debug("Wiki #{self.title} has #{self.updates_todo.count.to_s} updates to do")
      s = 'Scheduled'
      self.updates_todo.each do |u|
        logger.debug("Update todo #{u.baseline_process.title} is started on #{u.started_on}")
        s = 'UpdateInProgress' if !u.started_on.nil?
      end
    elsif self.updates_inprogress.count > 0
      s = 'UpdateInProgress'
    end
    return s
  end
  
  def top_contributors
    arr = User.find(:all).collect {|u|[u, Version.count(:conditions => ['user_id = ? and baseline_process_id is null and wiki_id=?',u.id, self.id]) + 
    Comment.count(:conditions => ['user_id = ? and site_id=?',u.id, self.id]) + 
    Upload.count(:conditions => ['user_id = ?',u.id])]}
    arr = arr.sort_by{|t|-t[1]}
  end
  
  def top_monthly_contributors
    arr = User.find(:all).collect {|u|[u, Version.count(:conditions => ['user_id = ? and baseline_process_id is null and wiki_id=?',u.id, self.id]) + 
    Comment.count(:conditions => ['user_id = ? and site_id=?',u.id, self.id]) + 
    Upload.count(:conditions => ['user_id = ?',u.id])]}
    arr = arr.sort_by{|t|-t[1]}
  end

  # Method #wikify does the actual wikifying of the content. It is the second step of the two step
  # process (the first step created the Wiki record and Update record).
  # * copies content of the source Site (parent) into that folder
  # * scans the content of the baseline process if this was not done yet, see #scan4content
  # * enhances the files in that site using method #enhance_files
  # * creates a relation between the Baseline and the Site
  # NOTE: This method is typically not called directly but called via #Update.wikify
  def wikify(update)
    bp = update.baseline_process
    logger.info("bp for wikify: #{bp.inspect}, pages #{bp.pages.size}")
    logger.info("Updating Wiki #{self.title} with baseline process #{bp.title}")
    raise 'The site was updated already or has a an update in progress!' if !update.first_update?
    raise "Can only update with a baseline process (static site)" if bp.wiki?
    update.update_attributes(:started_on => Time.now) # changes the wiki status to 'UpdateInProgress'
    FileUtils.makedirs(self.path)   
    logger.info("Copying files from #{bp.path} to #{self.path}")
    FileUtils.cp_r(bp.path + "/.", self.path) # How to copy the contents of a folder and not the folder [http://www.ruby-doc.org/core/classes/FileUtils.html#M001703]
    if !bp.content_scanned_on
    	bp.scan4content
    else
	logger.info("Baseline process already scanned, it has #{bp.pages.count} pages")
    end
    cadmin = User.find_central_admin
    bp.pages.each do |p| 
      logger.info("Create page en version for path #{p.rel_path}")
      newp = WikiPage.new(:rel_path => p.rel_path, :site => self, :tool => 'EPFC', :status => 'New', :site_id => self.id)
      # create baseversion
      baseversion = BaselineProcessVersion.new(:baseline_update => update, :user => cadmin, :page => newp,
                      :wiki => self, :version => 0, :done => 'Y', :note => 'Automatically created',
        :baseline_process_id => bp.id) 
      newp.baseline_process_versions << baseversion
      newp.save!
    end
    enhance_files
    self.baseline_process = bp
    self.wikified_on = Time.now
    self.save!
  end

  # Method #update_wiki updates a Wiki with a BaselineProcess with the following steps:
  # 1. Copy content (overwriting all pages)
  # 2. Update status of EPFC pages to 'Undetermined'
  # 3. Update status of the Wiki pages, find 'Updated' and 'New' pages
  # 4. Make EPFC pages obsolete if they are not part of the new BaselineProcess
  # 5. Make Wiki pages obsolete if they have been harvested
  # 6. Enhance files
  # TODO: notify users that want to be notified (add about notify_baseline_updates column to users)
  # TODO: Change 68 - Update should continue with checkouts and should not overwrite not harvested changes
  def  update_wiki(update)
    update.update_attributes(:started_on => Time.now)    
    bp = update.baseline_process
    logger.info("Starting update of wiki #{self.title} from baseline process #{self.baseline_process.title} (#{self.baseline_process.id}) to #{bp.title} (#{bp.id})")
    logger.info("Copy update site " + bp.path + " to " + self.path)
    cadmin = User.find_central_admin
    # 1. 
    bp.copy_to(self, nil)
    
    # 2. Update status of EPFC pages to 'undetermined'  
    Page.update_all( "status = 'Undetermined'", ["tool = ? and site_id = ? ", 'EPFC', self.id, ])

    # 3. Update
    bp.scan4content if bp.content_scanned_on.nil?
    bp.pages.each do |p|
      page = Page.find_by_site_id_and_rel_path(self.id, p.rel_path)
      if page
        page.status = 'Updated'
        no = page.max_version_no + 1
      else
        page = WikiPage.new(:rel_path => p.rel_path, :site => self, :tool => 'EPFC', :status => 'New', :site_id => self.id)
        no = 0
      end
      # create baseversion
      baseversion = BaselineProcessVersion.new(:baseline_update => update,:user => cadmin, :page => page,
                      :wiki => self, :version => no, :done => 'Y', :note => 'Automatically created',
        :baseline_process_id => bp.id) 
      page.baseline_process_versions << baseversion
      page.save!
    end

    # 4. 
    Page.find(:all, :conditions => ['site_id = ? and status = ?', self.id, 'Undetermined']).each do |p|
      p.status = 'RemovedOrMoved'
      p.save!
    end 
    
    # 5.
    Page.find(:all, :conditions => ['site_id = ? and tool = ?', self.id, 'Wiki']).each do |p|
      if p.harvested?
        p.status = 'Harvested'
      end
    end

    # 6.
    enhance_files

    # Change 68 - current versions not harvested
    versions = UserVersion.find(:all, :conditions => ['wiki_id =? and done <> ? and version is not null', self.id, 'Y'])
    logger.info("Found #{versions.size.to_s} versions with unharvested changes")
    pages = versions.collect{|version| version.page}.uniq
    if pages
      logger.info("Found #{pages.size.to_s} pages with unharvested changes") if pages
      snippets = Page.get_snippets
      pages.each do |page|
        logger.info("Processing page #{page.presentation_name}")
        if page.checkout
          logger.info("Page has unharvested versions, we don't need to set a current version")
        else  
          cv = page.current_version 
          unless cv.nil?
            if cv.current 
              logger.info("Page #{page.presentation_name} already has current version with id #{cv.id}, we don't need to set a current version")
            else
              logger.info("Page #{page.presentation_name} does not have a current version")          
              # set the current version equal to the last version that is not part of the update we are doing
              page.current_version = Version.find(:first, :order => 'version DESC', :conditions => ['page_id=? and version is not null and update_id is null',page.id])
            end
            page.html = page.current_version.html
            Page.enhance_file(page.path, snippets)
          end
        end
      end
    end
    self.baseline_updated_on = Time.now
    self.baseline_process = bp
    self.save!
  end
  
  def url
    "#{ENV['EPFWIKI_BASE_URL']}/#{self.rel_path}/index.htm"
  end
  
  def validate_folder_exist
      logger.info("Folder #{ENV['EPFWIKI_WIKIS_PATH']}/#{self.folder} should not exists already")
      errors.add(:folder, 'already exists') if  (!self.folder.blank? && File.exists?("#{ENV['EPFWIKI_WIKIS_PATH']}/#{self.folder}")) || !Wiki.find_by_folder(self.folder).nil?
      if self.title == 'Templates'
        if Wiki.find(:first, :conditions => ['title = ?','Templates'])
          errors.add(:title, ' "Templates" has been used. There can only be one Wiki with that name.') 
        end
      end 
  end

  def users
    return User.find(:all, :conditions => ['exists (select * from versions vsn where vsn.wiki_id = ? and vsn.user_id = users.id and baseline_process_id is null) or exists (select * from da_texts cmt where cmt.user_id = users.id and cmt.site_id = ?) or exists (select * from uploads where uploads.user_id = ?)', id, id, id])
  end

  #######
  private
  #######

  def enhance_files

    # CSS enhancement making it more robust layout of html, which shouldn't influence how the page is displayed
    css = IO.readlines(self.path + '/' + DEFAULT_CSS).join + "\n"
    [/.pageTitle .*?\{.*?\}/m, /.expandCollapseLink \{.*?\}/m].each do |regex|
      match = regex.match(css)
      if match
        new_css_snip = match[0].gsub('}', "\nwhite-space: nowrap;}") 
        css = css.gsub(match[0], new_css_snip) 
      else
        logger.info("CSS snippet not found, #{DEFAULT_CSS} changed in newer release of EPF?")
      end
    end
    f = File.new(self.path + '/' + DEFAULT_CSS, 'w')
    f.puts(css)
    f.close
    snippets = Page.get_snippets # TODO rename to snippets
    self.files_wikifiable.each do |path|
      Page.enhance_file(path, snippets)
    end
  end  
  
end
