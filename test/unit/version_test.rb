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

require 'test_helper'

class EpfcLibraryTest < ActiveSupport::TestCase

  def teardown
    [ENV['EPFWIKI_SITES_PATH'], ENV['EPFWIKI_WIKIS_PATH']].each do |p|
      FileUtils.rm_r(p) if File.exists?(p)
      FileUtils.makedirs(p)
    end
  end
  
  # Shows:
  # 1. We cannot checkout to baseline process, only to a Wiki
  # 2. We cannot write the html from a BaselineProcessVersion
  # 4. The path of a BaselineProcessVersion is just the path of the Page
  test "Various" do
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'C')
    @oup_20060721 = create_oup_20060721
    @oup_wiki = create_oup_wiki(@oup_20060721)
    @oup_20060728 = create_oup_20060728 
    @oup_20060825 = create_oup_20060825
    #raise "'"
    #@andy = users(:andy) 
    #@#tony = users(:tony) 
    #@cash = users(:cash) 
    #@emails = ActionMailer::Base::deliveries
    #@emails.clear
    
    # Used to be 617 but is 643 after upgrade as a result of replacing fixtures with factories
    # This causes Templates wiki te be created with 26 additional files/versions
    assert_equal [0, 617+26], [UserVersion.count, BaselineProcessVersion.count]  
    
    page = WikiPage.find(:first, :conditions => ['filename = ? and site_id = ?','test_data,_0ZZFcMlgEdmt3adZL5Dmdw.html', @oup_wiki])
    page.reload
    assert_equal 1, page.versions.size
    assert_equal 0, page.current_version.version
    co = Checkout.new(:user => @andy, :page => page, :site => @oup_20060825, :source_version => page.current_version)
    assert_raise(RuntimeError) {co.save}
    # 2
    assert_raise(NoMethodError) {page.current_version.html = 'version3 from @oup_wiki'}
    # 3
    page = WikiPage.find_by_filename('test_data,_0ZZFcMlgEdmt3adZL5Dmdw.html')
    assert_not_nil page
    version = page.current_version
    assert_equal 0, version.version
    bp_page = BaselineProcessPage.find_by_filename('test_data,_0ZZFcMlgEdmt3adZL5Dmdw.html')
    assert_equal bp_page.path, version.path
  end

  # Shows:
  # 1. The first version (version 0) does not have a previous_version
  # 2. We create version 1: previous_version is equal to the first version
  # 3. We create version 2 which has some added text 
  # 4. We can rollback changes by creating version 3 based on version 1
  # 5. Shows we can make a version 'current'
  # 6. Checkout doesn't change the 'current' version but checkin does  
  test "Various 2" do
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'C')
    @oup_20060721 = create_oup_20060721
    @oup_wiki = create_oup_wiki(@oup_20060721)
    @oup_20060728 = create_oup_20060728 
    @oup_20060825 = create_oup_20060825    
    page = WikiPage.find_by_filename('implementation,_0TeDoMlgEdmt3adZL5Dmdw.html')
    page.reload
    assert_not_nil page.versions
    assert File.exists?(page.path)
    cv0 = page.current_version
    assert_equal BaselineProcessVersion.name, cv0.class.name
    assert_equal 0, cv0.version 
    # 1
    assert_equal nil, cv0.previous_version 
    # 2
    # creating a new version
    co = Checkout.new(:user => @andy, :page => page, :site => @oup_wiki, :source_version => cv0)
    
    #puts "co errors: " + co.errors.inspect
    assert co.save! 
    # TODO co.save werkt niet meer na upgrade, 
    # co.save! geeft ActiveRecord::RecordInvalid: Validation failed: Version can't be blank
    
    co.checkin(@andy)
    cv1 = page.current_version
    assert_equal 1, cv1.version
    assert_equal cv1.previous_version, cv0
    # 3
    co = Checkout.new(:user => @andy, :page => page, :site => @oup_wiki, :source_version => cv1)
    assert co.save
    cv2 = co.version
    assert_nil cv2.version # number is determined on checkin
    cv2.html = cv2.html.gsub('</body>', '####</body>')
    co.checkin(@andy)
    cv2.reload
    assert_equal 2, cv2.version
    assert page.html.include?('####')
    # 4
    co = Checkout.new(:user => @andy, :page => page, :site => @oup_wiki, :source_version => cv1)
    assert co.save
    cv3 = co.version
    h = cv3.html
    assert_not_nil h
    assert !h.include?('####')
    co.checkin(@andy)
    cv3.reload
    assert_equal 3, cv3.version
    assert_equal cv3, page.current_version
    assert !page.html.include?('####')
    # 5
    assert_equal page.current_version, page.last_version # because there is no checkout
    page.current_version = cv1 
    assert_equal cv1, page.current_version
    page.current_version = cv2 # let op cv1 is nu nog steeds current == true
    cv1.reload
    assert_equal false, cv1.current, "cv2 is current, not cv1"
    assert_equal cv2, page.current_version
    cv2.current = false 
    assert cv2.save
    assert cv2 != page.current_version
    assert_equal cv3, page.current_version
    # 6
    Rails.logger.info("version_test.rb making cv1 the current version")
    cv1.reload
    assert_equal false, cv1.current
    page.current_version = cv1 # we make cv1 current # let op cv1 is al current, althans in log file is v: gelijk aan current
    page.reload
    assert_equal cv1, page.current_version
    Rails.logger.info("version_test.rb doing checkout")
    co = Checkout.new(:user => @andy, :page => page, :site => @oup_wiki, :source_version => cv3)
    assert co.save
    cv4 = co.version
    Rails.logger.info("version_test.rb checking current version")
    assert_equal cv1, page.current_version 
    co.checkin(@andy)
    cv4.reload
    assert_equal cv4, page.current_version
    assert_equal cv4, page.last_version
    assert page.current_version.current.nil?
  end
  
  test "XHTMLDiff links" do
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'C')
    @oup_20060721 = create_oup_20060721
    @oup_wiki = create_oup_wiki(@oup_20060721)
    @emails = ActionMailer::Base::deliveries
    @emails.clear
    page = WikiPage.find_by_filename('implementation,_0TeDoMlgEdmt3adZL5Dmdw.html') 
    # setup the page html
    page_html = IO.readlines(File.expand_path("test/unit/version_test/xp_environment,3.754748120034442E-307.html", Rails.root.to_s)).join
    page.html = page_html
    for i in 1..3
      co = Checkout.new(:user => @andy, :page => page, :site => @oup_wiki, :source_version => page.current_version)
      assert co.save
      assert_equal nil, co.version.version
      co.checkin(@andy)
      cv = page.current_version
      assert_equal i, cv.version
      assert_not_nil cv.page_id
    end
    page.reload
    assert_equal 4, page.versions.size
    html0 = IO.readlines(File.expand_path("test/unit/version_test/xp_environment,3.754748120034442E-307.html_EPFWIKI_BL2_v0.html", Rails.root.to_s)).join
    html1 = IO.readlines(File.expand_path("test/unit/version_test/xp_environment,3.754748120034442E-307.html_EPFWIKI_BL2_v1.html", Rails.root.to_s)).join
    html2 = IO.readlines(File.expand_path("test/unit/version_test/xp_environment,3.754748120034442E-307.html_EPFWIKI_BL2_v2.html", Rails.root.to_s)).join 
    version1 = page.versions[1]
    version2 = page.versions[2]
    version3 = page.versions[3]
    assert_equal [1,2,3],[version1.version, version2.version, version3.version]
    version1.html = html0
    version2.html = html1
    version3.html = html2
    assert_equal 0, @emails.size
    [[version2,version1],[version3,version2]].each do |versions|
      versions[0].xhtmldiffpage(versions[1])
      assert_equal "#{versions[0].relpath_to_diff(versions[1])} generated 0 email", "#{versions[0].relpath_to_diff(versions[1])} generated #{@emails.size} email"      
    end
    html3 = IO.readlines(File.expand_path("test/unit/version_test/architect.html_EPFWIKI_BL1_v0.html", Rails.root.to_s)).join 
    html4 = IO.readlines(File.expand_path("test/unit/version_test/architect.html_EPFWIKI_BL1_v1.html", Rails.root.to_s)).join     
    version4 = page.versions[1]
    version5 = page.versions[2]
    version4.html = html3
    version5.html = html4
    version5.xhtmldiffpage(version4)
    page = WikiPage.find_by_filename('implementation,_0TeDoMlgEdmt3adZL5Dmdw.html')
    versions = []
    versions << ['xp_programmer.html_EPFWIKI_BL2_v0.html', page.versions[1], '']
    versions << ['xp_programmer.html_EPFWIKI_BL2_v1.html', page.versions[2], '']
    versions.each do |v|
      v[2] = v[1].html # save the html, so we can rollback changes
      v[1].html = IO.readlines(File.expand_path("test/unit/version_test/#{v[0]}", Rails.root.to_s)).join
    end
    #links  = versions[0][1].diff_links(versions[1][1])  # new, removed
    #assert_equal [["href=\"./../../xp/guidances/concepts/coding_standard,8.8116853923311E-307.html\""],
    #["href=\"http://www.demo.epfwiki.net/wikis/openup/openup_basic/customcategories/resources/GetStarted_48.gif\""]], 
    #links
  end
  
  test "Diff v0v1" do

    v0 = File.read(File.join(Rails.root, 'test', 'unit', 'version_test', 'guideline_template_B677C878.html'))
    v1 = File.read(File.join(Rails.root, 'test', 'unit', 'version_test', 'guideline_template_B677C878.html_EPFWIKI_v1.html'))
    v0_noko, v1_noko = Nokogiri.HTML(v0).to_xhtml, Nokogiri.HTML(v1).to_xhtml
    v0_body, v1_body = Version::BODY_PATTERN.match(v0_noko.to_s)[0], Version::BODY_PATTERN.match(v1_noko.to_s)[0]
    # TODO volgende kan veel handiger, vraag is hoe, in Ruby, zonder duplication, drama
    v0_body = v0_body.gsub(Page::TREEBROWSER_PATTERN,'') # TODO
    v0_body = v0_body.gsub(Page::TREEBROWSER_PLACEHOLDER,'') # TODO
    v0_body = v0_body.gsub(Page::TREEBROWSER_PATTERN,'') # TODO
    v0_body = v0_body.gsub(Page::TREEBROWSER_PLACEHOLDER,'') # TODO
    v0_body = v0_body.gsub('&#13;','').gsub('nowrap="nowrap"','').gsub('width="100%"','width="99%"')
    v1_body = v1_body.gsub(Page::TREEBROWSER_PATTERN,'') # TODO
    v1_body = v1_body.gsub(Page::TREEBROWSER_PLACEHOLDER,'') # TODO
    v1_body = v1_body.gsub(Page::TREEBROWSER_PATTERN,'') # TODO
    v1_body = v1_body.gsub(Page::TREEBROWSER_PLACEHOLDER,'') # TODO
    v1_body = v1_body.gsub('&#13;','').gsub('nowrap="nowrap"','').gsub('width="100%"','width="99%"')
      # TODO javascript

    [[v0_body, 'guideline_template_body_v0.html'],[v1_body, 'guideline_template_body_v1.html']].each do |f|
      file = File.new(File.join(Rails.root, 'tmp',f[1]), 'w')
      file.puts f[0]
      file.close  
    end

    content_to = "<div>\n" + v0_body + "\n</div>"
    content_from = "<div>\n" + v1_body + "\n</div>"

    diff_doc = REXML::Document.new
    diff_doc << (div = REXML::Element.new 'div')
    hd = XHTMLDiff.new(div)
    
    parsed_from_content = REXML::HashableElementDelegator.new(REXML::XPath.first(REXML::Document.new(content_from), '/div'))
    parsed_to_content = REXML::HashableElementDelegator.new(REXML::XPath.first(REXML::Document.new(content_to), '/div'))
    Diff::LCS.traverse_balanced(parsed_from_content, parsed_to_content , hd)
    diffs = ''
    diff_doc.write(diffs, -1, true, true)

    diffs.gsub('&#13;','')

    file = File.new(File.join(Rails.root, 'tmp','guideline_template_diffs.html'), 'w')
    file.puts diffs
    file.close  

  end
  
end
