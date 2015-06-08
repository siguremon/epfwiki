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

# reset && rake log:clear test:functionals TEST=test/functional/comments_controller_test.rb
class CommentsControllerTest < ActionController::TestCase

  def setup
    #Rails.logger.info "Test Case: #{name}"  
    @controller = CommentsController.new
    #@request    = ActionController::TestRequest.new
    #@response   = ActionController::TestResponse.new
    #@wiki = create_templates
    #@andy, @george, @tony = users(:andy), users(:george), users(:tony) # admin, cadmin, user
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
  
  # Shows: 
  # 1. All users can access the edit form (including anonymous users)
  # 2. Cadmin can update and destroy
  test "Edit update destroy" do 
    # 1
    p = WikiPage.find_by_presentation_name('Toolmentor Template')
    c = Comment.create(:text => 'Text of comment by user tony', :user => @tony, :version => p.current_version, :page => p, :site => p.site)
    get :edit, :id => c.id
    assert_response :success
    session['user'] = @andy.id
    get :edit, :id => c.id
    assert_response :success
    assert_match 'Text of comment by user tony', @response.body
    # 2
    #post :destroy
    delete 'destroy', :id => 999 # id does not matter
    assert_unot_cadmin_message
    put 'update', :id => 999 # id does not matter
    assert_unot_cadmin_message
    session['user'] = @george.id
    post :destroy, :id => c.id 
    assert_redirected_to :controller => 'sites', :action => 'comments', :id => p.site.id
    # TODO test update
  end
  
end
