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

class CreatingSitesAndWikisTest < ActionDispatch::IntegrationTest

  def setup
    #logger.debug "Test Case: #{name}"
    @george = Factory(:user, :name => 'George Shapiro', :password => 'secret', :admin => 'C')
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'Y')
    @cash = Factory(:user, :name => 'Cash Oshman', :password => 'secret', :admin => 'N')
    @tony = Factory(:user, :name => 'Tony Clifton', :password => 'secret', :admin => 'N')
    @wiki = Wiki.find(:first)
    @bp = @wiki.baseline_process
  end
  
  def teardown
    [ENV['EPFWIKI_SITES_PATH'], ENV['EPFWIKI_WIKIS_PATH']].each do |p|
      FileUtils.rm_r(p) if File.exists?(p)
      FileUtils.makedirs(p)
    end
  end
  
  # Shows:
  # 1. user makes a change (checkout, checkin) (about_base_concepts)
  # 2. user makes a change (checkout, checkin) (any_role) and marks versions done
  # 3. user creates a checkout and saves a change (determine_architectural_feasibility)
  # 4. user create a checkout and saves a change (requirements)
  # 5. openup is updated to "openup0728"
  # 6. changes to "about_page_concepts" are still there, 
  #     the page was not harvested (there are version marked 'todo'
  # 7. changes to any_role are gone, the page was harvested
  # 8. changes to feasibility are gone, but they remain in checked-out version, of course
  # 9. changes to requirements are gone, but they remain in checked-out version, of course
  # 10. user checks in feasibility
  # 11. undo of checkout requirements, changes are lost, there are no unharvested versions
  # 12. undo of page with unharvested changes of another baseline (update to "openup0825"), feasibility
  # 13. checkout of "about_page_concepts" creates version 1
  # TODO http://blog.finalist.com/2007/02/12/test-driven-development-met-ruby-on-rails/
  
  test "Create sites and wikis" do 
    get '/'
    get 'portal/home'
    assert_response :success
    assert_no_errors
    user = login(@tony)
    # 1
    @page1 = WikiPage.find_by_presentation_name('Toolmentor Template')
    user.post 'pages/checkout', :user_version => {:version_id => @page1.current_version.id, :note => 'Changing toolmentor template'}
    assert_not_nil @page1.checkout
    user.assert_redirected_to :action => 'edit', :checkout_id => @page1.checkout.id
    assert_not_nil @page1.checkout
    html = @page1.html
    assert_not_nil html
    html = html.gsub('type of guidance', 'novel, novel, novel, aspects')
    user.post 'pages/checkin', :checkout_id => @page1.checkout.id, :html => html
    #assert_equal PagesController::FLASH_CHECKIN_SUCCESS, user.flash['success'] # TODO can't test this because we use flash.now, this only works without 'now'
    assert_equal 1, @page1.current_version.version
    assert_nil @page1.checkout
    assert @page1.html.include?('novel, novel, novel, aspects')
    # 2
    page2 = WikiPage.find_by_presentation_name('Checklist Template')
    user.post 'pages/checkout', :user_version => {:version_id => page2.current_version.id, :note => 'Changing checklist template'}
    user.assert_redirected_to :action => 'edit', :checkout_id => page2.checkout.id
    assert_equal 0, page2.checkout.version.source_version.version
    html = page2.html
    assert_not_nil html
    html = html.gsub('completed or verified', 'by any, any, any one')
    user.post 'pages/checkin', :checkout_id => page2.checkout.id, :html => html
    #assert_equal PagesController::FLASH_CHECKIN_SUCCESS, user.flash['success'] can't test for flash now
    assert_equal 2, page2.versions.size
    assert_nil page2.checkout
    page2.versions.each do |v|
      if v.version == 0
        assert_equal 'Y', v.done 
      else
        assert_equal 'N', v.done
        v.done = 'Y'
        assert v.save       
      end
    end
    # 3
    page3 = WikiPage.find_by_presentation_name('Practice Template')
    user.post 'pages/checkout', :user_version => {:version_id => page3.current_version.id, :note => 'Changing feasibility'}
    user.assert_redirected_to :action => 'edit', :checkout_id => page3.checkout.id    
    assert_equal 0, page3.checkout.version.source_version.version
    html = page3.html
    assert_not_nil html
    html = html.gsub('a proven way or strategy of doing work', 'Confirm, confirm, confirm that the project')
    user.post 'pages/save', :checkout_id => page3.checkout.id, :html => html
    assert_not_nil page3.checkout
    # 4
    page4 = WikiPage.find_by_presentation_name('Report Template')
    user.post 'pages/checkout', :user_version => {:version_id => page4.current_version.id, :note => 'Changing requirements'}
    user.assert_redirected_to :action => 'edit', :checkout_id => page4.checkout.id   
    assert_equal 0, page4.checkout.version.source_version.version
    html = page4.html
    assert_not_nil html
    html = html.gsub('predefined template of a result', 'list, list, list of work')
    user.post 'pages/save', :checkout_id => page4.checkout.id, :html => html
    assert_not_nil page4.checkout
    assert_equal 1, page4.versions.size # NOTE checkout.version is not counted by page4.versions
    # 5
    # TODO test for sending of email
    cv_before = @page1.current_version
    update = Update.new(:wiki => @wiki, :user => @george, :baseline_process => @bp)
    assert update.save
    update.do_update
    # 6
    #assert @page1.html.index('novel, novel, novel, aspects') todo activate
    cv_after = @page1.current_version
    assert_equal cv_before, cv_after # same version
    assert cv_after.current # marked current
    # 7
    assert !page2.html.index('by any, any, any one')
    # 8
    assert !page3.html.index('Confirm, confirm, confirm that the project')
    assert page3.checkout.version.html.index('Confirm, confirm, confirm that the project')
    # 9
    assert !page4.html.index('list, list, list of work')
    assert page4.checkout.version.html.index('list, list, list of work')
    # 10
    co = page3.checkout
    user.post 'pages/checkin', :checkout_id => co.id # is checked in on baseline OpenUP-Basic_published_20060728test!
    page3.reload
    assert_nil page3.checkout
    assert page3.html.index('Confirm, confirm, confirm that the project')
    page3.reload
    v0, v1, v2 = page3.versions[0], page3.versions[1], page3.versions[2]
    assert_equal ['BaselineProcessVersion', 'BaselineProcessVersion', 'UserVersion'],[v0.class.name, v1.class.name, v2.class.name]
    assert_equal [[0,@bp.title],[1,@bp.title], [2,nil]],
    [  [v0.version, v0.baseline_process.title],
    [v1.version, v1.baseline_process.title],
    [v2.version, v2.baseline_process_id]]
    assert_equal 3, page3.versions.size # previous 2, current 2 versions 
    version = page3.current_version
    # 11
    checkout = page4.checkout
    user.post 'pages/undocheckout', :checkout_id => checkout.id
    page4.reload
    assert_nil page4.checkout
    version = page4.current_version
    assert_equal 1, version.version
    assert !version.current 
    # 12
    # create checkout
    user.post 'pages/checkout',:user_version => {:version_id => page3.current_version.id, :note => 'Changing stuff'}
    user.assert_redirected_to :action => 'edit', :checkout_id => page3.checkout.id
    assert_equal 2, page3.checkout.version.source_version.version 
    v = page3.current_version
    lv = page3.last_version
    assert_equal 'N', v.done # version is not harvested
    assert !v.current # also not current, it doesn't need to be, because there is a checkout
    assert v = lv
    assert_equal 2, lv.version
    assert_equal 2, v.version
    assert_equal v.id, page3.checkout.version.source_version.id
    html = page3.html
    assert_not_nil html
    assert html.index('Confirm, confirm, confirm that')
    # update wiki
    update = Update.new(:wiki => @wiki, :user => @george, :baseline_process => @bp)
    assert update.save
    update.do_update
    version = page3.current_version
    # undo checkout
    user.post 'pages/undocheckout', :checkout_id => page3.checkout.id
    version.reload
    assert_equal version, page3.current_version
    # 13
    version = @page1.current_version
    assert version.current # explicitly set version as there were unharvested versions during update
    assert_not_nil @page1.current_version
    user.post 'pages/checkout',:user_version => {:version_id => @page1.current_version.id, :note => 'Changing stuff'}
    version.reload
    assert version.current # version remains current
    checkout = @page1.checkout
    assert_not_nil checkout
    assert_equal version, checkout.version.source_version # current version was selected as the source version    
  end
  
end
