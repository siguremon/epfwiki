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

class VersionsControllerTest < ActionController::TestCase
  
  def setup
    #logger.debug "Test Case: #{name}"  
    @controller = VersionsController.new
    #@request    = ActionController::TestRequest.new
    #@response   = ActionController::TestResponse.new
    #@oup_20060721 = create_oup_20060721
    #@oup_wiki = create_oup_wiki(@oup_20060721)
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
  
  # Shows
  # 1. Login required
  # 2. All users can access version details
  # 3. Get diif of equal versions
  # 4. Post diff of equal versions
  # 5. Post diff of versions with differences
    #show, diff, text, note
  def test_show_and_diff
    p = WikiPage.find(:first)
    create_some_data(p)
    # 1
    version = Version.find(:first)
    assert_not_nil version
    get :show, :id => version.id
    assert_tologin
    # 2
    [@andy, @george, @tony].each do |user|
      session['user'] = user.id
      Version.find(:all).each do |v|  
        get :show, :id => v.id
        # 2
        assert_response :success
        assert_not_nil assigns(:version)
      end
    end
    assert_equal 17, p.versions.size
    v1 = p.versions[14]
    v2 = p.versions[15]
    # 3
    get :diff, :id => v2.id
    assert_response :success
    assert_not_nil assigns(:version)
    assert_equal v1, assigns(:version).source_version
    assert_equal assigns(:versions), p.versions
    assert_equal p, assigns(:page)
    assert_equal p.site, assigns(:wiki)
    # 4
    post :diff, :user_version => {:id => v2.id, :version_id => v1.id}
    assert_response :success
    assert_equal assigns(:versions), p.versions
    assert_equal p, assigns(:page)
    assert_equal p.site, assigns(:wiki)
    # 5
    v2.html = v2.html.gsub('</body>','a change</body>')      
    post :diff, :user_version => {:id => v2.id, :version_id => v1.id}
    assert_response :success
    assert_equal assigns(:versions), p.versions
    assert_equal p, assigns(:page)
    assert_equal p.site, assigns(:wiki)
  end
  
end
