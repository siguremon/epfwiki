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

class OtherControllerTest < ActionController::TestCase
  
  def setup
    @controller = OtherController.new
  end
  
  def teardown
    [ENV['EPFWIKI_SITES_PATH'], ENV['EPFWIKI_WIKIS_PATH']].each do |p|
      FileUtils.rm_r(p) if File.exists?(p)
      FileUtils.makedirs(p)
    end
  end  

  # Shows all users can access information about the application with other/about
  test "About" do
    get :about
    assert_response :success
  end
  
  # Shows that also for logged on users
  test "About2" do
    george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    assert_not_nil george
    session['user'] = george.id
    get :about
    assert_response :success
  end

  test "Reset" do 
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')    
    get :reset
    assert_redirected_to :controller => 'other', :action => 'error'
    assert flash['error'].include?(LoginController::FLASH_UNOT_CADMIN)
    session['user'] = @cash.id
    get :reset
    assert flash['error'].include?(LoginController::FLASH_UNOT_CADMIN)
    session['user'] = @andy.id
    get :reset
    assert flash['error'].include?(LoginController::FLASH_UNOT_CADMIN)
    session['user'] = @george.id
    get :reset
    assert flash['warning'].include?(OtherController::FLASH_WARNING)
    post :reset
    assert_redirected_to :controller => 'login', :action => 'new_cadmin'
    assert flash['success'].include?(OtherController::FLASH_SUCCESS)
  end
 
end
