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

class PagesControllerTest < ActionController::TestCase

  def setup
    teardown
    @controller = PagesController.new
    @emails = ActionMailer::Base::deliveries
    @emails.clear
  end
  
  def teardown
    [ENV['EPFWIKI_SITES_PATH'], ENV['EPFWIKI_WIKIS_PATH']].each do |p|
      FileUtils.rm_r(p) if File.exists?(p)
      FileUtils.makedirs(p)
    end
  end
  
  # Shows:
  # 1. 'View' does not require logon 
  # 2. 'View' of a Page with Comment records, displays these records
  # 3. Contributors are displayed on the page
  # 4. If the page is checked out, this is displayed in the page
  test "View" do 
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @wiki = Wiki.find(:first) 
    assert_equal 'Templates', @wiki.title
    # 1
    @wiki.pages.each do |page|
      id = (@wiki.rel_path + page.rel_path).gsub('/', '_') # id allows us to cache the requests (pages)
      @request.env["CUSTOM_HEADER"] = "bar"
      get :view, :id => id , :url => URI.escape(page.url), :format => 'js'
      assert_response :success
      assert_equal @wiki, assigns(:wiki)
      assert_equal page, assigns(:page)
      assert_not_nil assigns(:version)
      assert_equal [], assigns(:comments)
      assert_nil assigns(:checkout)
      assert_equal [], assigns(:contributor_names)
    end
    # 2
    page = @wiki.pages[3]
    cs = [Comment.new(:text => 'Comment', :user => @andy, :page => page, :site => @wiki, :version => page.current_version),
    Comment.new(:text => 'Another comment', :user => @andy, :page => page, :site => @wiki, :version => page.current_version),
    Comment.new(:text => 'And another comment', :user => @andy, :page => page, :site => @wiki, :version => page.current_version)]
    cs.each do |c|
      assert c.save, "Failed to save commment #{c.errors.full_messages.join(', ')}"
    end
    page.reload
    assert_equal 3, page.comments.size 
    get :view, :url => page.url, :format => 'js'
    assert_response :success
    assert_match "Comment", @response.body
    assert_match "Another comment", @response.body
    assert_match "And another comment", @response.body
    # 3
    assert_equal [@andy.name], assigns(:contributor_names)
    assert_match @andy.name, @response.body
    # 4
    co = Checkout.new(:user => @andy, :page => page, :site => @wiki)
    assert co.save
    get :view, :url => page.url, :format => 'js'
    assert_response :success
    assert_match 'This page is currently being created or modified by ' + @andy.name, @response.body
  end

  # Shows:
  # 1. Access 'discussion' space for a page requires logon
  # 2. Comment submitted by specifying page and Wiki
  # 3. Users are immediately notified about the new comment
  # 4. user cannot mark 'todo', 'done'
  # 5. admin can, admin is recorded as the user that marked 'done'
  # 6. cadmin can, cadmin is recorded as the user that marked 'todo'
  test "Discussion" do
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    @tony = Factory(:user, :name => 'Tony Clifton', :password => 'secret', :admin => 'N')
    @wiki = Wiki.find(:first) 
    @emails.clear
    # 1
    page = WikiPage.find_by_presentation_name('Toolmentor Template')
    get :discussion, :site_folder => @wiki.folder, :id => page.id
    assert_redirected_to :controller => 'login'
    session['user'] = @tony.id
    get :discussion, :site_folder => @wiki.folder, :id => page.id
    assert_response :success
    assert_not_nil assigns(:wiki)
    assert_not_nil assigns(:page)
    assert_not_nil assigns(:comment)
    assert_not_nil assigns(:comments)
    assert_equal 1, page.versions.size
    assert_equal 0, assigns(:comments).size
    # preparation for 3
    [@andy, @george].each {|u|u.update_attributes(:notify_immediate => 1)}
    assert_equal 0, @emails.size
    # 2
    post :discussion, :comment => {:text => 'comment 1 submitted in test01_new', :page_id => page.id}
    assert_redirected_to :controller => 'pages', :site_folder => @wiki.folder, :id => page.id, :action => 'discussion'
    assert_not_nil assigns(:wiki)
    assert_not_nil assigns(:page)
    assert_not_nil assigns(:comment)
    assert_not_nil assigns(:comment).version
    assert_equal page.current_version, assigns(:comment).version
    assert_not_nil assigns(:comments)
    assert_no_errors
    assert_no_errors(assigns(:comment))
    assert_equal 1, assigns(:comments).size
    get :discussion, :site_folder => @wiki.folder, :id => page.id
    assert_response :success    
    # 3
    assert_equal 1, @emails.size
    assert_equal "[EPF Wiki - Test Enviroment] New comment about #{page.presentation_name}", @emails[0].subject
    assert_equal [@andy.email, @george.email, @tony.email].sort, @emails[0].bcc.sort # tony because he created the comment, george and andy because they want to be notified immediately
  end
  
  # Shows:
  # 1. 'Edit' requires logon, after logon redirects to 'Checkout'
  # 2. Get 'Checkout' will display the checkout dialog 
  # 3. We can create a checkout
  # 4. We cannot checkout again, if a checkout exists the HTML editor will open but a warning is displayed
  # 7. Can open page with TinyMCE if TinyMCE is installed in public/javascripts/tiny_mce
  # 8. All users can start the HTML editor but only the owner or cadmin can commit changes
  # 9. Other user can't save HTML
  # 10. Owner can save HTML
  # 11. Cadmin can save HTML of other user  
  # 12. Other user cannot checkin 
  # 13. Can checkin without submit of HTML 
  # 14. Checkout of version 1 of page
  # 15. Can checkin with submit of HTML
  # 16. Authentication to request form
  # 17. user request for form to create page based on a template
  # 18. form has field 'presentation_name', textarea 'note' and radio button for selecting a version, last version of first template is default
  # 19. new page '' based on 'Tool Mentor Template.html' creates a checkout
  # 20. page does not exist untill checkin
  # 21. undo checkout deletes new page 
  # 22. we can edit, preview, save and checkin a new page created based on a template
   test "Checkout edithtml save checking new" do 
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    @tony = Factory(:user, :name => 'Tony Clifton', :password => 'secret', :admin => 'N')
    @wiki = Wiki.find(:first) 
    @bp = @wiki.baseline_process
    page = WikiPage.find_by_presentation_name('Toolmentor Template')
    assert_not_nil page
    assert !page.versions.empty?
    # 1
    get :edit, :id => page.id, :site_folder => @wiki.folder
    assert_redirected_to :controller => 'login'
    session['user'] = @tony.id
    get :edit, :id => page.id, :site_folder => @wiki.folder
    assert_redirected_to :action => 'checkout', :id => page.id, :site_folder => @wiki.folder
    # 2 
    get :checkout, :id => page.id, :site_folder => @wiki.folder
    assert_response :success
    assert_not_nil assigns(:page)
    assert_not_nil assigns(:wiki)      
    assert_not_nil assigns(:version)   
    assert_equal page.current_version, assigns(:version).source_version # source version is default current_version
    assert_not_nil @bp
    # 3
    Rails.logger.info('We can create a checkout')
    assert_not_nil assigns(:page).current_version # TODO faalt indien we dit niet opnemen
    post :checkout, :id => page.id, :user_version => {:version_id => assigns(:version).source_version.id, :note => 'test01_checkout'}
    assert_not_nil page.checkout
    assert_redirected_to  :action => 'edit', :checkout_id => page.checkout.id 
    # 4
    session['user'] = @andy.id
    get :checkout, :id => page.id, :site_folder => @wiki.folder # get checkout will redirect
    assert_redirected_to  :action => 'edit', :checkout_id => page.checkout.id
    get :edit, :checkout_id => page.checkout.id # will just open the page in the HTML editor
    assert_response :success
    assert_match 'The page is currently checked out by user',@response.body
    # 7
    checkout = Checkout.find(:first)
    session['user'] = checkout.user.id
    get :edit, :checkout_id => checkout.id
    assert_response :success
    # 8
    session['user'] = @andy.id
    get :edit, :checkout_id => checkout.id
    assert_response :success
    assert_match "The page is currently checked out by user #{@tony.name}", @response.body
    assert_match "You can modify the HTML but you cannot commit any changes", @response.body
    session['user'] = @george.id
    get :edit, :checkout_id => checkout.id
    assert_response :success
    assert_not_nil assigns(:checkout)
    assert_match "The page is currently checked out by user #{@tony.name}", @response.body
    assert_match "As you are the central administrator you can perform operations on this checkout", @response.body
    # 9
    @emails.clear
    page.reload
    assert_not_nil page.checkout
    co = page.checkout
    assert_equal co.version.source_version.page, co.page # ordinary checkout, not a new page
    html = co.version.html.gsub('</body>','adding some text</body>')
    session['user'] = @andy.id
    post :save, :html => html, :checkout_id => co.id
    #assert_raise(RuntimeError) {post :save, :html => html, :checkout_id => co.id}
      #"Only Tony or the administator (#{User.find_central_admin.name}) should be able to save the HTML"
    assert_equal 1, @emails.size
    assert @emails[0].subject.include?('[Error] exception in')
    assert @emails[0].body.include?(LoginController::FLASH_UNOT_CADMIN)
    assert_redirected_to :controller => 'other', :action => 'error'
    assert_not_nil flash['error'] 
    assert flash['error'].include?(LoginController::FLASH_UNOT_CADMIN)
    assert flash['notice'].include?('notified about this issue')
    # 10
    session['user'] = checkout.user.id
    post :save, :html => html, :checkout_id => co.id
    assert_redirected_to :action => 'edit', :checkout_id => co.id
    assert_match 'adding some text', checkout.version.html 
    # 11
    session['user'] = @george.id
    post :save,  :checkout_id => co.id, :html => co.version.html.gsub('adding some text', 'adding some text, adding some more by by cadmin')
    assert_redirected_to :action => 'edit', :checkout_id => co.id    
    assert_equal nil, co.version.version
    assert_match 'adding some text, adding some more by by cadmin', co.version.html
    # 12     
    Rails.logger.debug 'test05_checkin'
    assert_equal 1, Checkout.count
    #page = WikiPage.find_by_presentation_name('Role Template')
    assert_not_nil page.checkout
    co = page.checkout
    session['user'] = @andy.id
    assert @andy != checkout.user
    @emails.clear
    post :checkin, :checkout_id => checkout.id
    assert_equal 1, @emails.size
    assert @emails[0].subject.include?('[Error] exception in')
    assert_redirected_to :controller => 'other', :action => 'error' 
    #assert_raise(RuntimeError) {post :checkin, :checkout_id => checkout.id}
    # 13
    session['user'] = checkout.user.id
    post :checkin, :checkout_id => checkout.id
    assert_raise(ActiveRecord::RecordNotFound) {Checkout.find(checkout.id)}
    assert_match 'adding some text, adding some more by by cadmin', page.html
    assert_enhanced_file(page.path)
    assert_version_file(page.current_version.path)  
    # 14
    page.reload
    assert_equal 1, page.versions[1].version
    post :checkout, :id => page.id, :user_version => {:version_id => page.versions[1].id, :note => 'Checkout of version 1'}   
    assert_not_nil page.checkout
    assert_redirected_to :action => 'edit', :checkout_id => page.checkout.id
    co = page.checkout
    v = co.version
    # 15
    post :checkin, :checkout_id => co.id, :html => checkout.version.html.gsub('</body>', 'Checkin with submit of html</body>')
    assert_raise(ActiveRecord::RecordNotFound) {Checkout.find(co.id)}    
    assert_match 'Checkin with submit of html', page.html    
    assert_enhanced_file(page.path)
    v.reload
    assert_version_file(v.path)
    # 16
    #create_templates
    session['user'] = @tony.id
    get :new, :site_folder => @wiki.folder, :id => @wiki.pages[10]
    assert_not_nil assigns(:wiki)
    assert_not_nil assigns(:page)    
    assert_not_nil assigns(:new_page).source_version
    assert_not_nil assigns(:templates)    
    assert_equal 26, assigns(:templates).size # was 27
    assert_equal assigns(:templates)[0].id, assigns(:new_page).source_version
    #assert_tag :tag => 'input', :attributes => {:type => 'radio',  :name => 'new_page[source_version]', :value => assigns(:page).source_version, :checked => 'checked'}
    # 17
    #assert_field('page_presentation_name') TODO update
    #assert_tag :tag => 'textarea', :attributes => {:id => 'new_page_note', :name => 'new_page[note]'}
    #assigns(:templates).each do |version|
    #  assert_tag :tag => 'input', :attributes => {:type => 'radio', :id => "new_page_source_version_#{version.id.to_s}", :name => 'new_page[source_version]', :value => version.id}
    #end
    # 18
    template = WikiPage.find_by_presentation_name('Toolmentor Template')
    assert_not_nil template
    post :new, :id => template.id, :site_folder => template.site.folder, :page => {:presentation_name => 'A strange name&2//++-09976', :source_version => template.current_version.id, :note => 'test03_new_page_using_template'}
    assert_not_nil assigns(:checkout)
    co = assigns(:checkout)
    new_page = co.page
    assert_not_nil new_page.user
    assert_redirected_to :action => 'edit', :checkout_id => co.id
    assert_equal template.current_version, co.version.source_version
    assert_version_file(co.version.path)
    assert_equal 'a_strange_name209976.html', new_page.filename
    assert co.version.source_version.html.index('Tool Mentor: Toolmentor Template')
    # 19
    assert File.exists?(new_page.path) # 
    assert File.exists?(co.version.path)
    # 20
    # 21
    # 22
    page = WikiPage.find_by_presentation_name('A strange name&2//++-09976')
    assert_not_nil page.checkout
    co = page.checkout
    v = co.version
    session['user'] = co.user.id
    get :edit, :checkout_id => co.id # we can edit
    assert_equal nil, flash['error']
    assert_equal nil, flash['notice']
    post :preview, :html => co.version.html.gsub('accomplish a piece of work', 'accomplish a piece of work####'), :checkout_id => co.id
    assert_redirected_to '/' + co.version.rel_path_root
    assert_match 'work####', co.version.html
    post :save, :html => co.version.html.gsub('work####', '####work####'), :checkout_id => co.id    
    assert_match '####work####', co.version.html    
    post :checkin, :checkout_id => co.id
    assert_raise(ActiveRecord::RecordNotFound) {Checkout.find(co.id)}
    assert_match '####work####', page.html
    assert_enhanced_file(page.path)
    v.reload
    assert_version_file(v.path)
  end 
  
  # Shows:
  # 1. Owner can undo checkout
  # 2. Other user can't undo
  # 3. Cadmin can undo any checkout
  # 4. Undo of new page deletes the checkout, version, page and redirects to first page of the wiki
  test "Undo checkout" do 
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    @tony = Factory(:user, :name => 'Tony Clifton', :password => 'secret', :admin => 'N')
    @wiki = Wiki.find(:first)
    assert_equal 'Templates', @wiki.title 
    #get :checkout # TODO remove rails 3 - was workaround
    session['user'] = @tony.id
    page = WikiPage.find_by_presentation_name('Toolmentor Template')
    assert_nil page.checkout
    # 1
    v = page.current_version
    assert_not_nil v
    post :checkout, :id => page.id, :user_version => {:version_id => v.id, :note => 'test_undocheckout'}    
    assert_not_nil page.checkout
    assert_redirected_to :action => 'edit', :checkout_id => page.checkout.id
    co = page.checkout
    v = page.checkout.version
    get :undocheckout, :checkout_id => co.id
    assert !Checkout.exists?(co.id)
    assert !Version.exists?(v.id)
    # 2
    post :checkout, :id => page.id ,:user_version => {:version_id => page.current_version.id, :note => 'test_undocheckout'}    
    co = page.checkout
    v = page.checkout.version    
    session['user'] = @andy.id
    @emails.clear
    get :undocheckout, :checkout_id => co.id
    assert_redirected_to :controller => 'other', :action => 'error'
    assert_equal 1, @emails.size
    assert @emails[0].subject.include?('[Error] exception in')
    #assert_raise(RuntimeError) {get :undocheckout, :checkout_id => co.id}
    # 3
    session['user'] = @george.id

    get :undocheckout, :checkout_id => co.id
    assert_redirected_to ENV['EPFWIKI_BASE_URL'] + '/' + @wiki.rel_path + '/' + page.rel_path
    assert_nil page.checkout
    assert !Checkout.exists?(co.id)
    assert !Version.exists?(v.id)
    # 4 
    session['user'] = @tony.id
    page.reload
    assert_not_nil page
    assert_not_nil page.site
    assert page.site.pages.size > 0
    post :new, :id => page.site.pages[0].id, :site_folder =>page.site.folder, :page => {:presentation_name => "New page based on #{page.presentation_name}", :source_version => page.versions.last.id, :note => 'Undo also deletes page'}
    new_page = WikiPage.find_by_presentation_name("New page based on #{page.presentation_name}")
    assert_not_nil new_page
    assert_not_nil new_page.checkout
    assert_not_nil new_page.checkout.version
    co, v = new_page.checkout, new_page.checkout.version
    post :undocheckout, :checkout_id => new_page.checkout.id
    assert !Page.exists?(new_page.id)
    assert !Checkout.exists?(co.id)
    assert !Version.exists?(v.id)
    assert_redirected_to page.site.pages[0].url
  end
  
  # Shows:
  # 1. Creating a new version with some added text ####
  # 2. checkout, checkin van base version is rollback of CHANGE 1
  # 4. Cannot rollback checked out version
  test "Rollback" do 
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    @tony = Factory(:user, :name => 'Tony Clifton', :password => 'secret', :admin => 'N')
    get :new
    session['user'] = @tony.id
    page = WikiPage.find_by_presentation_name('Toolmentor Template')
    assert_equal 1, page.versions.size
    # 1
