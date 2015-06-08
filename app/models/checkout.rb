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

# A Checkout is a working copy (Version) of a Page created so that 
# it can be edited. The HTML to create the version is typically 
# copied from the source version but it is also possible to provide it
# using the parameter :html

class Checkout < ActiveRecord::Base
  
  belongs_to :version # Version we are creating
  belongs_to :user
  belongs_to :page
  belongs_to :site
  
  attr_accessor :source_version # Version we are checking out
  
  # Note supplied with checkout will be used to create Version.note
  attr_accessor :note
  attr_accessor :html
  
  validates_presence_of :user, :page, :site, :version, :source_version

  before_validation :validate_checkout, :on => :create
  validate :cant_co_from_bp, :on => :create
    
  HTML_START_ELEMENT = /<html([^\<])*/
  
  def undo
    logger.info("Undo of checkout #{self.id}")
    self.version.destroy
    self.page.destroy if self.page.versions.size == 0 # If no versions remain, this must be a new page, so we also remove the page
    self.destroy
  end
  
  def checkin(user, h = nil)
    logger.info("Checkin of version #{self.version.path}")
    raise 'Cannot checkin, checked is not owned by user' if user != self.user && !user.cadmin?
    h = self.version.html if h.nil?

    # reset current attribute if set on a version
    cv = self.page.current_version 
    if !cv.nil? && cv.current
      cv.current = false
      cv.save!
    end
    Notification.find_or_create(self.page, self.user, Page.name)
    old_path = self.version.path
    self.version.version = self.page.max_version_no + 1
    self.version.rel_path = "#{self.page.rel_path}_EPFWIKI_v#{self.version.version}.html"
    logger.info("Moving version file from #{old_path} to #{self.version.path}")
    FileUtils.move(old_path, self.version.path)
    self.version.save!
    
    # Correct head tag of version file
    # TODO rename HEAD_PATTERN -> HEAD_REGEXP
    unless h.index(Page::HEAD_PATTERN).nil?
      logger.info("Head element found, replacing it with head element of original page")
      h = h.gsub(Page::HEAD_PATTERN, self.page.head_tag)
    else
      unless h.index(HTML_START_ELEMENT).nil?
        logger.info("HTML element found, adding a head element to it")
        h = h.gsub(HTML_START_ELEMENT, HTML_START_ELEMENT.match(h)[0] + self.page.head_tag)
      else
        logger.info("No head or html element found, adding head element")
        h = self.page.head_tag + h
      end
    end
    logger.info("Removing EPF Wiki Javascript library includes")
    h = h.gsub(Page::PAGE_HEAD_SNIPPET_PATTERN,'') if h.index(Page::PAGE_HEAD_SNIPPET_PATTERN)
    self.version.html = Nokogiri::HTML(h).to_html # this wil force html, body tags
    
    # copy version to page and enhance
    self.page.html = self.version.html # version html does not have body
    self.page.body_text = Nokogiri::HTML(h.gsub(/<script.*?<\/script>/m,'')).text
    self.page.save!
    Page.enhance_file(self.page.path) 
    h= self.page.html
    h = h.gsub(Page::BODY_TAG_PATTERN, self.page.body_tag ) if self.page.body_tag
    h = h.gsub(Page::TREEBROWSER_PLACEHOLDER, self.page.treebrowser_tag) if self.page.treebrowser_tag
    h = h.gsub(Page::COPYRIGHT_PLACEHOLDER, self.page.copyright_tag) if self.page.copyright_tag
    h = h.gsub('class="pageTitle"', 'nowrap="true" class="pageTitle"') # TODO workaround for 250148: No-wrap should be part of CSS file https://bugs.eclipse.org/bugs/show_bug.cgi?id=250148
    h = Nokogiri::HTML(h).to_html # this wil force html, body tags
    h = h.gsub(/<\/body>/,Page::BODY_CLOSING_TAG) # Put back in the contentPage.onload
    self.page.html = h
    # TODO set title equal to pageTitle? 
    self.destroy
  end
  
  def validate_checkout
    logger.info("Before validation on create of checkout for #{self.page.presentation_name}")
    raise "Versions can only be created in Wiki sites" if !self.site.wiki?
    raise "Cannot create a checkout, a checkout already exists" if self.page.checkout 
    
    self.source_version = self.page.current_version if self.source_version.nil?
    
    logger.debug("Creating version for checkout")
    self.version = UserVersion.new(:wiki => self.site, :page => self.page, :user => self.user, :source_version => self.source_version)
    self.version.rel_path = "#{self.page.rel_path}_EPFWIKI_co.html"    
    FileUtils.makedirs(File.dirname(self.version.path))
    self.version.note = self.note
    # Method #prepare_for_edit is used to prepare the file for editing in 
    # the HTML editor that runs in the browser:
    # 1. onload event is removed from the body element
    # 2. Javascript lib treebrowser.js that chrashes the editor is replaced by a placeholder comment tag
    # 3. the EPF iframe element is removed
    # 4. the copyright_tag is replaced by a placeholder tag # DISABLED, didn't work after upgrade of EPF
    # 5. head tag is removed, because this TinyMCE cannot (and should not) manage this (this was BUG 96 - Doubling meta-tags)
    # 6. replace IBM contentPage.onload for normal body tag
    # 
    # See also #Page.before_create 
    #-- 
    # TODO step 4 does not seem to work anymore with current version of OpenUP (EPF) 
    # TODO move to version as part of checkout
    #++ 
    h = self.source_version.html if h.blank?
    h = h.gsub(Page::BODY_TAG_PATTERN, '<body>') # 1
    h = h.gsub(Page::TREEBROWSER_PATTERN, Page::TREEBROWSER_PLACEHOLDER) # 2
    #html = html.gsub(COPYRIGHT_PATTERN, COPYRIGHT_PLACEHOLDER) # 4
    h = h.gsub(Page::HEAD_PATTERN, '') # 5
    h = h.gsub(Page::BODY_CLOSING_TAG_PATTERN, '</body>') # 6
    self.version.html = h
  end
  
  def cant_co_from_bp
    logger.debug('validate_on_create')
    errors.add(:site, 'can\'t be a baseline process') if self.site.baseline_process?
  end  
  
end
