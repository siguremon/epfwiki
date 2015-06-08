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

# A Site can be a BaselineProcess (static, published website from EPF) or a Wiki, 
# which is an enhanced EPFC site. Baseline Processes are 
# used to create or update Wiki sites.
#
# Creation or update of a Wiki is a two step process for performance reasons.
# This way the second step can be performed using a job that runs at night.
# 
# More information:
# * {EPF Wiki Data model}[link:files/doc/DATAMODEL.html]

class Site < ActiveRecord::Base
  
  belongs_to :user
  has_many :pages
 
  validates_presence_of  :user_id, :title, :folder # TODO validate :user not :user_id
  
  # TODO Folde can contain . (dot) because it is created from a filename
  validates_format_of :folder, :message => 'should consist of letters, digits and underscores', :with =>  /([-_.\dA-Za-z])*/  
  
  # A wikifiable file is a HTML file
  HTML_FILE_PATTERN = /.*.htm(l)?/i
  
  # A wikifiable is not a Wiki file (a version file created using the Wiki)
  WIKI_FILE_PATTERN = /(.)*wiki(.)*/i
  
   def content_scanned?
    return !self.content_scanned_on.nil?
  end
  
  def baseline_processes_candidate
    returning bp_candidate = [] do
      if self.status == 'Ready' # TODO
        Site.find_baseline_processes.each do |bp|
          bp_candidate << bp unless self.baselines.include?(bp.baseline)
        end
      end    
    end
  end
  
  def wiki?
    return self.class.name == 'Wiki'
  end
  
  def baseline_process?
    return self.class.name == 'BaselineProcess'
  end
  
  def path 
    return "#{ENV['EPFWIKI_ROOT_DIR']}#{ENV['EPFWIKI_PUBLIC_FOLDER']}/#{ENV['EPFWIKI_WIKIS_FOLDER']}/#{self.folder}" if self.wiki?
    return "#{ENV['EPFWIKI_ROOT_DIR']}#{ENV['EPFWIKI_PUBLIC_FOLDER']}/#{ENV['EPFWIKI_SITES_FOLDER']}/#{self.folder}"
  end
  
  def rel_path
    return self.path.gsub(ENV['EPFWIKI_ROOT_DIR'] + "#{ENV['EPFWIKI_PUBLIC_FOLDER']}/",'')
  end
  
  def path2zip 
    return self.path + '.zip'
  end
  
  # Method #templates returns current versions of pages from the Wiki 'Templates'. 
  # These pages are templates for creating new pages. 
  def self.templates
    w = Wiki.find_by_title('Templates')
    raise "No Templates Wiki was found. There should always be a Wiki with title 'Templates' to provide templates for creating new pages" if !w
    w.pages.collect{|p| p.current_version if p.current_version}.compact # NOTE: a new checked out Template has no current version
  end
  
  def unzip_upload
    logger.info("Unzipping upload #{self.path2zip}")
    raise "Folder #{self.path} exists" if File.exists?(self.path)
    cmdline = "unzip -q \"#{self.path2zip}\" -d \"#{self.path}\""
    logger.debug("Executing command #{cmdline}")
    unzip_success =  system(cmdline)
    raise "Error executing command #{cmdline}: #{$?}" if !unzip_success
  end
  
  # array of HTML files that are candate Wikification
  def self.files_html(path)
    paths = Array.new
     (Dir.entries(path) - [".", ".."]).each do |entry| 
      new_path = File.expand_path(entry, path)
      if FileTest.directory?(new_path)   
        paths = paths + Site.files_html(new_path)
      else
        paths << new_path if !HTML_FILE_PATTERN.match(entry).nil? && WIKI_FILE_PATTERN.match(entry).nil?
      end
    end
    return paths
  end
  
  # Find wikifiable files
  def files_wikifiable
    raise 'Path can\'t be blank' if self.path.blank?
    logger.info("Finding wikifiable files in #{self.path}")
    
    # TODO workaround for ArgumentError: invalid byte sequence in UTF-8
    # http://po-ru.com/diary/fixing-invalid-utf-8-in-ruby-revisited/
    # ic = Iconv.new('UTF-8//IGNORE', 'UTF-8') # 
    # valid_string = ic.iconv(untrusted_string + ' ')[0..-2]
    
    ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
    paths = []
    Site.files_html(self.path).each do |p|
      #logger.debug(p)
      c = File.read(p)
      c_trusted = ic.iconv(c +  ' ')[0..-2]
      match = Page::ELEMENT_TYPE_PATTERN.match(c_trusted)
      if !match.nil?
        paths << p 
      end
    end
    logger.debug("Found #{paths.size} wikifiable files\n" + (paths[0..14]+["...(skipping remaining #{paths.size}) files"]).join("\n"))
    paths
  end

  def self.update
    raise "Raise for testing exception handling in rake update" if ENV['EPFWIKI_RAISE_IN_RAKE_UPDATE'] == 'Y' # for test purposes
    cadmin = User.find_central_admin
    BaselineProcess.find_2scan.each do |bp|
      bp.scan4content
    end # end scan
    expired_by_update = false
    Update.find_todo.each do |update|
      update.do_update
      expired_by_update = true
    end # end update
    Wiki.expire_all_pages unless expired_by_update
    Sphinx.index # Update Sphinx index (will start server if not started)
  rescue => e
    Rails.logger.info("Error updating sites: " + e.message + "\n" + e.backtrace.join("\n"))
    Notifier.email(User.find_central_admin, 'Error running job_daily', [], e.message + "\n" + e.backtrace.join("\n")).deliver
  end
  
  def self.reports(runtime = Time.now)
    reps_sent = []
    raise "Raise for testing exception handling in rake update" if ENV['EPFWIKI_RAISE_IN_RAKE_UPDATE'] == 'Y' # for test purposes
    (Wiki.find(:all, :conditions => ['obsolete_on is null']) << nil).each do |w| # Wiki.new for notification for all sites
      Rails.logger.info("Site Reports for site " + w.title) if w
      Rails.logger.info("Global Reports") unless w
      reps = [Report.new('D', w, runtime)] # daily 
      reps << Report.new('W', w, runtime) if runtime.wday == 1 # monday, sunday is 0
      reps << Report.new('M', w, runtime) if runtime.day == 1 # first day of the month 
      reps.each do |r|
        Rails.logger.info("Report_type: " + r.report_type + "\nr.items.empty?: " + r.items.empty?.to_s + "\nr.users.empty? " + r.users.empty?.to_s )
        Notifier.summary(r).deliver unless r.items.empty? or r.users.empty? # only deliver when content and users
        reps_sent << r unless  r.items.empty? or r.users.empty?
      end
    end
    reps_sent
  rescue => e
    Rails.logger.info("Error running job_daily: " + e.message + "\n" + e.backtrace.join("\n"))
    Notifier.email(User.find_central_admin, 'Error running job_daily', [], e.message + "\n" + e.backtrace.join("\n")).deliver
  end
  
  def self.changed_items(rep)
    cond = ['created_on > ? and created_on < ?', rep.starttime, rep.endtime]
    if rep.site
      site_cond = ['created_on > ? and created_on < ? and site_id = ?', rep.starttime, rep.endtime, rep.site]
      site_cond2 = ['created_on > ? and created_on < ? and wiki_id = ?', rep.starttime, rep.endtime, rep.site]
      site_cond3 = ['created_on > ? and created_on < ? and tool=? and site_id = ?', rep.starttime, rep.endtime, 'Wiki', rep.site]
    else
      site_cond = site_cond2 = cond
      site_cond3 = ['created_on > ? and created_on < ? and tool=?', rep.starttime, rep.endtime, 'Wiki']
    end
    items = UserVersion.find(:all, :conditions => site_cond2) +
    Comment.find(:all, :conditions => site_cond) +
    Upload.find(:all, :conditions => cond) +
    Wiki.find(:all, :conditions => cond)+
    Update.find(:all, :conditions => site_cond2) +
    User.find(:all, :conditions => cond) +
    WikiPage.find(:all, :conditions => site_cond3)
    Checkout.find(:all)
    items.sort_by {|item|item.created_on}
  end
  
  def self.reset
      DaText.delete_all
      Page.delete_all
      Version.delete_all
      Site.delete_all
      Checkout.delete_all
      Notification.delete_all
      Update.delete_all
      Upload.delete_all
      User.delete_all
      ['pages','development_sites','development_wikis','development_diffs',
       'test_diffs','test_sites','test_wikis','wikis',
       'uploads','bp' ].each do |entry|
        FileUtils.rm_rf "public/#{entry}" if File.exists? "public/#{entry}"   
      end
      FileUtils.rm_rf "public/index.html" if File.exists? "public/index.html" # cache file
  end
  
  
  ###########
  # private # TODO after upgrade we need this
  ###########
  
 
  # action #copy_to copies the content of a site to another site (theDestSite). Files are overwritten if they exist in the destination site.
  # NOTE: Ruby does not have a copy + overwrite command?
  def copy_to(theDestSite, theFolderPath = nil)
    if  theFolderPath
     (Dir.entries(theFolderPath) - [".", ".."]).each do |aEntry|
        aPath = File.expand_path(aEntry, theFolderPath)
        aDestPath = aPath.gsub(self.path, theDestSite.path)
        if  FileTest.directory?(aPath)
          logger.info("Copying folder " + aPath + " to " + aDestPath)
          FileUtils.makedirs(aDestPath)
          copy_to(theDestSite, aPath)
        else
          if  !FileTest.exists?(aDestPath)
            logger.info("New file copied " + aPath + " to " + aDestPath)
            FileUtils.copy(aPath, aDestPath)
          else
            if  FileUtils.cmp(aPath, aDestPath)
              logger.info("Not copied because equal: " + aPath)
            else
              logger.info("Overwritten: " + aPath)
              FileUtils.remove_dir(aDestPath) # TODO changed by upgrade was File.delete
              FileUtils.copy(aPath, aDestPath)
            end
          end
        end
      end 
    else
      logger.info("Copying content from site " + self.title + " to " + theDestSite.title)
      logger.info("Source folder: " + self.path + ". Destination folder: " + theDestSite.path)
      copy_to(theDestSite, self.path)
    end
  end
  
end
