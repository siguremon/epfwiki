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

  # To see all available tasks run from app root:
  # rake --tasks 
  namespace :epfw do
    # To update a wikis using a job run from a cron job:
    # rake epfw:update RAILS_ENV=production
    desc "Update EPF Wiki sites"
    task :update => :environment  do
      puts "Running update in #{Rails.env}"
      Site.update
    end # end task update
    
    desc "Send EPF Wiki reports"
    task :reports => :environment do
      puts "Running update in #{Rails.env}"
      puts "EPFWIKI_HOST=#{ENV['EPFWIKI_HOST']}"
      Site.reports
    end 
    
    desc "Remove content in public"
    task :clean do
      ['pages','development_sites','development_wikis','development_diffs',
       'test_diffs','test_sites','test_wikis','wikis',
       'uploads','bp' ].each do |entry|
        FileUtils.rm_rf "public/#{entry}" if File.exists? "public/#{entry}"   
      end
      FileUtils.rm_rf "public/index.html" if File.exists? "public/index.html" # cache file
    end
    
    desc "Install TinyMCE"
    task :tinymce do
      install = false
      unless File.exists? 'tinymce_3.4.4.zip'
        puts `wget https://dl.dropboxusercontent.com/u/30428440/tinymce_3.4.4.zip`
        install = true
      else
        if File.exists? 'public/javascripts/tiny_mce/tiny_mce.js'
          puts "TinyMCE already installed"
        else
          install = true
        end
      end
      if install
        puts `unzip -o tinymce_3.4.4.zip` 
        puts `cp -Rn tinymce/jscripts/* public/javascripts`
        puts `rm -Rf tinymce`
      end
    end 
   
    namespace :bootstrap do
      
      files = [['bootstrap.min.css','public/stylesheets']]
      files << ['bootstrap.min.js','public/javascripts']
      files << ['bootstrap-theme.min.css','public/stylesheets']
      files << ['jquery.ba-bbq.min.js','public/javascripts']
      
      desc "Install Bootstrap"
      task :install do
        scrpt = "wget https://dl.dropboxusercontent.com/u/30428440/bootstrap-302.zip
          mkdir tmp_bootstrap
          mv bootstrap-302.zip tmp_bootstrap
          cd tmp_bootstrap && unzip -o bootstrap-302.zip && chmod a+r *"
        scrpt.split("\n").each do |cmd|
          puts cmd
          puts `#{cmd}` 
        end
        files.each do |file| # check if all files are found
          puts file.first
          raise "File #{file.first} not found!" unless File.exists? "tmp_bootstrap/#{file.first}"
        end
        files.each do |file|
          p = File.join(file.last, file.first)
          if File.exists? p
            puts "#{p} exists. Skipped."
          else
            FileUtils.cp File.join('tmp_bootstrap',file.first), file.last
          end
        end
        `rm -Rf tmp_bootstrap`
      end
      
      desc "Remove Bootstrap"
      task :remove do
        files.each do |file| 
          p = File.join(file.last, file.first)
          if File.exists? p
            FileUtils.rm p 
            puts "#{p} removed"
          else
            puts "#{p} not found!"
          end
        end
   
      end # task remove
      
    end # namespace bootstrap

    desc "Create deployment unit (zip file)"
    task :release do
      ENV['BUILD_ID'] ||= 'BUILD_ID'
      ENV['EPFWIKI_TAG'] ||= 'EPFWIKI_TAG'
      ENV['BUILD_NUMBER'] ||= 'BUILD_NUMBER'
      ENV['BUILD_ID'] = ENV['BUILD_ID'].gsub('-','') # Jenkins creates BUILD_ID as YYYY-MM-DD_hh-mm-ss
      p = "app/views/other/_revision.html.erb"
      build_tag = "#{ENV['EPFWIKI_TAG']}_#{ENV['BUILD_NUMBER']}_#{ENV['BUILD_ID']}"
      File.open('../epfwiki_build_tag.sh', 'w') {|f| f.write("export EPFWIKI_BUILD_TAG=#{build_tag}") }
      File.open(p, 'w') {|f| f.write(build_tag) }
      `zip -rq --exclude=*.svn* ../#{build_tag}.zip .`      
    end
  end # end namespace