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

class UploadsControllerTest < ActionController::TestCase
  
  def setup
    @controller = UploadsController.new
    #@request    = ActionController::TestRequest.new
    #@response   = ActionController::TestResponse.new
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    @tony = Factory(:user, :name => 'Tony Clifton', :password => 'secret', :admin => 'N')
  end
  
  # Shows:
  # 1. Logon
  # 2. Logged in user can upload image
  # 4. User cannot update upload of another user
  # 5. Admin can update upload of another user
  # 6. Admin cannot destroy upload of another user
  # 7. User cannot destroy own upload
  # 8. Cadmin can destroy upload of another user
  test "New and list uploads" do 
    assert_equal 0, Upload.count
    # 1
    post :new
    assert_redirected_to :controller => 'login'
    # 2
    session['user'] = @andy.id
    post :create, :upload => {:upload_type => 'Image', :description => 'OpenUP PT image', :file => Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/openup_pt.jpg'), 'image/jpeg')}
    assert_redirected_to :action => 'index'
    assert_equal 1, Upload.count
    assert_not_nil assigns(:upload)
    assert File.exists?(assigns(:upload).path)

    # 4
    assert_equal 1, Upload.count
    get :index
    session['user'] = @tony.id
    upload = Upload.find(:first)
    post :update, :id => upload.id, :upload => {:description => 'image'}
    assert_equal Utils::FLASH_NOT_OWNER, flash['error']
    upload.reload
    assert_equal 'OpenUP PT image', upload.description
    flash['error'] = nil
    # 5
    upload.user = @tony
    assert upload.save
    session['user'] = @andy.id # het lukt me niet om de session user te veranderen
    assert_equal @andy, session_user
    post :update, :id => upload.id, :upload => {:description => 'image'}
    assert_equal nil, flash['error']
    upload.reload
    assert_equal 'image', upload.description
    # 6
    get :index
    session['user'] = @andy.id
    upload = Upload.find(:first)
    assert session['user'] != upload.user.id
    post :destroy, :id => upload
    assert_equal LoginController::FLASH_UNOT_CADMIN, flash['error']
    assert Upload.exists?(upload.id)
    upload2 = Upload.new(:filename => upload.filename, :upload_type => upload.upload_type, 
    :content_type => upload.content_type, :description => upload.description, 
    :user_id => upload.user_id, :rel_path => upload.rel_path)
    assert upload2.save
    # 7
    session['user'] = @tony.id
    assert_equal session['user'], upload.user.id
    post :destroy, :id => upload
    assert Upload.exists?(upload)
    # 8 # TODO test this, currently we cannot test this because use of request.referer causes errors: "The error occurred while evaluating nil.[]"
    session['user'] = @george.id
    assert session['user'] != upload2.user.id
    assert_equal 2, Upload.count
    post :destroy, :id => upload2
    assert !Upload.exists?(upload2)
    assert_equal 1, Upload.count    
  end
  
end
