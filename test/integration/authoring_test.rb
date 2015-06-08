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

class AuthoringTest < ActionDispatch::IntegrationTest

  def setup
    #logger.debug "Test Case: #{name}"
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
  end
  
  def teardown
    [ENV['EPFWIKI_SITES_PATH'], ENV['EPFWIKI_WIKIS_PATH']].each do |p|
      FileUtils.rm_r(p) if File.exists?(p)
      FileUtils.makedirs(p)
    end
  end

  def test_view_discussion_edit_new_history
    
    Rails.logger.info("Andy creates a version without changing anything")
    post 'login/login', :user => {:email => @andy.email, :password => 'secret'}
    @page1 = WikiPage.find_by_presentation_name('Toolmentor Template')
    assert_page_success @page1, @andy
    post 'pages/checkout', :user_version => {:version_id => @page1.current_version.id, :note => 'Changing toolmentor template'}
    assert_not_nil @page1.checkout
    assert_redirected_to :action => 'edit', :checkout_id => @page1.checkout.id
    post 'pages/checkin', :checkout_id => @page1.checkout.id # TODO change

    Rails.logger.info("George makes a change")
    post 'login/login', :user => {:email => @george.email, :password => 'secret'}
    assert_page_success @page1    
    
    post 'pages/checkout', :user_version => {:version_id => @page1.current_version.id, :note => 'Change of george'}
    @page1.reload
    assert_not_nil @page1.checkout
    assert_equal 'Change of george', @page1.checkout.version.note
    assert_redirected_to :action => 'edit', :checkout_id => @page1.checkout.id
    get "pages/edit?checkout_id=#{@page1.checkout.id}"
    assert_response :success
    assert_page_success @page1
    
    v = @page1.checkout.version
    assert_not_nil v
    post 'pages/checkin', :checkout_id => @page1.checkout.id, :html => v.html.gsub("accomplish a piece of work", "REPLACED")
    get @page1.url # e.g. /development_wikis/mywiki/new/guidances/toolmentors/toolmentor_template_E9930C53.html
    assert_match 'REPLACED', @response.body
    assert_page_success @page1
    
    put 'pages/checkin', :version => {:id => v.id, :note => 'Change of George updated'} # TODO post or put, improve

    # TODO enable. Disabled as result of bug in Rails, assert will fail because of port number
    # Expected response to be a redirect to <http://localhost/test_wikis/templates/new/guidances/toolmentors/toolmentor_template_E9930C53.html> 
    # but was a redirect to <http://localhost:3000/test_wikis/templates/new/guidances/toolmentors/toolmentor_template_E9930C53.html>
    # assert_redirected_to '/' + v.wiki.rel_path + '/' + v.page.rel_path
    
    v.reload
    assert_equal 'Change of George updated', v.note 
    assert_page_success @page1
 
  end
  
  def test_review_changes
    
    @oup_20060721 = create_oup_20060721
    @oup_wiki = create_oup_wiki(@oup_20060721)
    
    Rails.logger.info("Cash creates a version")
    post 'login/login', :user => {:email => @cash.email, :password => 'secret'}
    @page1 = WikiPage.find_by_presentation_name('Analyst')
    assert_page_success @page1, @cash
    post 'pages/checkout', :user_version => {:version_id => @page1.current_version.id, :note => 'Changing the Analyst'}
    assert_not_nil @page1.checkout
    v = @page1.checkout.version
    assert_redirected_to :action => 'edit', :checkout_id => @page1.checkout.id
    post 'pages/checkin', :checkout_id => @page1.checkout.id, :html => v.html.gsub("leads and coordinates requirements elicitation", "REPLACED")
    assert_page_success @page1
    
    Rails.logger.info("Andy review")
    post 'login/login', :user => {:email => @andy.email, :password => 'secret'}
    get "/sites/versions/#{@page1.site.id}"
    assert_response :success
    assert_match 'Changing the Analyst', @response.body
    assert_match '<div class="edit-area" id="/versions/note/' + v.id.to_s + '/UserVersion">Changing the Analyst</div>', @response.body
    post "/versions/note/#{v.id}/UserVersion", :format => 'js', :value => 'Changing the Analyst 2'
    assert_response :success
    get "/sites/versions/#{@page1.site.id}"
    assert_match 'Changing the Analyst 2', @response.body
    
    #http://localhost:3000/development_wikis/mywiki/new/guidances/supportingmaterials/supporting_material_template_D3F13112.html_EPFWIKI_DIFF_V0_V1.html
    diff_url =  "#{@page1.url}.html_EPFWIKI_DIFF_V0_V1.html"
    get diff_url
    assert_response :missing, 'Diff file should not exist'
    get "/versions/diff?id=#{v.id}"
    assert_response :success
    path = "#{@page1.path}_EPFWIKI_DIFF_V0_V1.html"
    assert File.exists? path
    get diff_url
    diff_html = File.read(path)
    assert diff_html.include? "<del>"
    assert diff_html.include? "<ins>"
    assert diff_html.include? "This role leads and coordinates"
    assert diff_html.include? "This role REPLACED; outlines and delim"
    v = @page1.current_version
    v.html = File.read(File.join(Rails.root, 'test', 'integration', 'authoring_test.html')) # this is a file authored by TinyMCE
    File.delete(path)
    get "/versions/diff?id=#{v.id}"
    assert_response :success
    path = "#{@page1.path}_EPFWIKI_DIFF_V0_V1.html"
    assert File.exists? path
    get diff_url
    diff_html = File.read(path)
    #assert diff_html.include? "<del>This role leads and coordinates requirements elicitation; outlines and delimits the system's functionality; specifies and maintains the detailed system requirements.</del><ins>This role REPLACED; outlines and delimits the system's functionality; specifies and maintains the detailed system requirements.</ins></td>"

  end
  
  def test_feedback 
  
    w = Wiki.find(:first)
    
    get '/'
    assert_response :success
    get '/portal/feedback'
    assert_response :success
    post '/portal/feedback', :feedback =>{"email"=>"onno.van.der.straaten@gmail.com", "text"=>"Some feedback"}
    assert flash['success'].include?("succesfully sent")
    assert_redirected_to '/'
    post '/portal/feedback', :feedback =>{"email"=>"onno.van.der.straaten@gmail.com", "text"=>"Some feedback 2"}
    assert flash['success'].include?("succesfully sent")
    post '/portal/feedback', :feedback =>{"email"=>"onno.van.der.straaten@gmail.com", "text"=>"Some feedback 3"}
    assert flash['success'].include?("succesfully sent")
    
    post 'login/login', :user => {:email => @cash.email, :password => 'secret'}
    get "/sites/feedback/#{w.id}"
    assert_response :success 
    assert !@response.body.include?('Some feedback')

    # Admin can see
    f = Feedback.find(:first)
    post 'login/login', :user => {:email => @andy.email, :password => 'secret'}
    get "/sites/feedback/#{w.id}"
    assert @response.body.include?('id="/review/note/' + f.id.to_s)
    
    # Cadmin can destroy
    post 'login/login', :user => {:email => @george.email, :password => 'secret'}
    request.env['HTTP_REFERER'] = 'http://test.com/go/back'
    #@request.env['HTTP_REFERER'] =  "http://test.com/sites/feedback/#{w.id}" TODO this should work but doesn't
    delete "/feedbacks/#{f.id}",{}, {'HTTP_REFERER' => "/sites/feedback/#{w.id}"}
    assert_redirected_to "/sites/feedback/#{w.id}" # back
    assert !Feedback.exists?(f.id)
    
    # Make reviewer
    f = Feedback.find(:first)
    assert_nil f.reviewer
    get "/review/assign?class_name=Feedback&div_id=Feedback#{f.id}_reviewer&id=#{f.id}" , :format => 'js'
    assert_response :success
    f.reload
    assert_equal @george, f.reviewer
    get "/review/assign?class_name=Feedback&div_id=Feedback#{f.id}_reviewer&id=#{f.id}" , :format => 'js'
    assert_response :success
    f.reload
    assert_nil f.reviewer
    
    # Mark done
    assert_equal 'N', f.done
    get "/review/toggle_done?class_name=Feedback&id=#{f.id}" , :format => 'js'
    assert_response :success
    f.reload
    assert_equal 'Y', f.done
    get "/review/toggle_done?class_name=Feedback&id=#{f.id}" , :format => 'js'
    assert_response :success
    f.reload
    assert_equal 'N', f.done
    
  end
  
  def test_uploads 
    
    w = Wiki.find(:first)
    
    Rails.logger.info("No uploads")
    post 'login/login', :user => {:email => @andy.email, :password => 'secret'}
    get "sites/uploads/#{w.id}"
    assert_response :success
    
    Rails.logger.info("Cash creates upload")
    get 'uploads/new'
    assert_response :success
    post 'uploads', :upload => {:upload_type => 'Image', :description => 'OpenUP PT image', 
      :file => Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/openup_pt.jpg'), 'image/jpeg')}
    assert_redirected_to '/uploads'
    get '/uploads'
    assert_response :success
    
  end
  
  def test_obsolete 
  
    w = Wiki.find(:first)
    post 'login/login', :user => {:email => @andy.email, :password => 'secret'}

    t = Time.now
    post "/sites/obsolete/#{w.id}"
    assert_response :success
    w.reload
    assert_equal @andy, User.find(w.obsolete_by)
    assert_not_nil w.obsolete_on    

    post "/sites/obsolete/#{w.id}"
    assert_response :success
    w.reload
    assert_equal nil, w.obsolete_on
    
  end
  
 def test_comments  
    
    w = Wiki.find(:first)
    p = WikiPage.find_by_presentation_name('Estimating Guideline Template')
    assert_not_nil p
    
    Rails.logger.info("No comments")
    post 'login/login', :user => {:email => @andy.email, :password => 'secret'}
    get "sites/uploads/#{w.id}"
    assert_response :success

    Rails.logger.info("Cash creates some comments")
    get p.url
    assert_response :success
    
    ### TODO Rails 3.2 looses the session, so login again
    post 'login/login', :user => {:email => @andy.email, :password => 'secret'}
    ####
    
    get "#{w.folder}/#{p.id}/discussion"
    assert_response :success

    #http://localhost:3000/pages/view/_development_wikis_mywiki_new_guidances_guidelines_estimating_guideline_templae_BA401F96_html.js?url=http://localhost:3000/development_wikis/mywiki/new/guidances/guidelines/estimating_guideline_templae_BA401F96.html
    id = (w.rel_path + '/' + p.rel_path).gsub('/', '_').gsub('.','_') # id allows us to cache the requests (pages)    
    get "/pages/view/_#{id}.js?url=#{p.url}", :format => 'js'
    assert_response :success    
    
    [1..15].each do |i|
      post "#{w.folder}/#{p.id}/discussion", :comment => {:page_id => p.id, :site_id => w.id, :text => "Comment #{i}" }  
      assert_redirected_to "/#{w.folder}/#{p.id}/discussion"
      get "#{w.folder}/#{p.id}/discussion"
      assert_response :success
      assert @response.body.include? "Comment #{i}"
    end
    
    Rails.logger.info("Andy review comments")
    post 'login/login', :user => {:email => @andy.email, :password => 'secret'}
    get "/sites/comments/#{w.id}"
    assert_response :success
    assert @response.body.include? 'Comment 1'
    
  end


end
