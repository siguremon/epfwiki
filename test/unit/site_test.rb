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


  def setup
    teardown
  end

  def teardown
    [ENV['EPFWIKI_SITES_PATH'], ENV['EPFWIKI_WIKIS_PATH']].each do |p|
      FileUtils.rm_r(p) if File.exists?(p)
      FileUtils.makedirs(p)
    end
  end
  
  # Shows:
  # 1. To create a new BaselineProcess we have to specifiy: title, folder, baseline, user
  # 2. We cannot create a BaselineProcess from non-existing folder
  # 3. We can create a BaselineProcess
  # 4. We cannot use a folder twice (create two or more sites from the same folder)
  # 5. We can scan the content
  test "New baseline process" do
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    create_oup_20060721
    BaselineProcess.destroy_all
    # 1.
    site = BaselineProcess.new
    assert !site.save
    assert_equal "Folder can't be blank, Folder does not seem to contain a valid site, no index.htm was found, Title can't be blank, User can't be blank", site.errors.full_messages.sort.join(", ")
    # 2.
    site_count = Site.count
    site = BaselineProcess.new(:folder => 'nonexistingfolder', :title => 'OUP_20060721', :user_id => @george.id)
    assert !site.save
    assert_equal 'Folder doesn\'t exist, Folder does not seem to contain a valid site, no index.htm was found', site.errors.full_messages.join(', ')        
    assert_equal site_count, Site.count
    # 3.
    site = BaselineProcess.new(:folder => 'oup_20060721', :title => 'oup_20060721', :user_id => @george.id)
    #assert
    site.save
    assert_equal '', site.errors.full_messages.join(', ')
    assert_equal site_count + 1, Site.count
    site = Site.find(site.id)
    # 4.
    site = BaselineProcess.new(:folder => 'oup_20060721', :title => 'oup_20060721', :user_id => @george.id)
    assert !site.save
    assert_equal 'Folder was already used to create a baseline process', site.errors.full_messages.join(', ')
    assert_equal site_count + 1, Site.count    
    # 5.
    sites = BaselineProcess.find_2scan
    assert_equal 1, sites.size
    site = sites[0]
    assert_equal ['oup_20060721', 'oup_20060721'], [site.title, site.folder]
    assert site.content_scanned_on.nil?
    site.scan4content
    assert_not_nil site.content_scanned_on
    assert_equal 617, site.pages.size
    #site.versions[0..3].each do |v|
    #  assert_equal [true, 0, false, false, false, false], [v.base_version?, v.version, v.rel_path.nil?, v.wiki_id.nil?, v.user_id.nil?, v.page_id.nil?]
    #end
    site.pages[0..3].each do |p|
      assert_equal [false, false, 'BaselineProcessPage', 'EPFC', 'N.A.', false, false, false, false,false,false], [p.rel_path.nil?, p.presentation_name.nil?, p.type, p.tool, 
        p.status, p.uma_type.nil?, p.filename.nil?, p.uma_name.nil?, p.body_tag.nil?, p.treebrowser_tag.nil?, p.copyright_tag.nil?]
    end
  end

  # Shows:
  # 1. we cannot unzip same content twice
  test "Upload" do
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @oup_20060721 = create_oup_20060721
    # 1
    assert_raise(RuntimeError){@oup_20060721.unzip_upload}
    names = ['OpenUP_Basic_published-0.9-W-20070316']
    assert_equal 'openup_basic_published09w20070316', Utils.valid_filename(names[0])    
  end
  
  # Shows:
  # 1. To create a Wiki we need to specifiy a folder, title and user
  # 2. We create a Wiki
  # 3. We try to schedule an Update of the Wiki but we mix things up
  # 4. We schedule an Update of the Wiki with a BaselineProcess
  # 5. The Wiki folder should be unique
  # 6. We cannot wikify a BaselineProcess
  # 7. We can Wikify a Wiki
  test "New wiki" do 
    @emails = ActionMailer::Base::deliveries
    @emails.clear
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @oup_20060721 = create_oup_20060721
    # 1.
    sites_count, update_count = Site.count, Update.count
    wiki = Wiki.new#(:folder => 'openup', :title => 'OpenUP Wiki', :user_id => @george.id) 
    assert !wiki.save
    assert_equal "Folder can't be blank, Title can't be blank, User can't be blank", wiki.errors.full_messages.sort.join(', ')
    assert_equal [sites_count, update_count], [Site.count, Update.count]
    # 2.
    wiki = Wiki.new(:folder => 'openup', :title => 'OpenUP Wiki', :user_id => @george.id)
    FileUtils.remove_dir(wiki.path) if File.exists?(wiki.path)
    assert wiki.save
    assert_equal "", wiki.errors.full_messages.join(', ')
    wiki.reload
    assert_equal sites_count+1, Site.count
    # 3
    update = Update.new(:baseline_process_id => wiki.id, :wiki_id => @oup_20060721.id, :user_id => @george.id)
    assert !update.save
    assert_equal "Baseline process is not a BaselineProcess, Wiki is not a Wiki", update.errors.full_messages.join(', ')
    assert_equal 'Pending', wiki.status
    # 4
    update = Update.new(:baseline_process_id => @oup_20060721.id, :wiki_id => wiki.id, :user_id => @george.id)
    assert update.save
    assert_equal 'Scheduled', wiki.status
    assert_equal 4, @emails.size # TODO changed from 1 to 3
    r = ["[EPF Wiki - Test Enviroment] SCHEDULED creation new Wiki Templates using Baseline Process templates_20080828",
 "[EPF Wiki - Test Enviroment] STARTED creating New Wiki Templates using Baseline Process templates_20080828",
 "[EPF Wiki - Test Enviroment] FINISHED creating new Wiki Templates using Baseline Process templates_20080828",
 "[EPF Wiki - Test Enviroment] SCHEDULED creation new Wiki OpenUP Wiki using Baseline Process oup_20060721"]
    assert_equal r, @emails.collect{|e|e.subject}
    #assert_equal @emails[0].subject.include? "SCHEDULED creation new Wiki #{update.wiki.title} using Baseline Process #{update.baseline_process.title}"
    @emails.clear
    # 5.
    wiki = Wiki.new(:folder => 'openup', :title => 'OpenUP Wiki', :user_id => @george.id)
    assert !wiki.save    
    assert_equal 'Folder already exists', wiki.errors.full_messages.join(', ')    
    # 6
    assert_raise(NoMethodError) {@oup_20060721.wikify} 
    # 7
    assert_equal 1, Update.find_todo.size
    update = Update.find_todo[0]
    w, bp = update.wiki, update.baseline_process
    bp.reload
    Rails.logger.info("bp: #{bp.inspect}, pages #{bp.pages.size}")
    assert_equal 617, bp.pages.size
    assert !bp.content_scanned_on.nil?
    update.baseline_process.scan4content # TODO fails after upgrade
    assert_equal ['Scheduled', 0], [w.status, w.pages.size]
    cnt1 = Page.count
    Rails.logger.info("site_test.rb: doing update that just update but then doesn't")
    update.do_update
    Rails.logger.info("site_test.rb: after update that doensn't do much")
    cnt2 = Page.count
    assert_equal 0, Update.find_todo.size
    bp.reload
    w.reload
    assert_equal 617, bp.pages.count
    Rails.logger.info("site_test.rb: testing number of pages")
    assert_equal ['Ready', 617, 669, 669+617], [w.status, w.pages.size, cnt1, cnt2]
    assert_equal w.pages.size + bp.pages.size + 2*26, Page.count
    assert_equal 2, @emails.size
    assert_equal "[EPF Wiki - Test Enviroment] STARTED creating New Wiki #{update.wiki.title} using Baseline Process #{update.baseline_process.title}", @emails[0].subject
    assert_equal "[EPF Wiki - Test Enviroment] FINISHED creating new Wiki #{update.wiki.title} using Baseline Process #{update.baseline_process.title}", @emails[1].subject
    assert_equal [update.user.email], @emails[0].to
    assert_equal [User.find_central_admin.email], @emails[0].cc
  end
  
  # Shows:
  # 1. We cannot Wikify a BaselineProcess TODO?
  # 2. We can update content in a Wiki site    
  # 3. The Wikify operation will cause content of baseline process to be scanned (because it was not scanned yet)
  # 4. 
  test "New wiki 2" do
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @oup_20060721 = create_oup_20060721
    @oup_20060728 = create_oup_20060728
    @oup_wiki = create_oup_wiki(@oup_20060721)
    @oup_wiki.reload # TODO is necessary or not?
    assert_equal @oup_20060721, @oup_wiki.baseline_process 
    # 1
    #assert_raise(RuntimeError) {@oup_20060721.wikify} 
    # 2
    #@oup_wiki.baseline_process = @oup_20060728
    assert_equal 'Ready', @oup_wiki.status
    cnt = Update.count
    update = Update.create(:baseline_process_id => @oup_20060728.id, :wiki_id => @oup_wiki.id, :user_id => @george.id )
    assert_equal cnt+1, Update.count
    #assert @oup_wiki.save
    @oup_wiki.reload # NOTE: @oup_wiki.updates is cached so status will wrong without reload
    assert_equal 'Scheduled', @oup_wiki.status
    updates = Update.find_todo
    assert_equal 1, updates.size
    assert_equal @oup_wiki, updates[0].wiki
    update.do_update
    update.reload
    assert_equal 'Ready', update.wiki.status  
    @oup_wiki.reload
    assert_equal [], Update.find_todo
    assert_equal 2, Wiki.find(:all).size 
    @oup_20060721.reload 
    assert_not_nil @oup_20060721 
    assert_equal 'oup_20060721',@oup_20060721.title 
    #assert_equal @oup_wiki.baseline, @oup_20060728.baseline
    assert_equal 617, @oup_wiki.pages.size 
    # 3
    assert_equal @oup_wiki.pages.size, @oup_20060728.pages.size  
    # 4
    assert_equal [1234, {"New" => 26, "Updated" => 617}, {"N.A." => 1260}],[@oup_wiki.versions.size, WikiPage.count(:group => 'status'), BaselineProcessPage.count(:group => 'status')]
    status = WikiPage.count(:group => 'status')
    assert_equal [26,617], [status['New'], status['Updated']], "Different status: #{status.inspect}"
   r = {"Activity" =>  140,
 "Artifact" =>  23+1,
 "CapabilityPattern" =>  35,
 "Checklist" =>  10+1,
 "Concept" =>  48+1,
 "CustomCategory" =>  4+1,
 "Deliverable" => 1,
 "DeliveryProcess" =>  5,
 "Discipline" =>  6+1,
 "DisciplineGrouping" =>  1,
 "Domain" =>  6+1,
 "EstimationConsiderations"=>1,
 "Example"=>1,
 "Guideline" =>  45+2,
 "Milestone" =>  4,
 "Outcome" =>  1,
 "Practice" =>  1,
 "Report"=>1,
 "ReusableAsset"=>1,
 "Roadmap" =>  1+1,
 "Role" =>  7+1,
 "RoleDescriptor" =>  33,
 "RoleSet" =>  1+1,
 "RoleSetGrouping"=>1,
 "Summary" =>  114,
 "SupportingMaterial" =>  4+1,
 "Task" =>  23+1,
 "TaskDescriptor" =>  25,
 "Template" =>  8+1,
 "TermDefinition" =>  7+1,
 "ToolMentor"=>1,
 "Whitepaper"=>1,
 "WorkProductDescriptor" =>  59,
 "WorkProductType" =>  8+1}
    uma_types_count = WikiPage.count(:group => 'uma_type')
    UmaType.find(:all).each do |uma_type|
      assert_equal [uma_type.name,uma_types_count[uma_type]], [uma_type.name, r[uma_type.name]]          
    end
  end
 
  # Shows:
  # 2. Can't update a BaselineProcess (site_type != 'W')
  # 3. Can update a wiki with a current or previous BaselineProcess
  # 4. Can update or cancel a pending wiki 
  # 5. We can do the actual update
  # 6. Update with Templates baseline  
  # 7. We can also update with a previous baseline process
  test "Update Wiki" do 
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @oup_20060721 = create_oup_20060721
    @oup_20060728 = create_oup_20060728
    @oup_20060825 = create_oup_20060825
    @oup_wiki = create_oup_wiki(@oup_20060721)
    # 2
    update = Update.new(:baseline_process_id => @oup_20060728.id, :wiki_id => @oup_20060721.id, :user_id => @george.id)
    assert !update.save
    assert_equal 'Wiki is not a Wiki', update.errors.full_messages.join(', ')  
    @oup_wiki.reload
    assert_equal 'Ready', @oup_wiki.status        
    # 3
    @oup_20060721.reload
    #@oup_wiki = create_oup_wiki(@oup_20060721)
    update = Update.new(:baseline_process_id => @oup_20060721.id, :wiki_id => @oup_wiki.id, :user_id => @george.id)
    assert update.save
    @oup_wiki.reload
    assert_equal 'Scheduled', @oup_wiki.status    
    # 4
    update.baseline_process = @oup_20060825
    assert update.save
    @oup_wiki.reload
    assert_equal 'Scheduled', @oup_wiki.status
    assert_equal @oup_20060721, @oup_wiki.baseline_process
    assert_equal 'Scheduled', @oup_wiki.status
    update.destroy
    #assert @oup_wiki.save
    @oup_wiki.reload
    assert_equal 'Ready', @oup_wiki.status
    # 5
    update = Update.new(:baseline_process_id => @oup_20060728.id, :wiki_id => @oup_wiki.id, :user_id => @george.id)
    assert update.save
    @oup_wiki.reload
    assert_equal 'Scheduled', @oup_wiki.status
    assert_equal 617, @oup_20060728.pages.size 
    update.do_update
    @oup_wiki.reload
    @oup_20060728.reload
    assert_equal @oup_wiki.baseline_process,@oup_20060728
    assert_equal 617, @oup_wiki.pages.size 
    @oup_20060728.reload
    assert_equal 617, @oup_20060728.pages.size # content scan triggered by update
    status = WikiPage.count(:group => 'status')
    assert_equal 26, status['New']
    assert_equal 617, status['Updated']
    # 6
    #tpb_bl = create_templates_baseline # TODO obsolete after upgrade
    @templates = Wiki.find_by_title('Templates') # TODO added for upgrade
    tpb_bl = @templates.baseline_process # TODO added for upgrade
    assert_equal 'Ready', @oup_wiki.status
    update = Update.new(:baseline_process_id => tpb_bl.id, :wiki_id => @oup_wiki.id, :user_id => @george.id)
    assert update.save
    @oup_wiki.reload
    assert_equal 'Scheduled', @oup_wiki.status
    status = WikiPage.count(:group => 'status')
    r = {"New"=>26, "Updated"=>617}
    assert_equal r, status
    update.do_update
    @oup_wiki.reload
    assert_equal 'Ready', @oup_wiki.status
    assert_equal tpb_bl, @oup_wiki.baseline_process
    r = {"New"=>26, "RemovedOrMoved"=>617}
    assert_equal r, WikiPage.count(:group => 'status', :conditions => ['site_id=?',@oup_wiki.id])
    # 7
    update = Update.new(:baseline_process_id => @oup_20060728.id, :wiki_id => @oup_wiki.id, :user_id => @george.id)
    assert update.save
    @oup_wiki.reload
    assert_equal 'Scheduled', @oup_wiki.status
    update.do_update
    @oup_wiki.reload
    assert_equal 'Ready', @oup_wiki.status
    assert_equal @oup_wiki.baseline_process, @oup_20060728
    r = {"RemovedOrMoved"=>26, "Updated"=>617}
    assert_equal r, WikiPage.count(:group => 'status', :conditions => ['site_id=?',@oup_wiki.id])    
  end

  test "Wikifiable files" do
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @oup_20060721 = create_oup_20060721
    wikifiable_files = @oup_20060721.files_wikifiable
    assert_equal 617, wikifiable_files.size 
    assert_equal 617, wikifiable_files.size
  end
  
end
