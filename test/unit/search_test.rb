# Copyright (c) 2006-2013 OnKnows.com, Logica, 2008 IBM, and others
#  
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
#Contributors:
#* Onno van der Straaten:: initial implementation

# reset && rake log:clear && ruby -I test test/unit/search_test.rb -n test_Search
require 'test_helper'

class SearchTest < ActiveSupport::TestCase

  # We can only test search without transactions, Sphinx search uses separate db connection
  self.use_transactional_fixtures = false

  def setup
    Sphinx.index
    Sphinx.start
  end

  def teardown
    Site.reset
    Sphinx.stop
  end
  
  # Shows:
  # 1. After create OpenUP we can search but won't find 
  # 2. We run indexer and find 20 records
  # 3. Update page and find update page text
  # 4. Find using uma_name, uma_type,presentation_name
  # 5. Filter using site and uma_type
  # 6. We can search comments, version notes and user name
  test "Search" do
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'N')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    # 1
    Sphinx.index # make sure index is up to date
    @oup_wiki = create_oup_wiki
    assert_equal [], (Page.search 'OpenUP')
    # 2
    Sphinx.index # run the indexer again
    i = 0
    while (Page.search 'OpenUP').length == 0 and i < 5 do
      puts "Index not ready..."
      i += 1
      sleep 5
    end
    assert_equal 20, (Page.search 'OpenUP').length
    # 3
    page = WikiPage.find(:first, :conditions => ['filename = ? and site_id = ?','test_data,_0ZZFcMlgEdmt3adZL5Dmdw.html', @oup_wiki])
    checkout = Checkout.new(:user => @george, :page => page, :site => @oup_wiki, :note => 'Another checkout')     
    assert checkout.save!
    version = checkout.version
    html_version = version.html
    html_page = version.page.html
    html_version = html_version.gsub('systematically test how the system under test uses data','systematically test how the system under test uses bitcoin')
    checkout.checkin(@george, html_version)
    html_page = version.page.html
    Sphinx.index
    i = 0
    while (Page.search 'bitcoin').length == 0 and i < 5 do
      puts "Index not ready..."
      i += 1
      sleep 5
    end
    pages = Page.search 'bitcoin'
    assert_equal 1, pages.length
    assert_equal page, pages.first
    # 4 Find using uma_name, uma_type,presentation_name
    assert_equal 'test_data', page.uma_name
    assert_equal Page.where(:uma_name => 'test_data').count, (Page.search 'test_data').length
    assert_equal UmaType.where(:name => 'CustomCategory').first.pages.count,(Page.search 'CustomCategory').length
    assert_equal Page.where(:presentation_name => 'Test Data').count, (Page.search :conditions => {:presentation_name => 'Test Data'}).length
    # 5 filter
    ut = UmaType.where(:name => 'CustomCategory').first
    assert_equal ut.pages.count, (Page.search :with => {:type => ["#{ut.id}"]}).length
    pages = (Page.search :with => {:site => ["#{@oup_wiki.id}"]}) # returns first 20 records, default page size
    assert_equal @oup_wiki.pages.count, pages.total_entries
    # 6 We can search comments, version notes and user name
    assert_equal page.id, (Page.search @george.name)[0].id, "George created version of #{page.presentation_name} (#{page.id}), we should be able to find it using his name"
    Comment.create(:text => 'Buy Altcoin!', :user => @andy, :version => version, :page => version.page, :site => version.wiki)
    Comment.create(:text => 'Buy Bitcoin!', :user => @andy, :version => version, :page => version.page, :site => version.wiki)
    Comment.create(:text => 'Buy gold, silver! Before it is too late!', :user => @george, :version => version, :page => version.page, :site => version.wiki)
    assert_equal 3, Comment.count
    assert_equal [], (Page.search @andy.name), "Index not updated yet, we should not find anything"
    Sphinx.index
    i = 0
    while (Page.search 'gold silver').length == 0 and i < 5 do
      puts "Index not ready..."
      i += 1
      sleep 5
    end
    assert_equal page.id, 
      (Page.search @george.name)[0].id, 
      "Andy created a comment for page #{page.presentation_name} (#{page.id}), we should be able to find it using his name"
    assert_equal page.id, 
      (Page.search 'altcoin')[0].id,
      "We should be able to find using 'altcoin'"
    assert_equal page.id, 
      (Page.search 'gold silver')[0].id,
      "We should be able to find using 'gold'"
    assert_equal page.id, 
      ((Page.search 'Another checkout')[0]).id,
      "We should be able to search version notes"      
  end

end
