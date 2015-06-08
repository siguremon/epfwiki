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

class FeedbacksControllerTest < ActionController::TestCase

  def setup
    #logger.debug "Test Case: #{name}"  
    @controller = FeedbacksController.new
    #@request    = ActionController::TestRequest.new
    #@response   = ActionController::TestResponse.new
    #@andy = users(:andy) # admin
    #@george = users(:george) # central admin
    #@tony = users(:tony) # user
    #@emails = ActionMailer::Base::deliveries
    #@emails.clear
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    @tony = Factory(:user, :name => 'Tony Clifton', :password => 'secret', :admin => 'N')
  end

  test "Edit feedback"  do
    get :edit, :id => 999
    assert_unot_cadmin_message
  end

  test "Destroy feedback" do 
    feedback = Feedback.create(:email => 'x@adb.com',:text => 'test_show')
    session['user'] = @andy.id
    assert_nothing_raised {Feedback.find(feedback.id)}

    post :destroy, :id => feedback.id
    assert_unot_cadmin_message
    
    request.env["HTTP_REFERER"] = '/portal/feedback'
    session['user'] = @george.id
    post :destroy, :id => feedback.id
    
    assert_response :redirect
    assert_redirected_to '/portal/feedback'

    assert_raise(ActiveRecord::RecordNotFound) {Feedback.find(feedback.id)}
  end
end
