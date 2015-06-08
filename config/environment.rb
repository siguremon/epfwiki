# force Rails into production mode when                          
# you don't control web/app server and can't set it the proper way                  
# TODO ENV['RAILS_ENV'] ||= 'production'

# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
EPFWikiRails3::Application.initialize!



