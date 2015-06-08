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
  
  def create_oup_version(folder)
    Rails.logger.debug("Creating baseline #{folder}")
    bp = BaselineProcess.new(:folder => folder, :title => folder, :user_id => User.find_central_admin.id)    
    if File.exists?(bp.path)
      Rails.logger.debug('Removing old folder')
      FileUtils.rm_rf(bp.path)
    end
    if !File.exists?(bp.path2zip)
      path = File.expand_path(File.dirname(__FILE__) + "/data/#{bp.folder}.zip")
      FileUtils.makedirs(File.dirname(bp.path2zip))
      Rails.logger.debug("Copying #{path} to #{bp.path2zip}")
      FileUtils.copy(path, bp.path2zip) 
    end
    bp.unzip_upload
    bp.save!
    bp.scan4content
    return bp
  end
  
  def create_oup_20060721
    return create_oup_version('oup_20060721')
  end
  
  def create_oup_20060728
    return create_oup_version('oup_20060728')
  end
  
  def create_oup_20060825
    return create_oup_version('oup_20060825')
  end
  
  def create_oup_wiki(baseline = create_oup_20060721, folder = 'openup')
    Rails.logger.debug('Creating OpenUP wiki')
    cadmin = User.find_central_admin
    wiki = Wiki.new(:folder => folder, :title => 'OpenUP Wiki', :user_id => cadmin.id) # , :baseline_process_id => baseline.id TODO cleanup
    if File.exists?(wiki.path)
      Rails.logger.debug('Removing old folder')
      FileUtils.rm_r(wiki.path)
    end
    FileUtils.makedirs(File.dirname(wiki.path))
    wiki.save!
    update = Update.create(:wiki_id => wiki.id, :baseline_process_id => baseline.id, :user_id => cadmin.id)
    #wiki.wikify
    #wiki.save!
    update.do_update
    return wiki
  end
