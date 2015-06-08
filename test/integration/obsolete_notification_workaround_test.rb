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

class ObsoleteNotificationWorkaroundTest < ActionDispatch::IntegrationTest

  # Shows that dangling Notification records are deleted when accessed tru users/account or users/show
  test "Notification destroy workaround" do
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    #get "login/login"
    post 'login/login', :user => {:email => @andy.email, :password => 'secret'}
    assert_equal @andy, session_user
    p = WikiPage.find_by_presentation_name('Toolmentor Template')
    template = Site.templates[0]
    w = p.site
    assert_equal 0, Notification.count
    post "#{w.folder}/#{p.id}/new", 
      :page => {:presentation_name => 'New page', :source_version => template.id}
    assert assigns(:checkout)
    assert_redirected_to  :action => 'edit', :checkout_id => assigns(:checkout).id
    p2,w,np,co = assigns(:page), assigns(:wiki), assigns(:new_page), assigns(:checkout)
    [p2,w,np,co].each {|o|o.reload}
    assert_equal 1, Notification.count # checkout creates notification?
    #assert Notification.create(:user => session_user, :page => p2, :notification_type => 'Page')
    post 'pages/undocheckout', :checkout_id => co.id
    assert_equal 1, Notification.count # Notification still exists although page was deleted
    get 'users/account'
    assert_response :success
    assert_equal 0, Notification.count, "Obsolete notification should be deleted"
    get "users/#{@andy.id}"
    assert_response :success
    # another time for show
    post "#{w.folder}/#{p.id}/new", 
      :page => {:presentation_name => 'New page', :source_version => template.id}
    assert_redirected_to  :action => 'edit', :checkout_id => assigns(:checkout).id
    p2,w,np,co = assigns(:page), assigns(:wiki), assigns(:new_page), assigns(:checkout)
    #assert Notification.create(:user => session_user, :page => p2, :notification_type => 'Page')
    assert_equal 1, Notification.count
    post 'pages/undocheckout', :checkout_id => co.id
    assert_equal 1, Notification.count
    get "users/#{@andy.id}"
    assert_response :success
    assert_equal 0, Notification.count
  end
end
