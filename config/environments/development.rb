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

  ENV['EPFWIKI_APP_NAME'] = "EPF Wiki - Development Environment"
  ENV['EPFWIKI_PUBLIC_FOLDER'] = 'public'
  ENV['EPFWIKI_ROOT_DIR'] = File.expand_path(Rails.root) + '/'
  ENV['EPFWIKI_BASE_URL'] = "http://localhost:3000" # used for jobs, when there is no host variable in the environment
  ENV['EPFWIKI_SITES_FOLDER'] = 'development_sites'
  ENV['EPFWIKI_SITES_PATH'] = ENV['EPFWIKI_ROOT_DIR'] + ENV['EPFWIKI_PUBLIC_FOLDER'] + '/' + ENV['EPFWIKI_SITES_FOLDER']
  ENV['EPFWIKI_WIKIS_FOLDER'] = 'development_wikis'
  ENV['EPFWIKI_WIKIS_PATH'] = ENV['EPFWIKI_ROOT_DIR'] + ENV['EPFWIKI_PUBLIC_FOLDER'] + '/' + ENV['EPFWIKI_WIKIS_FOLDER']
  ENV['EPFWIKI_DIFFS_PATH'] = ENV['EPFWIKI_ROOT_DIR'] + ENV['EPFWIKI_PUBLIC_FOLDER'] + "/#{Rails.env}_diffs/"
  #ENV['EPFWIKI_DOMAINS'] = "@epf.org @openup.org" # specify to restrict valid emails to these domains. Uncomment to allow all.
  
  ENV['EPFWIKI_REPLY_ADDRESS'] = "no-reply@epwiki.net"
  ENV['EPFWIKI_TEMPLATES_DIR'] = "#{ENV['EPFWIKI_ROOT_DIR']}#{ENV['EPFWIKI_PUBLIC_FOLDER']}/templates/"
  
  ENV['EPFWIKI_GOOGLE_CUSTOM_SEARCH'] = 'N' # Google Custom Search example for EPFWiki.net
  
   # authentication methods that can be used to authenticate users
  ENV['EPFWIKI_AUTH_METHODS'] = 'validemail'# valid values, for instance: bugzilla,basic,validemail
  ENV['EPFWIKI_AUTH_BASIC'] = 'home.global.logicacmg.com,401,logicacmg.com'  # host,fail code,domain for creating email
  ENV['EPFWIKI_AUTH_BUGZILLA'] = 'bugs.eclipse.org,443'  # host,port
  ENV['EPFWIKI_USAGE_STATISTICS'] = 'N'
  
  config.per_page = 5
  
  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin
  
  # Turn on Sphinx search
  config.sphinxsearch = true
end

