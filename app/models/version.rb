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

class Version < ActiveRecord::Base
  
  belongs_to  :user
  belongs_to  :wiki, :foreign_key => 'wiki_id' # TODO not necessary?
  belongs_to  :page
  has_one     :checkout
  belongs_to  :source_version,        :class_name => 'Version', :foreign_key => 'version_id'
  belongs_to  :reviewer,              :class_name => 'User',    :foreign_key => 'reviewer_id'
  has_many    :child_versions,        :class_name => 'Version', :foreign_key => 'version_id'
  has_many    :comments
  
  before_destroy :delete_file

  attr_accessor :type_filter # used for selection filter

  # NOTE: it is not possible to use 'update' below, this is reserved by ActiveRecord. 
  # If you use it, the record won't save
  belongs_to  :baseline_update, :class_name => 'Update', :foreign_key => 'update_id'
  
  validates_presence_of :user, :wiki, :page
  
  BODY_PATTERN = /<body.*<\/body>/m
  LINKS_PATTERN = /<a.*?href=".*?".*?<\/a>/
  HREF_PATTERN = /href="(.*?)"/

  DIFF_STYLE =   ["<style type=\"text/css\">",
"ins { text-decoration: none; background-color: #ff0; color: #057508; }
del { text-decoration: line-through; color: #f00; }

div>ins, ul>ins, div>del, ul>del, body>ins, body>del { display: block; }",
"</style>"].join("\n")
  
  def previous_version
    case self.version
    when 0 then nil 
    when nil # TODO when the version no is nil, it is a checked out version
      if true
      self.page.current_version 
      end
    else Version.find(:first, :conditions => ['page_id=? and version=?', self.page_id, self.version - 1])
    end
  end
  
  # TODO this doesn't add value
  def baseversion
    return Version.find(:first, :conditions => ['wiki_id = ? and page_id=? and version=0',
    self.wiki_id, self.page_id])
  end  
  
  def current_version
    return self.page.current_version
  end
  
  # return the latest version of page in a site
  def self.find_latest_version(site, page)
    return Version.find(:first ,:order => 'version DESC', :conditions => ["page_id=? and wiki_id =?", page.id, site.id])    
  end  
  
  # return the latest version based on a version
  # TODO use page.last_version
  def latest_version
    return Version.find(:first ,:order => 'version DESC', :conditions => ["page_id=? and wiki_id =?", self.page, self.wiki])    
  end
  
  # Returns relative path of a version in folder 'public', 
  # the column rel_path stores the relatieve path in a Site folder
    def rel_path_root
    return self.path.gsub("#{ENV['EPFWIKI_ROOT_DIR']}#{ENV['EPFWIKI_PUBLIC_FOLDER']}/", '')
  end
  
  def html
    IO.readlines(self.path).join
  end

  # Create the tmp diff source file, clean it using Tidy and prepare for use with XHTMLDiff 
  def html4diff(h = nil)
    logger.info("Create tmp diff source file #{self.path_to_tmp_diff_html} using #{self.path}")    
    h = IO.readlines(self.path).join if h.nil?
    html = Nokogiri.HTML(h)
    xhtml = html.to_xhtml
    h = BODY_PATTERN.match(xhtml.to_s)[0]
    h = h.gsub(/<[\/]{0,1}(tbody){1}[.]*>/, '') 
    h = h.gsub(Page::TREEBROWSER_PATTERN,'') 
    h = h.gsub(Page::TREEBROWSER_PLACEHOLDER,'')
    h = h.gsub(Page::TREEBROWSER_PATTERN,'')
    h = h.gsub(Page::TREEBROWSER_PLACEHOLDER,'')
    h = h.gsub('&#13;','').gsub('nowrap="nowrap"','').gsub('width="100%"','width="99%"')#.gsub('&#13;','')
    h = h.gsub(/guid="(.*?)"/, '') # v0 diffs
    h = h.gsub('<div id="breadcrumbs"></div>','')
    h = h.gsub('class="sectionTable" border="0" cellspacing="0" cellpadding="0"', 'border="0" cellspacing="0" cellpadding="0" class="sectionTable"')
    h = h.gsub('cellspacing="0" cellpadding="0"', 'cellpadding="0" cellspacing="0"') # v0: TinyMCE changes sort
    h = h.gsub('<p></p>','') # TinyMCE adds empty p element
    
    
    h = h.gsub(/title="(.*?)"/, '') 
    logger.debug("html4diff #{self.path}: ")
    file = File.new(self.path_to_tmp_diff_html, 'w')
    file.puts(h)
    file.close
    h 
  end

  # Create diff results using XHTMLDiff
  def xhtmldiff(from_version)
    content_to = "<div>\n" + self.html4diff + "\n</div>"
    content_from = "<div>\n" + from_version.html4diff + "\n</div>"

    diff_doc = REXML::Document.new
    diff_doc << (div = REXML::Element.new 'div')
    hd = XHTMLDiff.new(div)
    
    parsed_from_content = REXML::HashableElementDelegator.new(REXML::XPath.first(REXML::Document.new(content_from), '/div'))
    parsed_to_content = REXML::HashableElementDelegator.new(REXML::XPath.first(REXML::Document.new(content_to), '/div'))
    Diff::LCS.traverse_balanced(parsed_from_content, parsed_to_content , hd)
    diffs = ''
    diff_doc.write(diffs, -1, true, true)
    diffs    
  end
  
  # Create diff file using #xhtmldiff. The file is generated if doesn't exist of if one of the versions is checked out.
  def xhtmldiffpage(from_version, force = true)
    p = path_to_diff(from_version)
      if !File.exists?(p) || !from_version.checkout.nil? || !self.checkout.nil? || force
      logger.info("Generating xhtmldiffpage #{p}")
      diffs = xhtmldiff(from_version)
      h = Nokogiri::HTML(page.html).to_html
      body_tag = Page::BODY_TAG_PATTERN.match(h)[0]
      h = h.gsub(BODY_PATTERN,body_tag + diffs + '</body>')
      h = h.gsub('</head>',DIFF_STYLE + '</head>')
      h = h.gsub(Page::PAGE_HEAD_SNIPPET_PATTERN, '')
      file = File.new(p, 'w')
      file.puts(h)
      file.close
    end
  end
  
  # Absolute path to the diff file and paths to the intermediate (tidied, cleaned) HTML files
  def path_to_diff(from_version)
    "#{ENV['EPFWIKI_ROOT_DIR']}#{ENV['EPFWIKI_PUBLIC_FOLDER']}/#{relpath_to_diff(from_version)}"
  end
  
  # Relative path to the diff file
  def relpath_to_diff(from_version)
    '/' + self.wiki.rel_path + '/' + self.page.rel_path + "_EPFWIKI_DIFF_V#{from_version.version}_V#{self.version}.html"  
  end
  
  def url_to_diff(from_version)
    ENV['EPFWIKI_BASE_URL'] + self.relpath_to_diff(from_version)
  end
  
  # Path intermediate (tidied, cleaned) HTML files, prepared for XHTMLDiff
  def path_to_tmp_diff_html
    FileUtils.makedirs(ENV['EPFWIKI_DIFFS_PATH']) unless File.exists?(ENV['EPFWIKI_DIFFS_PATH'])    
    "#{ENV['EPFWIKI_DIFFS_PATH']}#{self.id.to_s}.html"  
  end
  
  # Compares hrefs to determine new or added 
  #--
  # Depends on covert_urls settings of TinyMCE
  #++
  # TODO diff enhancement
  #def diff_links(from_version)
  #  links = self.html.scan(LINKS_PATTERN)
  #  links_from = from_version.html.scan(LINKS_PATTERN)
  #  hrefs = links.collect {|link | HREF_PATTERN.match(link)[0]}
  #  hrefs_from = links_from.collect {|link | HREF_PATTERN.match(link)[0]}
  #  new_removed = [hrefs - hrefs_from, hrefs_from - hrefs]
  #  new_removed
  #end
  
  # TODO diff enhancement
  #def diff_img(from_version)
  #end

  #def diff_area_links
  #end
   
  def template?
    self.wiki.title == 'Templates' 
  end
  
  def base_version?
    !user_version?
  end
  
  def user_version?
    baseline_process_id.nil?
  end
  
  # #version_text returns version number, site title and baseline,
  # for example <tt>1 from OpenUP(OUP_20060721)</tt>
  def version_text
    if self.base_version? 
      return self.version.to_s + ' from ' + self.wiki.title + ' (' + self.baseline_process.title+ ')'
    else
      return self.version.to_s + ' from ' + self.wiki.title + ' (' + self.user.name + ')'
    end
  end
  
  def delete_file
    logger.debug("Before Destroy: deleting file #{self.path}")
    File.delete(self.path)
  end
  
  # #uma_type_descr is used to retrieve the brief description for a template, see app/views/pages/new
  def uma_type_descr
    logger.debug("Returning uma_type_description from: #{self.inspect}")
    if self.note.blank? || self.note == 'Automatically created'
      match = /<table class="overviewTable".*?<td valign="top">(.*?)<\/td>/m.match(self.html)
      if match
        self.note = match[1]
        self.save!
        logger.info("Match found: #{self.note}")
      else
        logger.debug('No match')
      end
    end
    return self.note
  end
  
end
