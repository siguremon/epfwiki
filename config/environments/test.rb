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

EPFWikiRails3::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  ENV['EPFWIKI_APP_NAME'] = "EPF Wiki - Test Enviroment"
  ENV['EPFWIKI_PUBLIC_FOLDER'] = 'public'
  ENV['EPFWIKI_ROOT_DIR'] = File.expand_path(Rails.root.to_s) + '/'
  ENV['EPFWIKI_BASE_URL'] = "http://localhost:3000" # used for jobs, when there is no host variable in the environment
  ENV['EPFWIKI_SITES_FOLDER'] = 'test_sites'
  ENV['EPFWIKI_SITES_PATH'] = ENV['EPFWIKI_ROOT_DIR'] + ENV['EPFWIKI_PUBLIC_FOLDER'] + '/' + ENV['EPFWIKI_SITES_FOLDER']
  ENV['EPFWIKI_WIKIS_FOLDER'] = 'test_wikis'
  ENV['EPFWIKI_WIKIS_PATH'] = ENV['EPFWIKI_ROOT_DIR'] + ENV['EPFWIKI_PUBLIC_FOLDER'] + '/' + ENV['EPFWIKI_WIKIS_FOLDER']
  ENV['EPFWIKI_DIFFS_PATH'] = ENV['EPFWIKI_ROOT_DIR'] + ENV['EPFWIKI_PUBLIC_FOLDER'] + "/#{Rails.env}_diffs/"
  ENV['EPFWIKI_DOMAINS'] = "@epf.eclipse.org @openup.org" # specify to restrict valid emails to these domains. Uncomment to allow all.
  
  ENV['EPFWIKI_REPLY_ADDRESS'] = "no-reply@epfwiki.org"
  ENV['EPFWIKI_TEMPLATES_DIR'] = "#{ENV['EPFWIKI_ROOT_DIR']}#{ENV['EPFWIKI_PUBLIC_FOLDER']}/templates/"
  
  ENV['EPFWIKI_GOOGLE_CUSTOM_SEARCH'] = 'N' # Google Custom Search example for EPFWiki.net
  
   # authentication methods that can be used to authenticate users
  ENV['EPFWIKI_AUTH_METHODS'] = 'validemail' # valid values, for instance: bugzilla,basic,validemail
  #ENV['EPFWIKI_AUTH_BASIC'] = 'home.global.logicacmg.com,401,logicacmg.com'  # host,fail code,domain for creating email
  ENV['EPFWIKI_AUTH_BUGZILLA'] = 'bugs.eclipse.org,443'  # host,port
  
  ENV['EPFWIKI_USAGE_STATISTICS'] = 'N'
  
  config.per_page = 5
    
  # The test environment is used exclusively to run your application's
  # test suite.  You never need to work with it otherwise.  Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs.  Don't rely on the data there!
  config.cache_classes = true

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment
  config.action_controller.allow_forgery_protection    = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  # config.active_record.schema_format = :sql

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr
  
  # Turn on Sphinx search
  config.sphinxsearch = true
end
