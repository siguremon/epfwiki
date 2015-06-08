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

class WikiPage < Page

  # When creating a new page, the page will belong to the user creating the page
  belongs_to :user

  #--
  # TODO database change -> rename page_id to wiki_page_id
  #++
  has_many :notifications#, :dependent => :destroy

  #--
  # TODO (but now now) anomaly works in the console but not in the application or in tests. Then is always returns nil. Replaced with method
  # has_one :checkout, :foreign_key => 'page_id' 
  #++
  
  #--
  # has_many :comments, :foreign_key => 'page_id' #, :dependent => :destroy
  # TODO anomaly. the above statement does not work. Comments is always nil. When I change the key
  # I see the statement, it looks allright.
  # ActiveRecord::StatementInvalid: Mysql::Error: Unknown column 'da_texts.page_id_2
  # ' in 'where clause': SELECT * FROM `da_texts`   WHERE (da_texts.page_id_2 = 1431
  # ) AND ( (`da_texts`.`type` = 'Comment' ) )
  #++

  def versions
    (self.user_versions + self.baseline_process_versions).sort_by{|v|v.version}
  end

  def checkout
    Checkout.find(:first, :conditions => ['page_id=?',self.id])
  end

  # change 68 TODO remove
  def unharvested_versions
    Version.find(:all, :order => 'created_on DESC', :conditions => ['page_id = ? and done=?',self.id, 'N'])
  end
  
  #--
  # TODO not sure if this is used
  #++
  def harvested?
    self.unharvested_versions.size == 0
  end

  # Method #new_using_template requires presentation_name, note, site, user and source_version and returns: page, checkout.
  # For an example see PagesController.new 
  #--
  # TODO new_using_template when there is already a checkout causes error without clear message
  #++
  def self.new_using_template(params)
    logger.info("Creating new page using params: #{params.inspect}" )
    p, co = nil, nil
    if params[:presentation_name].blank? or params[:source_version].nil?
       logger.error('Parameters are missing')
       p = Page.new
       p.errors.add(:presentation_name, "can't be blank") if params[:presentation_name].blank?
       p.errors.add(:source_version, "can't be blank") if params[:source_version].nil?
    else
      sv = Version.find(params[:source_version])
      #p = sv.page.clone # TODO no longer working, why? 
      p = WikiPage.new
      p.site = params[:site]
      p.tool = 'Wiki'
      p.user = params[:user]
      p.presentation_name = params[:presentation_name]
      p.filename = p.presentation_name.downcase.delete('&+-.\"/\[]:;=,').tr(' ','_') + '.html' if !p.presentation_name.blank?
      old_path = File.expand_path(p.filename, File.dirname(sv.path))
      if sv.class.name == UserVersion.name
        p.rel_path = old_path.gsub(sv.wiki.path + '/','')
      else
        p.rel_path = old_path.gsub(sv.baseline_process.path + '/','')
      end
      # make the rel_path unique, this way we can create multiple pages with the same presentation name
      unique = false
      while !unique
        if Page.exists?(['rel_path = ? and site_id = ?',p.rel_path, p.site.id])     
          p.make_rel_path_unique 
        else
          unique = true
        end
      end
  
      logger.debug("New path is #{p.rel_path}, site path is #{sv.wiki.path}, old_path is #{old_path}")
      h = sv.html
      h = h.gsub(/<meta.*? name="uma\.presentationName".*?>/, '<meta content="' + p.presentation_name + '" name="uma.presentationName">')
      h = h.gsub(TITLE_PATTERN, "<title>#{p.presentation_name}</title>")
      h = h.gsub(TITLE2_PATTERN, 'class="pageTitle">' + p.presentation_name + '</td>') 
      p.html = h
      Page.enhance_file(p.path)
      if p.save
        logger.info("Page saved, creating co")
          co = Checkout.new(:note => p.note, :page => p, :site => p.site, :source_version => sv, :user => params[:user], :html => h)
          logger.debug("creating co: #{co.inspect}")
          co.save
          Notification.find_or_create(p, params[:user], Page.name)
      else
        logger.info("Failed to save page, returned unsaved page")
      end
    end
    return p, co
  end
  
  def max_version_no
    max = Version.maximum('version', :conditions => ['page_id=? and wiki_id = ?',self.id, self.site.id]) 
    max = 0 if max.nil? # max can be zero when creating new pages, there is no BaselineProcessVersion only a UserVersion
    return max
  end

  # Method #current_version=(version) makes the version the current version of the page 
  #--
  # TODO this method should also do the html stuff
  #++
  def current_version=(v)
    logger.debug("v: #{v.inspect}")
    v2 = self.current_version
    if v2
      logger.debug("v2:\n#{v2.inspect}")
      if v2.current
        v2.current = false 
        v2.save!
        logger.info("No longer current version: #{self.filename} version #{v2.version}(#{v2.id})")
      else
        logger.debug "Current version but not current #{self.filename} version #{v.version}(#{v.id})"
      end
    else
      logger.info("No current version found")
    end
    #if v
      v.current = true # TODO implement test
      v.save!
      logger.debug("v na: #{v.inspect}")
      v.reload
      logger.debug("v na reload: #{v.inspect}")
      logger.info("New current version: #{self.filename} version #{v.version}(#{v.id}) the current version")
    #end
    return v
  end

  # Method #current_version returns the current version of the page   
  def current_version
    logger.debug("Finding current version of page #{self.presentation_name}")
    version = Version.find(:first ,:conditions => ["page_id=? and current = ?", self.id, true])
    version = Version.find(:first ,:order => "version DESC", :conditions => ["page_id=? and version is not null", self.id]) if version.nil?
    version = version.previous_version if !version.nil? && version.checkout #NOTE: version can be nil, it will be nil when creating a new page
    return version
  end

  # Method #last_version return the last created version (the version with the highest version number). Versions that are
  # part of a checkout are excluded (version is nil for those versions)
  def last_version
    return Version.find(:first ,:order => 'version DESC', :conditions => ["page_id=? and version is not null", self.id])    
  end

  def contributors
    (self.user_versions.collect {|v|v.user.name} + self.comments.collect {|c|c.user.name}).uniq
  end

  # See also #Page.html
  def html=(h)
    logger.debug("Writing html to #{self.path}")
    d = File.dirname(self.path)
    FileUtils.makedirs(d) if !File.exists?(d) # In case of a new page being created using a template, the dir possible doesn't exist yet
    f = File.new(self.path, "w")
    f.puts(h)
    f.close     
  end

  # Example wiki.pages.active
  def self.active
    find(:all, :conditions=>["status = ? or status = ?", 'New','Updated'])
  end
  
  # TODO Bugzilla 231125
  # A method like below could be used to create a good index for finding pages
  #def text
  #  t = read_attribute('text')
  #  if t.blank?
  #    t = self.html.gsub(/<\/?[^>]*>/, '')    
  #    t += self.comments.collect {|c|c.text} 
  #    t += self.versions.collect {|v|v.note}
  #    write_attribute('text', t)
  #  end
  #  t
  #end
  
  def other_pages_with_comments
    pages = []
    WikiPage.find(:all, :conditions => ['rel_path = ? and id <> ?', self.rel_path, self.id]).each do |p|
      pages << p if Comment.count(:conditions => ['page_id =?', self.id]) > 0        
    end
    pages
  end

  def other_pages_with_versions
    pages = []
    WikiPage.find(:all, :conditions => ['rel_path = ? and id <> ?', self.rel_path, self.id]).each do |p|
      pages << p if Version.count(:conditions => ['page_id =? and baseline_process_id is null', self.id]) > 0        
    end
    pages
  end
  
  def wikis
    return WikiPage.find(:all, :conditions => ['rel_path=?', self.rel_path]).collect {|p|p.site}
  end

  def comments_in_other_wikis_count
    Comment.count(:conditions => ['site_id in (?) and page_id <> ?', WikiPage.find(:all, :conditions => ['rel_path=?', self.rel_path]).collect{|p|p.id}, self.id])    
  end

  def versions_in_other_wikis
    Version.find(:all, :conditions => ['wiki_id in ? and baseline_process_id is null and page_id <> ?', WikiPage.find(:all, :rel_path => self.rel_path).collect{|p|p.id}, self.id])
  end
  
  def versions_in_other_wikis_count
    ids = WikiPage.find(:all, :conditions => ['rel_path=?', self.rel_path]).collect{|p|p.id}
    Version.count(:conditions => ['wiki_id in (?) and baseline_process_id is null and page_id <> ?', ids , self.id])    
  end
  
  def checkedout?
    !self.checkout.nil?  
  end

  # TODO add check that if the page is a new page (tool = 'Wiki'), the user needs to be set

  # Make rel_path unique if it isn't unique. Used for creating new pages with the same presentation name. 
  # Only used by WikiPage.new_using_template
  def make_rel_path_unique
       match = /_([\d]+)\.html/.match(self.rel_path)
        if match
          nr = (match[1].to_i + 1)
          self.rel_path = self.rel_path.gsub(match[0], "_#{nr}.html")
        else
          self.rel_path = self.rel_path.gsub('.html', '_1.html')
        end
  end

end
