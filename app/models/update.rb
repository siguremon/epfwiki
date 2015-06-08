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

class Update < ActiveRecord::Base

  belongs_to :baseline_process, :foreign_key => 'baseline_process_id'
  belongs_to :wiki, :foreign_key => 'wiki_id'
  belongs_to :user
  
  after_create :deliver_notification
  after_destroy :deliver_destroy_notification
  validate :validate_bp_wiki
  
  # TODO validates_presence_of :user, :baseline_process, :wiki

  def self.find_todo
    Update.find(:all, :order => 'created_on ASC', :conditions => ['started_on is null'])
  end
  
  def self.find_done 
    Update.find(:all, :order => 'finished_on ASC', :conditions => ['finished_on is not null'])
  end
  
  def self.find_inprogress
    Update.find(:all, :order => 'finished_on ASC', :conditions => ['started_on is not null and finished_on is null'])
  end
  
  def do_update
    logger.info("Doing update of #{self.wiki.title} with #{self.baseline_process.title}")
    if self.first_update?
      Notifier.site_status(self, "STARTED creating New Wiki #{self.wiki.title} using Baseline Process #{self.baseline_process.title}").deliver
      self.wiki.wikify(self)
      Notifier.site_status(self, "FINISHED creating new Wiki #{self.wiki.title} using Baseline Process #{self.baseline_process.title}").deliver
    else
      Notifier.site_status(self, "STARTED update of Wiki #{self.wiki.title} with Baseline Process #{self.baseline_process.title}").deliver
      self.wiki.update_wiki(self)
      Notifier.site_status(self, "FINISHED update of Wiki #{self.wiki.title} with Baseline Process #{self.baseline_process.title}").deliver
    end
    users = User.find(:all, :conditions => ['notify_immediate=?', 1])
    unless users.empty?
        subject = "Wiki #{self.wiki.title} Updated with Baseline Process #{self.baseline_process.title}"
        introduction = "User #{self.user.name} updated Wiki <a href=\"#{self.wiki.url}\">#{self.wiki.title}</a> with Baseline Process #{self.baseline_process.title}."
        Notifier.notification(users,subject,introduction, nil).deliver 
    end 

   Wiki.expire_all_pages
    
    # Notify contributors of harvested stuff
    contributions = Upload.find(:all, :conditions => ['done=? and review_note_send_on is null', 'Y']) + 
      Comment.find(:all, :conditions => ['done=? and review_note_send_on is null and site_id=?', 'Y', self.wiki.id]) + 
      UserVersion.find(:all, :conditions => ['done=? and review_note_send_on is null and wiki_id=?', 'Y', self.wiki.id])  
    contributions.collect{|rec|rec.user}.uniq.each do |u |
      Notifier.contributions_processed(u, contributions.collect{|rec|rec if rec.user == u}.compact).deliver
    end
  
   contributions.each do |record|
      record.review_note_send_on = Time.now
      record.save!
    end  
    
    self.finished_on = Time.now
    self.save!  
  end


  def first_update?
    self.wiki.updates_done.empty? && wiki.updates_inprogress.empty?
  end

  def validate_bp_wiki
    errors.add(:baseline_process, 'is not a BaselineProcess') if !self.baseline_process_id.nil? && Site.find(baseline_process_id).wiki?
    errors.add(:wiki, 'is not a Wiki') if !self.wiki_id.nil? && Site.find(wiki_id).baseline_process?
  end 

  def deliver_notification
    if first_update?
      Notifier.site_status(self, "SCHEDULED creation new Wiki #{self.wiki.title} using Baseline Process #{self.baseline_process.title}").deliver
    else
      Notifier.site_status(self, "SCHEDULED creation new Wiki #{self.wiki.title} using Baseline Process #{self.baseline_process.title}").deliver
    end
  end

  def deliver_destroy_notification
    Notifier.site_status(self, "CANCELLED update of Wiki #{self.wiki.title} with Baseline Process #{self.baseline_process.title}").deliver    
  end

end
