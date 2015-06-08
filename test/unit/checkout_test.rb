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
# reset && rake log:clear test:units TEST=test/unit/checkout_test.rb
# reset && rake log:clear && ruby -I test test/unit/page_test.rb -n test_New_page_using_template

class EpfcLibraryTest < ActiveSupport::TestCase
  
  def teardown 
    [ENV['EPFWIKI_SITES_PATH'], ENV['EPFWIKI_WIKIS_PATH']].each do |p|
      FileUtils.rm_r(p) if File.exists?(p)
      FileUtils.makedirs(p)
    end
  end

  # Shows: 
  # 1. we cannot check out a page of a baseline process
  # 2. we can check out a page by supplying the user, page and site
  # 3. we cannot check out the same page twice
  # 4. we can undo a checkout
  # TODO 5. we cannot checkout a page in a site that has not been wikified yet
  # TODO 6. we can supply a note with a checkout
  # TODO 7. checkout removes 
  test "New checkout" do
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'C')
    @oup_20060721 = create_oup_20060721
    @oup_wiki = create_oup_wiki(@oup_20060721)
    #@oup_20060728 = create_oup_20060728 
    #@oup_20060825 = create_oup_20060825
    Rails.logger.debug('1 - we cannot check out a page of a baseline process')
    assert_equal 617, @oup_20060721.pages.count 
    page = WikiPage.find_by_filename('requirements,_allMQMWfEdqiT9CqkRksWQ.html')
    assert_not_nil page
    version_count = Version.count
    checkout_count = Checkout.count
    html_files_count = Site.files_html(@oup_20060721.path).size
    checkout = Checkout.new(:user => @andy, :page => page, :site => @oup_20060721)
    assert_raise(RuntimeError) {checkout.save} # TODO test for message, how "RuntimeError: Versions can only be created in Wiki sites"
    #assert_equal 'Version can\'t be blank, Site can\'t be a baseline process', checkout.errors.full_messages.join(", ")
    assert_equal version_count, Version.count
    assert_equal checkout_count, Checkout.count
    assert_equal html_files_count, Site.files_html(@oup_20060721.path).size
    
    Rails.logger.debug('2 - we can check out a page by supplying the user, page and site')
    version_count = Version.count
    checkout_count = Checkout.count
    html_files_count = Site.files_html(@oup_20060721.path).size
    checkout = Checkout.new(:user => @andy, :page => page, :site => @oup_wiki)
    assert checkout.save
    assert_equal version_count + 1, Version.count 
    assert_equal checkout_count + 1, Checkout.count
    assert_equal @oup_wiki, checkout.site # created checkout
    assert_equal page, checkout.page
    assert_equal @andy, checkout.user
    version = checkout.version # version created
    assert_equal @andy, version.user
    assert_equal @oup_wiki, version.wiki
    assert_equal page, version.page
    assert File.exists?(version.path)
    
    Rails.logger.debug('3 - we cannot check out the same page twice')
    checkout = Checkout.new(:user => @andy, :page => page, :site => @oup_wiki)
    assert_raise(RuntimeError) {checkout.save} # Checkout already exists #TODO mixed results with this, caused by page.checkout, that doesn't seem to work
    #assert_errors(checkout)
    #assert !checkout.valid?, "Checkout should have errors"
    assert_equal version_count + 1, Version.count # same as before, nothing changed
    assert_equal checkout_count + 1, Checkout.count
    
    Rails.logger.debug('4 - we can undo a checkout')
    assert_equal 1, Checkout.count
    checkout = Checkout.find(:first)
    assert_kind_of Checkout,  checkout
    assert File.exists?(checkout.version.path)
    version_path = checkout.version.path
    checkout.undo
    assert_equal version_count, Version.count # undo destroys checkout + version
    assert_equal checkout_count, Checkout.count
    assert !File.exists?(version_path)    
    checkout = Checkout.new(:user => @andy, :page => page, :site => @oup_wiki, :note => 'My checkout')
    assert checkout.save
    assert_equal 'My checkout', checkout.version.note
  end
  
  # Shows:
  # 1. an admin or user cannot checkin a file of another user
  # 2. owner (who is not an admin) can checkin
  # 3. cadmin can check in
  # 4. html can be supplied during checkin 
  # TODO 5. don't supply html which will checkin using the version file
  # 6. the version file does not contain wiki tags
  # 7. after checkin the page does
  test "Checkin" do
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    @tony = Factory(:user, :name => 'Tony Clifton', :password => 'secret', :admin => 'N')
    @oup_20060721 = create_oup_20060721
    @oup_wiki = create_oup_wiki(@oup_20060721)
    page = WikiPage.find_by_filename('artifact,_fdRfkBUJEdqrUt4zetC1gg.html')
    assert page.html.include?('body onload')
    
    assert Page::BODY_TAG_PATTERN.match(page.html)
    assert Page::TREEBROWSER_PATTERN.match(page.html)
    assert Page::COPYRIGHT_PATTERN.match(page.html)
    assert Page::HEAD_PATTERN.match(page.html)
    
    checkout = Checkout.new(:user => @tony, :page => page, :site => @oup_wiki, :note => 'Another checkout')
    assert checkout.save
    assert_kind_of Checkout,  checkout
    assert File.exists?(checkout.version.path)
    checkout.reload
    checkout_id = checkout.id
    
    Rails.logger.debug('1 - an admin or user cannot checkin a file of another user')
    assert_raise(RuntimeError) {checkout.checkin(@andy)}
    assert_raise(RuntimeError) {checkout.checkin(@cash)}

    Rails.logger.debug('2 - owner (who is not an admin) can checkin')
    checkout.checkin(@tony)
    assert !Checkout.exists?(checkout_id)
    
    Rails.logger.debug('3 - cadmin can check in')
    checkout = Checkout.new(:user => @tony, :page => page, :site => @oup_wiki, :note => 'Another checkout')
    assert checkout.save!
    checkout_id = checkout.id
    checkout.checkin(@george)
    assert !Checkout.exists?(checkout_id)
    
    Rails.logger.debug('4 - html can be supplied during checkin')
    
    assert Page::BODY_TAG_PATTERN.match(page.html)
    assert Page::TREEBROWSER_PATTERN.match(page.html)
    assert Page::COPYRIGHT_PATTERN.match(page.html)
    assert Page::HEAD_PATTERN.match(page.html)
    
    checkout = Checkout.new(:user => @tony, :page => page, :site => @oup_wiki, :note => 'Another checkout')
    assert checkout.save!
    version = checkout.version
    checkout_id = checkout.id
    html = checkout.version.html
    html = html.gsub('making responsibility easy to identify','##replaced text##')
    
    assert Page::BODY_TAG_PATTERN.match(version.html) # still there
    assert !Page::TREEBROWSER_PATTERN.match(version.html) # is replaced by placeholder
    assert version.html.include? Page::TREEBROWSER_PLACEHOLDER
    assert Page::COPYRIGHT_PATTERN.match(version.html)
    assert !Page::HEAD_PATTERN.match(version.html)
    
    checkout.checkin(@tony, html)
    assert !Checkout.exists?(checkout_id)
    assert version.html.index('##replaced text##')
    assert page.html.index('##replaced text##')

    assert Page::BODY_TAG_PATTERN.match(page.html)
    assert Page::TREEBROWSER_PATTERN.match(page.html)
    assert Page::COPYRIGHT_PATTERN.match(page.html)
    assert Page::HEAD_PATTERN.match(page.html)
    
    Rails.logger.debug('5 - don\'t supply html which will checkin using the version file')
    
    Rails.logger.debug('6 - the version file does not contain wiki tags')
    checkout = Checkout.new(:user => @tony, :page => page, :site => @oup_wiki, :note => 'Another checkout')     
    assert checkout.save!
    version = checkout.version
    html_version = version.html
    html_page = version.page.html
    # removed stuff in version file
    assert_equal nil, html_version.index('body onload') # onload was removed
    assert_equal nil, html_version.index('<!-- epfwiki head start -->') # wiki stuff removed
    assert_equal nil, html_version.index('<!-- epfwiki iframe start -->')
    # replaced stuff in version file
    #File.open('magweg.html', 'w') {|f| f.write(html_page) }
    assert_not_nil html_version.index(Page::TREEBROWSER_PLACEHOLDER)   # TODO test this 
    # assert_not_nil html_version.index('<!-- copyright statement -->')    
    # stuff to be removed from page
    
    #File.open('magweg2.html', 'w') {|f| f.write(html_page) }
    assert_not_nil html_page.index('body onload')  
    # stuff to be replace in page
    assert_not_nil  html_page.index('treebrowser.js')
    assert_not_nil  html_page.index('class="copyright"')   

    Rails.logger.debug('7 - after checkin the page does')
    html_version = html_version.gsub('making responsibility easy to identify','##replaced text##')
    checkout.checkin(@tony, html_version)
    html_page = version.page.html
    # stuff to be removed from page back in page
    assert_not_nil html_page.index('##replaced text##') 
    assert_not_nil html_page.index('body onload')     
    # stuff to be replaced in page back in page
    assert_not_nil  html_page.index('treebrowser.js')
    assert_not_nil  html_page.index('class="copyright"') 
  end
  
  # Shows that a user will start receiving notifications about page changes after checkin of a page
  test "Notification subscription" do
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'C')
    @george = Factory(:user, :name => 'George Clifton', :password => 'secret', :admin => 'Y')
    @oup_20060721 = create_oup_20060721
    @oup_wiki = create_oup_wiki(@oup_20060721)
    page = WikiPage.find(:first)
    checkout = Checkout.new(:user => @andy, :page => page, :site => page.site)
    assert checkout.save
    assert !Notification.find_all_users(page, Page.name).include?(@andy)
    checkout.checkin(@andy)
    assert Notification.find_all_users(page, Page.name).include?(@andy)
    checkout = Checkout.create(:user => @andy, :page => page, :site => page.site)    
    assert checkout.save
    checkout.checkin(@andy)
    assert Notification.find_all_users(page, Page.name).include?(@andy)
    checkout = Checkout.create(:user => @george, :page => page, :site => page.site)    
    assert checkout.save
    checkout.checkin(@george)
    assert Notification.find_all_users(page, Page.name).include?(@george)
  end
end
