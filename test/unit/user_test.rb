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
require 'openssl'
require 'digest/sha1'

class EpfcLibraryTest < ActiveSupport::TestCase
 
  def teardown
    [ENV['EPFWIKI_SITES_PATH'], ENV['EPFWIKI_WIKIS_PATH']].each do |p|
      FileUtils.rm_r(p) if File.exists?(p)
      FileUtils.makedirs(p)
    end
  end

  test "Create" do
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'C')
    assert_kind_of User, @andy
    #assert_equal 1, @andy.id
    assert_equal "fooandy.kaufman@epf.eclipse.org", @andy.email
    assert_equal "Andy Kaufman", @andy.name
    assert_equal "localhost", @andy.ip_address
    assert_equal Utils.hash_pw('secret'), @andy.hashed_password
    assert_equal "C", @andy.admin
  end
  
  test "New sign up" do
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'C')
    assert User.count > 0
    assert_not_nil ENV['EPFWIKI_DOMAINS']
    # we need params
    user = User.new_signup({}) 
    assert !user.save
    assert_equal "Email can't be blank, Email domain not valid, Email is invalid, Name can't be blank, Password can't be blank, Password confirmation can't be blank", user.errors.full_messages.sort.join(", ")
    # password needs to be confirmed
    user = User.new_signup({:name => "User10", :password => "User10", :email => "User10@epf.eclipse.org"}) #, :i_agree_to_the_terms_of_use => '1'
    assert !user.save
    assert_equal "Password confirmation can't be blank", user.errors.full_messages.join(", ")    
    # password needs to be confirmed 2
    user = User.new_signup({:name => "User10", :password => "User10", :password_confirmation => "xyz", :email => "User10@epf.eclipse.org"})  # , :i_agree_to_the_terms_of_use => '1'
    assert !user.save
    assert_equal "Password doesn't match confirmation", user.errors.full_messages.join(", ")    
    # user created
    user = User.new_signup({:name => "User10", :password => "User10", :password_confirmation => "User10", :email => "User10@epf.eclipse.org"})  # , :i_agree_to_the_terms_of_use => '1'
    assert user.save
    assert_equal "user10@epf.eclipse.org", user.email
    assert_equal nil, user.confirmed_on # account needs to be confirmed
    assert_equal Utils.hash_pw('User10'), user.hashed_password
    assert_equal nil, user.hashed_password_new
    # cannot login, not confirmed
    login_user = user.try_to_login
    assert_equal nil, login_user
    # confirm account
    # assert_equal hash_pw('User10'), user.hashed_password 
    user.confirm_account(Utils.hash_pw(user.hashed_password))  
    assert user.save
    assert_not_nil user.confirmed_on
    # can login
    login_user = user.try_to_login
    assert_not_nil login_user
  end
  
  test "Set new pw" do 
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'C')
    # user created
    user = User.new_signup({:name => "User11", :password => "User11", :password_confirmation => "User11", :email => "User11@epf.eclipse.org"})  # , :i_agree_to_the_terms_of_use => '1'
    assert user.save
    # confirm account
    user.confirm_account(Utils.hash_pw(user.hashed_password))  
    assert user.save
    assert_equal "", user.errors.full_messages.join(", ")    
    user = User.find_by_name('User11')
    assert_not_nil user.confirmed_on
    # can login
    user.password = 'User11'
    login_user = user.try_to_login
    assert_not_nil login_user
    # set new password  
    hashed_password = user.hashed_password
    user.set_new_pw('new_password')
    new_pw = user.password
    assert user.save
    assert_equal "", user.errors.full_messages.join(", ")
    user.reload
    assert_not_nil user.confirmed_on 
    assert_equal Utils.hash_pw(new_pw), user.hashed_password_new
    # we can still sign in with the old password
    user.password = "User11"
    login_user = user.try_to_login
    assert_not_nil login_user
    # we cannot sign in with the new password
    user.password = new_pw
    login_user = user.try_to_login
    assert_equal nil, login_user
    # cannot confirm with the wrong token
    user = User.find_by_name('User11')
    assert_equal false, user.confirm_account("somewrongtoken")
    # confirm the account
    user = User.find_by_name('User11')
    #assert_equal hash_pw(hash_pw(new_pw)), hash_pw(user.hashed_password_new)
    user.confirm_account(Utils.hash_pw(Utils.hash_pw(new_pw)))
    assert_equal Utils.hash_pw(new_pw), user.hashed_password
    user.save
    assert_equal "", user.errors.full_messages.join(", ")
    user = User.find_by_name('User11')
    assert_not_equal hashed_password, user.hashed_password
    assert_equal Utils.hash_pw(new_pw), user.hashed_password
    assert_equal nil, user.hashed_password_new
    assert_not_nil user.confirmed_on
    # we can sign in with the new password
    user.password = new_pw
    login_user = user.try_to_login
    assert_not_nil login_user
  end
  
  test "Updates" do 
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'C')
    user = User.find_by_name('Andy Kaufman')
    user.name = "test04_updates"
    assert user.save
    assert_equal "", user.errors.full_messages.join(", ")
  end
  
  test "Change password" do
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'C')
    @george = Factory(:user, :name => 'George Clifton', :password => 'secret', :admin => 'Y')
    user = User.find_by_name('Andy Kaufman')
    assert_raise(RuntimeError) {user.change_password(User.new)}
    assert_raise(RuntimeError) {user.change_password(User.new(:password =>'', :password_confirmation => ''))}
    user.change_password(User.new(:password =>'xyz', :password_confirmation => '123'))    
    assert !user.save
    assert_equal "Password doesn't match confirmation", user.errors.full_messages.join(", ")
    user.change_password(User.new(:password =>'xyz', :password_confirmation => 'xyz'))    
    assert user.save
    assert_equal '', user.errors.full_messages.join(', ')
    user = User.find_by_name('Andy Kaufman')
    user.password = 'xyz'
    login_user = user.try_to_login
    assert_equal Utils.hash_pw('xyz'), login_user.hashed_password
    assert_not_nil login_user
  end
  
  # Shows:
  # 1 User can logon using basic authentication, first logon -> an account is created
  # 2 Second logon succesfull, account is not created
  # 3 Wrong password cannot logon
  # 4 Failed to save, sends email
  def tst_login_basicauthentication # TODO - magweg/aanpassen
    # get password
    pw = IO.readlines('S:/Keys/epfwiki_basic_authentication_key')[0]
    # 1
    ENV['EPFWIKI_DOMAINS'] = ENV['EPFWIKI_DOMAINS'] + ' @logicacmg.com'
    user_count = User.count
    user = User.new(:account => 'ostraaten', :password => pw)
    logon_user = User.login(user.account, user.password)
    assert_equal user_count + 1, User.count
    # 2
    logon_user = User.login(user.account, user.password)
    assert_not_nil logon_user
    assert_equal user_count + 1, User.count
    # 3
    logon_user = User.login(user.account, user.password + 'xyz')
    assert_nil logon_user
    assert_equal user_count + 1, User.count
    # 4
    User.find_by_account(user.account).destroy
    assert_equal user_count, User.count
    ActiveRecord::Migration::drop_column 'users', 'account'
    assert_equal 0,@emails.size
    logon_user = nil
    logon_user = User.login(user.account, user.password)
    assert_nil logon_user
    assert_equal user_count, User.count
  end
  
  # Shows:
  # 1. Cannot update a user to Y or C without specifying the user
  # 2. Cadmin can upgrade user to admin, downgrade to user, admin kan upgrade user to admin but not downgrade admin to user
  # 3. Cadmin can make another user the cadmin
  # . C -> Y or C -> N not possible
  test "Admin" do 
    cadmin = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'C')
    admin = Factory(:user, :name => 'George Clifton', :password => 'secret', :admin => 'Y')
    user = Factory(:user, :name => 'Tony Clifton', :password => 'secret', :admin => 'N')
    #cadmin = User.find_central_admin # TODO delete
    #user = User.find_all_by_admin('N')[0]
    #admin = User.find_all_by_admin('Y')[0]
    assert_not_nil cadmin
    assert_not_nil user
    assert_not_nil admin
    user.admin = 'Y'
    assert !user.save
    assert_equal 'Admin can only be set by an admin', user.errors.full_messages.join(", ")
    user.admin = 'C'
    assert !user.save
    assert_equal 'Admin can only be set to C by the central admin', user.errors.full_messages.join(", ")
    # 2
    user.admin = 'Y' 
    user.user = cadmin
    assert user.save
    user.admin = 'N' 
    user.user = cadmin
    assert user.save
    user.admin = 'Y' 
    user.user = admin
    assert user.save
    user.admin = 'N' 
    user.user = admin
    assert !user.save
    assert_equal 'Admin can only be revoked by the central admin', user.errors.full_messages.join(", ")    
    user.user = cadmin
    assert user.save
    # 3
    assert cadmin.cadmin?
    User.cadmin(cadmin, user) 
    user.save
    cadmin.save
    assert_equal '', user.errors.full_messages.join(", ")        
    assert_equal '', cadmin.errors.full_messages.join(", ")            
    user.reload
    cadmin.reload
    assert user.cadmin?
    assert !cadmin.cadmin?
    assert_equal 'Y', cadmin.admin
    assert_equal 'C', user.admin
  end

  # Shows:
  # 1 User can logon using bugzilla authentication, on first logon an account is created
  # 2 Second logon succesfull, account is not created
  # 3 Wrong password cannot logon
  # 4 User tries to switch validemail to Bugzilla authentication when using the same email -> TODO
  def tst_login_bugzilla # TODO delete? Use own account, prompt for password
    # get password
    pw = IO.readlines('S:/Keys/epfwiki_bugzilla_authentication_key')[0]
    # 1
    ENV['EPFWIKI_DOMAINS'] = ENV['EPFWIKI_DOMAINS'] + ' @logicacmg.com'
    user_count = User.count
    user = User.new(:email => 'onno.van.der.straaten@logicacmg.com', :password => pw)
    logon_user = User.login(user.email, user.password)
    assert_equal user_count + 1, User.count # TODO fails
    # 2
    logon_user = User.login(user.email, user.password)
    assert_not_nil logon_user
    assert_equal user_count + 1, User.count
    # 3
    logon_user = User.login(user.email, user.password + 'xyz')
    assert_nil logon_user
    assert_equal user_count + 1, User.count
    # 4
  end
  
  # Shows:
  # 1. When the central admin is created, the 'Templates' Wiki is created
  test "New cadmin" do 
    @andy = Factory(:user, :name => 'Andy Kaufman', :password => 'secret', :admin => 'C')
    params = {:name => 'onno', :email => 'Onno@epf.eclipse.org', :password => 'xyz', :password_confirmation => 'xyz'}
    # cannot create cadmin if there are users
    assert_raise(RuntimeError) {cadmin = User.new_cadmin(params)}
   end
 
   test "New cadmin 2" do 
    # params are needed
    cadmin = User.new_cadmin({})
    assert !cadmin.save
    assert_equal "Email can't be blank, Email is invalid, Name can't be blank, Password can't be blank, Password confirmation can't be blank", cadmin.errors.full_messages.sort.join(", ")
    # password needs to be confirmed    
    cadmin = User.new_cadmin(:name => 'onno', :email => 'Onno@epf.eclipse.org', :password => 'xyz', :password_confirmation => '123')
    assert !cadmin.save
    assert_equal "Password doesn't match confirmation", cadmin.errors.full_messages.join(", ")
    # valid email is required
    cadmin = User.new_cadmin(:name => 'onno', :email => 'Onno(at)epf.org', :password => 'xyz', :password_confirmation => 'xyz')
    assert !cadmin.save
    assert_equal "Email is invalid", cadmin.errors.full_messages.join(", ")
    # cadmin is created, note domain restriction does not apply to cadmin account
    cadmin = User.new_cadmin(:id => 5, :name => 'onno', :email => 'Onno@noneExistingDomain.Com', :password => 'xyz', :password_confirmation => 'xyz')
    assert cadmin.save 
    assert_equal 26, Site.templates.size
    # 1
    assert_equal "", cadmin.errors.full_messages.join(", ")
    assert_equal 'onno@noneexistingdomain.com', cadmin.email # email set to downcase
    assert_not_nil cadmin.hashed_password
    assert_equal Utils.hash_pw('xyz'), cadmin.hashed_password # password is hashed and stored
    assert_not_nil cadmin.confirmed_on # account or email does not need to be confirmed
    # TODO: we can update attributes
  end
  
end
