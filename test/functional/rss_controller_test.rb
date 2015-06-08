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

class RssControllerTest < ActionController::TestCase
  
  def setup
    @controller = RssController.new
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    @tony = Factory(:user, :name => 'Tony Clifton', :password => 'secret', :admin => 'N')
  end

  def teardown
    [ENV['EPFWIKI_SITES_PATH'], ENV['EPFWIKI_WIKIS_PATH']].each do |p|
      FileUtils.rm_r(p) if File.exists?(p)
      FileUtils.makedirs(p)
    end
  end

  test "List" do
    @wiki = Wiki.find(:first)
    p = WikiPage.find_by_presentation_name('Toolmentor Template')
    assert_not_nil p
    for i in 0..2
      c= Comment.new(:text => "Text of comment #{i} by user tony", :user => @tony, :version => p.current_version, :page => p, :site => p.site)
      assert c.save
      co = Checkout.new(:user => @andy, :page => p, :site => @wiki, :note => "Checkout #{i} by Andy")
      assert co.save
      co.checkin(@andy)
      u = Upload.new(:filename => 'filename.html', :upload_type => 'Image', 
        :content_type => 'Content type', :description => 'Description of upload', 
        :user_id => @andy.id, :rel_path => 'x/y/z.html')
      assert u.save
    end
    get :list, :site_folder => 'all', :format => 'atom'
    assert_response :success
    #assert_valid_feed # TODO fails after upgrade Rails 3
    get :list, :site_folder => @wiki.folder, :format => 'atom' 
    assert_response :success
    assert assigns(:records)
    #assert_equal [], assigns(:records)
    
    #assert_valid_feed # TODO fails after upgrade Rails 3
    
    # TODO redirect rss
  end
  
  # Assumes you will have a development environment on http://localhost:3000 with some data
  #def test_development_with_feed_validator
  #  v = W3C::FeedValidator.new()
  #  v.validate_url('http://localhost:3000/rss/all') 
  #  puts v.to_s unless v.valid?
  #end
end
