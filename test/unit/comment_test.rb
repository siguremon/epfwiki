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
# rake log:clear test:units TEST=test/unit/checkout_test.rb

class EpfcLibraryTest < ActiveSupport::TestCase

   def teardown 
    [ENV['EPFWIKI_SITES_PATH'], ENV['EPFWIKI_WIKIS_PATH']].each do |p|
      FileUtils.rm_r(p) if File.exists?(p)
      FileUtils.makedirs(p)
    end
  end

  # Shows that a user will start receiving notifications about page changes after creating a comment about a page
  test "Notification" do
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'C')
    @oup_20060721 = create_oup_20060721
    @oup_wiki = create_oup_wiki(@oup_20060721)
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    #wiki = create_templates
    #wiki.reload
    version = Version.find(:first)
    assert !Notification.find_all_users(version.page, Page.name).include?(@andy)
    Comment.create(:text => 'test', :user => @andy, :version => version, :page => version.page, :site => version.wiki)
    assert Notification.find_all_users(version.page, Page.name).include?(@andy)
    Comment.create(:text => 'another test', :user => @andy, :version => version, :page => version.page, :site => version.wiki)
    assert Notification.find_all_users(version.page, Page.name).include?(@andy)
    Comment.create(:text => 'another test', :user => @cash, :version => version, :page => version.page, :site => version.wiki)
    assert Notification.find_all_users(version.page, Page.name).include?(@cash)
  end
end
