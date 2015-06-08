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
  

  def teardown2
    [ENV['EPFWIKI_SITES_PATH'], ENV['EPFWIKI_WIKIS_PATH']].each do |p|
      FileUtils.rm_r(p) if File.exists?(p)
      FileUtils.makedirs(p)
    end
  end

  
  test "New" do
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @oup_20060721 = create_oup_20060721
    @oup_wiki = create_oup_wiki(@oup_20060721)
    @oup_20060728 = create_oup_20060728
    @html = IO.readlines('test/unit/page_test/test_html.txt').join.split("####")
    treebrowser_tag_count = 0
    copyright_tag_count = 0
    #text_count = 0
    body_tag_count = 0
    assert_equal 2, Wiki.count, "We should have the Templates and OpenUP Wiki"
    @oup_wiki.pages.each do |page|
      find_page = WikiPage.find_by_rel_path(page.rel_path) # assumes there is only 1 Wiki
      assert_not_nil find_page
      assert_equal page, find_page
      treebrowser_tag_count = treebrowser_tag_count + 1 if  !find_page.treebrowser_tag.nil?
      copyright_tag_count = copyright_tag_count + 1 if !find_page.copyright_tag.nil?
      #text_count = text_count + 1 if !find_page.text.nil?
      body_tag_count = body_tag_count + 1 if !find_page.body_tag.nil?
    end
    assert_equal 617, treebrowser_tag_count 
    assert_equal 617, copyright_tag_count 
    # assert_equal 617, text_count  
    assert_equal 617, body_tag_count 
  end
  
   test "Shim tag pattern" do
    @html = IO.readlines('test/unit/page_test/test_html.txt').join.split("####")
    assert_pattern(Page::SHIM_TAG_PATTERN, @html[4],    
        "images/shim.gif\"></td>")
    assert_pattern(Page::SHIM_TAG_PATTERN,@html[2],    
        "images/shim.gif\" />\n              </td>")
    assert_pattern(Page::SHIM_TAG_PATTERN, @html[3],    
        "images/shim.gif\"></td>")
  end
  
  test "Copyright pattern" do
    @html = IO.readlines('test/unit/page_test/test_html.txt').join.split("####")
    assert_pattern(Page::COPYRIGHT_PATTERN, @html[5],    
        "<p>Copyright (c) 1987, 2006 IBM Corp. and others. All Rights Reserved.\n\n                <br />This program and the accompanying materials are made available under the\n\n                <br />\n\n                <a href=\"http://www.eclipse.org/org/documents/epl-v10.php\" target=\"_blank\">Eclipse Public License v1.0</a> which accompanies this distribution.</p>")
    assert_pattern(Page::COPYRIGHT_PATTERN, @html[2],    
        "<p>\n    Copyright (c) 1987, 2006 IBM Corp. and others. All Rights Reserved.<br />\n    This program and the accompanying materials are made available under the<br />\n    <a href=\"http://www.eclipse.org/org/documents/epl-v10.php\" target=\"_blank\">Eclipse Public License v1.0</a> which\n    accompanies this distribution.\n</p>")
  end
 
  # Shows:
  # 1. can extract title from the file using Page.uma_presentation_name_from_file
  test "Test title from file" do 
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @oup_20060721 = create_oup_20060721   
    filenames = Array.new
    filenames << ['about_base_concepts,_uvje4D_fEdqDFvujd6NHiA.html','About Base Concepts']
    filenames << ['any_role,_3TCEoeB5EdqnKu908IEluw.html', 'Any Role']
    filenames << ['determine_architectural_feasibility_0oreoclgEdmt3adZL5Dmdw_desc.html', 'Determine Architectural Feasibility']
    for filename in filenames
      page = Page.find_by_filename(filename[0])
      assert_not_nil page
      assert_equal filename[1], Page.uma_presentation_name_from_html(page.html)
    end
    #pages = Page.find(:all)
  end
  
  # Shows:
  # 1. There should always be a Wiki 'Templates'. It is create with the first user.  
  # 2. Creating a new page creates a page, a version, a checkout
  # 3. A Page file does exist after new page, before checkin
  # 4. A Version file is created and prepared for edit
  # 5. Notification record is created for the page after checkin
  # 6. We can create another new page with the same presentation name
  test "New page using template" do
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @oup_20060721 = create_oup_20060721
    @oup_wiki = create_oup_wiki(@oup_20060721)
    #@oup_20060728 = create_oup_20060728
    # 1
    # TODO disabled after upgrade. Is a result from using factories not fixtures
    # assert_raise(RuntimeError) {Site.templates}
    # create_templates # Using templates plugin to create the 'Templates' Wiki
    assert_equal 26, Site.templates.size
    @templates = Wiki.find(:first, :conditions => ['title = ?', 'Templates'])
    # 2
    pc, vc, cc = Page.count, Version.count, Checkout.count
    tool_tpl = WikiPage.find_by_presentation_name('Toolmentor Template')
    assert_not_nil tool_tpl
    assert_equal @templates, tool_tpl.site
    assert_equal [0,0,0], [Page.count - pc, Version.count - vc, Checkout.count - cc]
    assert_equal 1, Version.count(:conditions => ['page_id=? and wiki_id =?', tool_tpl.id, @templates.id])
    source_version = tool_tpl.current_version
    assert_not_nil source_version
    new_page, new_co = WikiPage.new_using_template(:presentation_name => 'New Tool Mentor created in test10_new_page_using_tempalte', 
      :source_version => source_version, :user => @andy, :site => @oup_wiki)
    #5
    assert_no_errors(new_page)
    assert_no_errors(new_co)
    assert_equal [1,1,1], [Page.count - pc, Version.count - vc, Checkout.count - cc]    
    assert_equal new_co, new_page.checkout
    new_page.reload
    assert_equal 'New Tool Mentor created in test10_new_page_using_tempalte', new_page.presentation_name
    assert_equal 'new_tool_mentor_created_in_test10_new_page_using_tempalte.html', new_page.filename
    assert_equal "#{ENV['EPFWIKI_ROOT_DIR']}#{ENV['EPFWIKI_PUBLIC_FOLDER']}/#{ENV['EPFWIKI_WIKIS_FOLDER']}/openup/new/guidances/toolmentors/#{new_page.filename}", new_page.path 
    # 3
    assert File.exists?(new_page.path)
    # 4
    assert File.exists?(new_co.version.path)
    assert_version_file(new_co.version.path)
    # 5
    new_co.checkin(@andy)
    assert Notification.find_all_users(new_page, Page.name).include?(@andy)
    # 6
    new_page2, new_co2 = WikiPage.new_using_template(:presentation_name => 'New Tool Mentor created in test10_new_page_using_tempalte', :source_version => source_version, :user => @andy, :site => @oup_wiki)  
    assert_no_errors(new_page2)
    assert_no_errors(new_co2)
    new_co2.checkin(@andy)
    assert_equal new_page.rel_path.gsub('.html', '_1.html'), new_page2.rel_path
    new_page3, new_co3 = WikiPage.new_using_template(:presentation_name => 'New Tool Mentor created in test10_new_page_using_tempalte', :source_version => source_version, :user => @andy, :site => @oup_wiki)  
    assert_no_errors(new_page3)
    assert_no_errors(new_co3)
    new_co3.checkin(@andy)
    assert_equal new_page.rel_path.gsub('.html', '_2.html'), new_page3.rel_path
  end
  
  # Shows: we do get uma_type, uma_presentation_name, uma_name, body_tag, treebrowser_tag and copyright tag from the HTML
  test "Patterns" do 
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @wiki = Wiki.find(:first)
    assert_equal 'Templates', @wiki.title
    assert_equal ["CustomCategory",
     "Discipline",
     "Domain",
     "Checklist",
     "Concept",
     "EstimationConsiderations",
     "Example",
     "Guideline",
     "Guideline",
     "Practice",
     "Report",
     "ReusableAsset",
     "Roadmap",
     "SupportingMaterial",
     "Template",
     "TermDefinition",
     "ToolMentor",
     "Whitepaper",
     "Role",
     "RoleSetGrouping",
     "RoleSet",
     "Task",
     "Artifact",
     "Deliverable",
     "Outcome",
     "WorkProductType"].sort, @wiki.pages.collect {|page| page.uma_type.name}.sort
    assert_equal ["Templates",
"Discipline Template",
"Domain Template",
"Checklist Template",
"Concept Template",
"Estimation Considerations Template",
"Example Template",
"Estimating Guideline Template",
"Guideline Template",
"Practice Template",
"Report Template",
"Reusable Asset Template",
"Roadmap Template",
"Supporting Material Template",
"Template Template",
"Term Definition Template",
"Toolmentor Template",
"Whitepaper Template",
"Role Template",
"Role Set Grouping Template",
"Role Set Template",
"Task Template",
"Artifact Template",
"Deliverable Template",
"Outcome Template",
"Work Product Kind Template"].sort, @wiki.pages.collect {|page| page.presentation_name}.sort
    assert_equal ["view", "discipline_template", "domain_template", "checklist_template", 
    "concept_template", "estimation_considerations_template", "example_template", 
    "estimating_guideline_templae", "guideline_template", "practice_template", "report_template", 
    "reusable_asset_template", "roadmap_template", "supporting_material_template", 
    "template_template", "term_definition_template", "toolmentor_template", "whitepaper_template", 
    "role_template", "role_set_grouping_template", "role_set_template", "task_template", 
    "artifact_template", "deliverable_template", "outcome_template", "work_product_kind_template"].sort, @wiki.pages.collect {|page| page.uma_name}.sort
    assert_equal ["<body>"]*26, @wiki.pages.collect {|page| page.body_tag} 
    @wiki.pages.each do |p|
      assert_equal [p.filename, true, true, true, true], [p.filename, p.treebrowser_tag.include?('treebrowser.js'), p.treebrowser_tag.include?('<script'), p.treebrowser_tag.include?('script>'), p.copyright_tag.include?('http://www.eclipse.org/org/documents/epl-v10.php')]
    end
  end
  
  # Shows:
  # 1. we replace 'UMA Method Architecture' with 'Unified Method Architecture (UMA)' in about base concepts
  # 2. we create a new page based on that changed version and then remove 'Method'
  test "New page using other page" do
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y') 
    @oup_20060721 = create_oup_20060721
    @oup_wiki = create_oup_wiki(@oup_20060721)
    @oup_20060728 = create_oup_20060728    
    # 1 
    assert_equal 1, WikiPage.find(:all, :conditions => ['presentation_name=?','About Base Concepts']).size
    page = WikiPage.find_by_presentation_name('About Base Concepts')
    assert !page.nil? 
    assert_equal [617+26, 617+26, (617*3) + (2*26), 617*2+ 26], [Version.count, WikiPage.count, Page.count, BaselineProcessPage.count]
    assert_equal 1, page.versions.size
    checkout = Checkout.new(:user => @andy, :page => page, :site => @oup_wiki, :note => 'test13_new_page_using_other_page')
    assert checkout.save
    checkout.reload
    page.reload
    assert_equal 'test13_new_page_using_other_page', checkout.version.note
    assert_equal 1, page.versions.size # versions doesn't count checked out
    assert_equal nil, checkout.version.version
    checkout.checkin(@andy, checkout.version.html.gsub('UMA Method Architecture', 'Unified Method Architecture (UMA)'))
    page.reload
    assert_equal 2, page.versions.size
    version = page.current_version
    assert_equal 1, version.version
    assert version.html.index('Unified Method Architecture (UMA)')
    assert page.html.index('Unified Method Architecture (UMA)')
    assert_enhanced_file(page.path)
    assert_version_file(version.path)
    # 2
    pages_count = @oup_wiki.pages.count
    @pages = @oup_wiki.pages.collect{|p|p.rel_path}
    params = Hash.new
    params[:page] = {:presentation_name => 'New page created using base concepts', :source_version => version.id, :user => @andy, :site => @oup_wiki}
    page, co = WikiPage.new_using_template(params[:page])
    assert_not_nil page
    assert_equal [], page.errors.full_messages
    assert_not_nil co
    page.reload
    co.reload
    @oup_wiki.reload
    assert_equal ["base_concepts/guidances/supportingmaterials/new_page_created_using_base_concepts.html"], 
          (@oup_wiki.pages.collect{|p|p.rel_path} - @pages)
    assert_equal pages_count + 1, @oup_wiki.pages.reload.count # don't understand the reload but anyway...grasping at straws
    assert_equal 0, page.versions.size # checkouts are not counted here
    v = co.version
    assert_not_nil v
    assert_not_nil v.version_id 
    assert_equal version, v.source_version # the template version
    assert v.previous_version.nil? # the first version of a new page
    checkout = page.checkout
    assert_not_nil checkout
    assert checkout.version.html.index('Unified Method Architecture (UMA)')
    assert_not_nil checkout.version.source_version
    p = checkout.version.source_version.path
    assert_version_file(p)
    checkout.checkin(@andy, checkout.version.html.gsub('Unified Method Architecture (UMA)','Unified Architecture (UMA)'))
    version = page.current_version
    assert_equal 1, version.version
    assert version.html.index('Unified Architecture (UMA)')
    assert page.html.index('Unified Architecture (UMA)')
    Rails.logger.debug("Page test: test enhanced: \n#{page.html}")
    assert_enhanced_file(page.path)
    Rails.logger.info("assert_version_file: #{version.path}\n should be same as: #{p}")
    assert_version_file(p)
    assert_version_file(version.path)
  end

  # Shows:
  # 
  test "Max rel path" do 
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @oup_20060721 = create_oup_20060721
    max_rel_path = 0 
    @oup_20060721.pages.each do |page|
      max_rel_path = page.rel_path.length if page.rel_path.length > max_rel_path
    end
    assert_equal 101, max_rel_path
  end
  
  test "Make rel path unique" do
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    page = WikiPage.find_by_presentation_name('Toolmentor Template')
    assert_equal 'new/guidances/toolmentors/toolmentor_template_E9930C53.html', page.rel_path
    for i in 1..15
      page.make_rel_path_unique
      assert_equal "new/guidances/toolmentors/toolmentor_template_E9930C53_#{i}.html", page.rel_path
    end
  end
  
  "Test if we can extract from overview table"
  test "Overview table" do
    Rails.logger.info("Page test: overview table")
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    page = WikiPage.find_by_presentation_name('Concept Template')
    assert_equal "A concept is a specific type of guidance that outlines key ideas associated with basic principles underlying the referenced item. Concepts normally address more general topics than guidelines and may be applicable to several work products, tasks, and activities.<br/>&#xD;&#xA;", page.overview_table
    WikiPage.find(:all).each do |page|
      Rails.logger.info("   test overview table of #{page.path}")
      if ['Templates'].include? page.presentation_name and !page.filename.include? "view_"  
      # Not all pages have a overview table
      # We exclude the view page that EPFC generates
        assert_equal [page.presentation_name, false], [page.presentation_name, page.overview_table.blank?]
      end
    end
  end

end
