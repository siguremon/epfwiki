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

require 'simplecov'
SimpleCov.start 'rails'

ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require File.dirname(__FILE__) + "/factories"
#require 'md5' # TODO fails after upgrade Rails 3
#require 'feed_validator/assertions' # TODO fails aftwer upgrade Rails 3

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  #fixtures :all

  #def login(who)
  #  Rails.logger.debug("Login: #{who.inspect}")
  #  open_session do |sess|
  #    Rails.logger.debug("Opening session")
  #    sess.post "login/login", :user => {:email => who.email, :password => who.password }
  #    assert_not_nil sess.assigns(:logged_in_user)
  #  end
#end


  module TestingDSL
    # TODO cleanup    
  end
  
  def login(who)
    Rails.logger.debug("Login: #{who.inspect}")
    assert_not_nil who.confirmed_on, "User not confirmed"
    open_session do |sess|
      Rails.logger.debug("Opening session: email: #{who.email}, password: #{who.password}")
      u = User.find_by_email(who.email)
      assert_not_nil u, "Email #{who.email} not found"
      Rails.logger.debug("Hashed password: #{u.hashed_password}")     
      sess.extend(TestingDSL)
      sess.post "login/login", :user => {:email => who.email, :password => who.password }
      assert_not_nil sess.assigns(:logged_in_user) # TODO enable
    end
  end
  
  # Method #create_some_data creates some test records for a page (Comment, Checkout, Upload, New Page)
  def create_some_data(p, u = @andy)
    for i in 0..15
      c= Comment.new(:text => "Text of comment #{i} by user tony", :user => u, :version => p.current_version, :page => p, :site => p.site)
      assert c.save
      co = Checkout.new(:user => u, :page => p, :site => p.site, :note => "Checkout #{i} by Andy")
      assert co.save
      co.checkin(u)
      upl = Upload.new(:filename => 'filename.html', :upload_type => 'Image', 
        :content_type => 'Content type', :description => 'Description of upload', 
        :user_id => u.id, :rel_path => 'x/y/z.html')
      assert upl.save
      new_page2, new_co2 = WikiPage.new_using_template(:presentation_name => 'New Page Using Another Page as a Template', :source_version => p.current_version, :user => u, :site => p.site)  
      assert_no_errors(new_page2)
      assert_no_errors(new_co2)
      new_co2.checkin(u)
    end
  end
  
  def assert_field(name)
    assert_tag :tag => "input", :attributes => {:id => name}
  end
  
  def assert_no_field(name)
    assert_no_tag :tag => "input", :attributes => {:id => name}
  end
  
  def assert_wiki_menu(wiki, page, html, action)
    result_expected = []
    result_expected << ["", '/' + wiki.rel_path + '/' + page.rel_path, "View"]
    result_expected << ["", "/#{wiki.site_folder}/#{page.id}/discussion", "Discussion"]
    result_expected << ["", "/#{wiki.site_folder}/#{page.id}/edit", "Edit"]
    result_expected << ["", "/#{wiki.site_folder}/#{page.id}/new", "New"]
    result_expected << ["", "/#{wiki.site_folder}/#{page.id}/info", "Info"]
    result_expected << ["", "/", "Home"]
    result_expected.each do |r|
      r[0] = " class=\"current\"" if r[2] == action
    end
    result = html.scan(/<a href="(.*?)".*?<span>(.*?)<\/span>/)    
    assert result_expected, result
    if action == 'edit'
      # TODO implement functional test for confirm message
    end
  end
  
  def assert_errors(object = nil)
    if object
      object.errors.full_messages.each do |message|
        assert_tag :content => message
      end
    else
      assert_tag error_message_field      
    end
  end
  
  def assert_no_errors(object = nil) # TODO when there are errors this will fail with no method defined on assert_no_tag
    if object
      object.errors.full_messages.each do |message|
        #assert_no_tag :content => message 
        #assert_no_tag :
        assert_no_tag message
      end
    else
      assert_no_tag error_message_field
    end
  end
  
  def assert_pattern(pat, html, result)
    html =~ pat
    assert_equal result, $&
  end
  
  def error_message_field
    {:tag => 'div', :attributes => { :class => 'errorExplanation', :id => 'errorExplanation' }}
  end
  
  def assert_save(object)
    if !object.save
      assert_equal '', object.errors.full_messages.join(", ")      
    end
  end
  
  def assert_enhanced_file(path)
    html = IO.readlines(path).join
    # r =  [html.include?("<!-- epfwiki head start -->"), html.include?("onload"), html.include?("<!-- epfwiki head end -->")]
    # onload is not necessary anymore, this is now included in wiki.js
     r =  [html.include?("<!-- epfwiki head start -->"), true, html.include?("<!-- epfwiki head end -->")]

    Rails.logger.debug "assert_enhanced_file:  #{r.join(',')} for #{path}"
    assert_equal [true, true, true], r 
  end 
  
  def assert_version_file(path)
    html = IO.readlines(path).join
    Rails.logger.debug('html: ' + html)
    assert_equal [path, false,true, true], [path, html.include?('<!-- epfwiki head start -->'), html.include?('<body>'), html.include?("<div id=\"treebrowser_tag_placeholder\">")]
  end
  
  def assert_tologin
    #assert_equal  ::MSG_LOGIN, flash['notice']
    assert_equal @request.fullpath, session["return_to"]
    assert_redirected_to :controller => 'login'
  end
  def assert_unot_admin_message
    assert_equal LoginController::FLASH_UNOT_ADMIN, flash['error']
    assert_redirected_to :controller => "other", :action => "error"
  end
  def assert_unot_cadmin_message
    assert_equal LoginController::FLASH_UNOT_CADMIN, flash['error']
    assert_redirected_to :controller => "other", :action => "error"
  end
  
  def assert_illegal_get
    assert_redirected_to :controller => 'other', :action => 'error'
    assert Utils::FLASH_USE_POST_NOT_GET, flash['error']
  end
 
  def copyright_files(path)
    paths = Array.new
     (Dir.entries(path) - [".", ".."]).each do |entry| 
      new_path = File.expand_path(entry, path)
      if FileTest.directory?(new_path)   
        paths = paths + copyright_files(new_path)
      else
        if entry =~ /\.rb\z/i
          paths << new_path 
        end
      end
    end
    return paths
  end
  
  # Test helper integration tests
  def assert_page_success(page, user = nil)

    w = page.site
    
    get page.url # e.g. /development_wikis/mywiki/new/guidances/toolmentors/toolmentor_template_E9930C53.html
    assert_response :success, "assert_page_success View #{page.url}"
    
    id = (w.rel_path + '/' + page.rel_path).gsub('/', '_').gsub('.','_') # id allows us to cache the requests (pages)
    #http://localhost:3000/pages/view/_development_wikis_mywiki_new_guidances_toolmentors_toolmentor_template_E9930C53_html.js?url=http://localhost:3000/development_wikis/mywiki/new/guidances/toolmentors/toolmentor_template_E9930C53.html
    url = "pages/view/_#{id}.js?url=#{page.url}"
    get url
    assert_response :success, "Not success: view #{page.url} AJAX"
    
    # TODO Workaround implemented for Rails destroying session
    if user
      Rails.logger.info("LOGIN")
      post 'login/login', :user => {:email => user.email, :password => 'secret'}
    else
      Rails.logger.info("NO LOGIN")
    end
    
    get "#{w.folder}/#{page.id}/discussion"
    assert_response :success, "Not success: discussion #{page.url}!"
    
    #Rails.logger.info("assert_page_success Edit #{page.url}")
    get "#{w.folder}/#{page.id}/edit"
    assert_redirected_to :controller => 'pages', :action => 'checkout', :id => page.id, :site_folder => w.folder
    
    get "#{w.folder}/#{page.id}/new"
    assert_response :success, "Not success: new #{page.url}"

    get "#{w.folder}/#{page.id}/history"
    assert_response :success, "Not success: history #{page.url}"

  end
  
  def session_user
    User.find(session['user']) if session and session['user']
  end
    
end
