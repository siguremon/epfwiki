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

# http://railscasts.com/episodes/158-factories-not-fixtures

Factory.define :user do |f|
  f.sequence(:name) { |n| "foo#{n}" }
  f.ip_address "localhost"
  f.password "foobar"
  f.password_confirmation { |u| u.password }
  f.hashed_password {|u| Utils.hash_pw(u.password)}
  f.email { |u| "foo#{u.name.downcase.gsub(' ', '.')}@epf.eclipse.org" }
  f.admin "Y"
  f.confirmed_on Time.now
end

#Factory.define :article do |f|
#  f.name "Foo"
#  f.association :user
#end