# pages/checkout/488
# version_note
# version_version_id

    post :checkout, :id => page.id, :user_version => {:version_id => page.current_version.id, :note => 'test_rollback'}    
    assert_not_nil page.checkout
    co = page.checkout
    post :checkin, :checkout_id => co.id, :html => co.version.html.gsub('</body>', '####</body>')
    page.reload
    assert_nil page.checkout
    assert_match '####', page.html
    # 2
    post :rollback, :version => {:version_id => page.versions[0].id}    
    page.reload
    assert_nil page.checkout
    assert_equal 2, page.versions.last.version
    assert !page.versions.last.html.index('#### 1')
    assert !page.html.index('####')
  end
  
  test "TinyMCE installed" do
    #assert File.exists?("#{ENV['EPFWIKI_ROOT_DIR']}public/javascripts/tiny_mce/tiny_mce.js"), "TinyMCE is not installed yet!" 
  end

  test "New" do
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    p = WikiPage.find_by_presentation_name('Supporting Material Template')
    assert_equal 1, p.versions.size, 'Page should have one version'
    assert_equal 0, p.versions[0].version, 'Version number is 0'
    assert_not_nil p, 'Template was not found'
    v =  p.versions[0]
    w = p.site
    assert_not_nil w, 'Page should belong to a site'
    Rails.logger.info('We need to login to create a new page')
    get :new, :id => p.id, :site_folder => w.folder
    assert_redirected_to :controller => 'login'
    session['user'] = @cash.id
    Rails.logger.info("---- test new #{p.id}, #{w.folder}")
    get :new, :id => p.id, :site_folder => w.folder
    #assert_response :success
   # assert_redirected_to :action => 'edit', :checkout_id => assigns(:checkout).id
    assert_equal [w.id, p.id, v.id], 
      [assigns(:wiki).id, assigns(:page).id, assigns(:new_page).source_version]
    assert_not_nil assigns(:templates)
    Rails.logger.info('We can create a new page')
    assert_equal 'BaselineProcessVersion', assigns(:templates)[0].class.name
    p = WikiPage.find_by_presentation_name('Role Set Grouping Template')
    template = p.current_version 
    assert assigns(:templates).include? template
    raise "No Templates Wiki was found. There should always be a Wiki with title 'Templates' to provide templates for creating new pages" if !w
    assert_equal 'Role Set Grouping Template', template.page.presentation_name # TODO <"Role Set Grouping Template"> expected but was<"Checklist Template"> 
    post :new, :site_folder => w.folder, :id => p.id, 
      :page => {:presentation_name => 'New page', :source_version => template.id}
    assert assigns(:page)
    assert assigns(:wiki)
    assert assigns(:new_page)
    assert assigns(:checkout)  
    assert_redirected_to  :action => 'edit', :checkout_id => assigns(:checkout).id
    p,w,np,co = assigns(:page), assigns(:wiki), assigns(:new_page), assigns(:checkout)
    [p,w,np,co].each {|o|o.reload}
    assert_equal 'Role Set Grouping Template', co.version.source_version.page.presentation_name
    assert_equal template.page.current_version, co.version.source_version
    page_count = Page.count
    post :undocheckout, :checkout_id => co.id
    assert_equal page_count - 1, Page.count, "Page count was #{page_count} and should be minus 1 equal to #{Page.count} after undo checkout"
    Rails.logger.info('Presentation name is a mandatory field')
    post :new, :site_folder => w.folder, :id => p.id, 
    :page => {:source_version => template.id}
    assert_response :success
    assert assigns(:page)
    assert assigns(:wiki)
    assert assigns(:new_page)
    #assert assigns(:checkout) # Fails indien nil?
    #assert_nil assigns(:checkout)
    assert_equal 'Presentation name can\'t be blank', assigns(:new_page).errors.full_messages.join(', ')
    Rails.logger.info('Source version is a mandatory field')
    post :new, :site_folder => w.folder, :id => p.id, 
      :page => {:presentation_name => 'New page'}
    assert_response :success
    assert_equal 'Source version can\'t be blank', assigns(:new_page).errors.full_messages.join(', ')     
  end
  
 end
