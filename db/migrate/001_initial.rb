class Initial < ActiveRecord::Migration
  def self.up

    create_table "checkouts", :force => true do |t|
      t.column "user_id", :integer, :limit => 10, :default => 0, :null => false
      t.column "site_id", :integer, :limit => 10
      t.column "page_id", :integer, :limit => 10
      t.column "version_id", :integer, :limit => 10, :default => 0, :null => false
      t.column "created_on", :datetime
      t.column "updated_on", :datetime
    end
    
    add_index "checkouts", ["user_id"], :name => "checkouts_user_id_index"
    add_index "checkouts", ["page_id"], :name => "checkouts_page_id_index"
    add_index "checkouts", ["version_id"], :name => "checkouts_version_id_index"
    add_index "checkouts", ["site_id"], :name => "checkouts_site_id_index"
    
    create_table "da_texts", :force => true do |t|
      t.column "text", :text
      t.column "type", :string, :limit => 15, :null => false
      t.column "guid", :string, :limit => 45
      t.column "ip_address", :string, :limit => 500
      t.column "done", :string, :limit => 1, :default => "N", :null => false
      t.column "review_note", :text
      t.column "review_note_send_on", :datetime
      t.column "user_id", :integer, :limit => 10
      t.column "page_id", :integer, :limit => 10
      t.column "site_id", :integer, :limit => 10
      t.column "version_id", :integer, :limit => 10
      t.column "created_on", :datetime
      t.column "updated_on", :datetime
      t.column "reviewer_id", :integer
      # feedback
      t.column "email", :string
    end
    
    add_index "da_texts", ["page_id"], :name => "da_texts_page_id_index"
    add_index "da_texts", ["site_id"], :name => "da_texts_site_id_index"
    add_index "da_texts", ["user_id"], :name => "da_texts_user_id_index"
    add_index "da_texts", ["version_id"], :name => "da_texts_version_id_index"
    add_index "da_texts", ["guid"], :name => "da_texts_guid_index", :unique => false
    
    
    create_table "notifications", :force => true do |t|
      t.column "page_id", :integer, :limit => 10
      t.column "user_id", :integer, :limit => 10, :default => 0, :null => false
      t.column "notification_type", :string, :limit => 50, :default => "", :null => false
      t.column "created_on", :datetime
      t.column "updated_on", :datetime
    end
    
    add_index "notifications", ["page_id"], :name => "notifications_page_id_index"
    add_index "notifications", ["user_id"], :name => "notifications_user_id_index"
    
    create_table "pages", :force => true do |t|
      t.column "rel_path", :string, :limit => 220, :default => "", :null => false
      t.column "presentation_name", :string, :limit => 500, :null => false
      t.column "type", :string, :limit => 20, :null => false
      t.column "tool", :string, :limit => 4, :null => false, :default => "EPFC"
      t.column "status", :string, :limit => 20, :default => "New", :null => false 
      t.column "uma_type", :string, :limit => 100, :default => "", :null => false 
      t.column "filename", :string, :limit => 250, :default => "", :null => false
      t.column "uma_name", :string, :limit => 250, :default => "", :null => false
      t.column "site_id", :integer, :limit => 10      
      t.column "user_id", :integer, :limit => 10            
      t.column "created_on", :datetime
      t.column "updated_on", :datetime
      t.column "body_tag", :string, :limit => 1000
      t.column "treebrowser_tag", :string, :limit => 1000
      t.column "copyright_tag", :string, :limit => 1000
      t.column "text", :text
      t.column "head_tag", :text
    end
    
    add_index "pages", ["rel_path"], :name => "pages_rel_path_index", :unique => false
    
    # TODO verwijderen
    create_table "pages_sites", :id => false, :force => true do |t|
      t.column "site_id", :integer, :limit => 10
      t.column "page_id", :integer, :limit => 10
      t.column "created_on", :datetime
      t.column "updated_on", :datetime
    end
    
    add_index "pages_sites", ["site_id", "page_id"], :name => "pages_sites_site_id_index", :unique => true
    
    create_table "sites", :force => true do |t|
      t.column "title", :string, :limit => 40, :default => "", :null => false
      t.column "type", :string, :limit => 15, :null => false
      t.column "description", :text
      #t.column "site_type", :string, :limit => 1 # TODO obsolete
      t.column "baseline_process_id", :integer, :limit => 10
      t.column "created_on", :datetime
      t.column "updated_on", :datetime
      t.column 'baseline_updated_on' , :datetime      
      t.column "html_files_count", :integer # TODO obsolete?
      t.column "wikifiable_files_count", :integer # TODO obsolete?
      t.column "user_id", :integer
      t.column "folder", :string, :limit => 200, :default => "", :null => false
      # for type is 'BaselineProcess'
      t.column "content_scanned_on", :datetime
      # for type is 'Wiki'
      t.column "wikified_on", :datetime
      t.column "obsolete_on", :datetime
      t.column "obsolete_by", :integer, :limit => 10
      # the following columns are not used yet but will be in a futher version, see Bug 238009
      t.column "zip_removed_on", :datetime
      t.column "zip_removed_by", :integer, :limit => 10
      t.column "content_removed_on", :datetime
      t.column "content_removed_by", :integer, :limit => 10      
    end
    
    add_index "sites", ["baseline_process_id"], :name => "sites_baseline_process_id_index"
    add_index "sites", ["user_id"], :name => "sites_user_id_index"

    create_table :updates do |t|
      t.column "wiki_id", :integer, :limit => 10, :null => false
      t.column "baseline_process_id", :integer, :limit => 10, :null => false
      t.column "user_id", :integer, :limit => 10, :null => false
      t.column "started_on", :datetime
      t.column "finished_on", :datetime      
      t.column "created_on", :datetime
      t.column "updated_on", :datetime
    end
    
    create_table "users", :force => true do |t|
      t.column "email", :string, :limit => 250, :default => "", :null => false
      t.column 'account', :string # used for basic authentication
      t.column "name", :string, :limit => 50, :default => "", :null => false
      t.column "page", :text 
      t.column "ip_address", :string, :limit => 20, :default => "", :null => false
      t.column "hashed_password", :string, :limit => 40
      t.column "hashed_password_new", :string, :limit => 40
      t.column "admin", :string, :limit => 1, :default => "N", :null => false
      t.column "notify_daily", :integer, :limit => 1, :default => 0, :null => false
      t.column "notify_weekly", :integer, :limit => 1, :default => 0, :null => false
      t.column "notify_monthly", :integer, :limit => 1, :default => 0, :null => false
      t.column "notify_immediate", :integer, :limit => 1, :default => 0, :null => false
      t.column "site_id", :integer, :limit => 10
      t.column "created_on", :datetime
      t.column "updated_on", :datetime
      t.column "http_user_agent", :string, :limit => 250
      t.column "logon_count", :integer, :limit => 5, :default => 0
      t.column "logon_using_cookie_count", :integer, :limit => 5, :default => 0
      t.column "last_logon", :datetime
      t.column "confirmed_on", :datetime
    end
    
    add_index "users", ["email"], :name => "users_email_index", :unique => true
    add_index "users", ["site_id"], :name => "users_site_id_index"
    
    create_table "versions", :force => true do |t|
      t.column "version", :integer, :limit => 4
      t.column "type", :string, :limit => 25, :null => false            
      t.column "note", :text
      t.column "done", :string, :limit => 1, :default => "N", :null => false
      t.column 'current', :boolean      
      t.column "review_note", :text
      t.column "review_note_send_on", :datetime
      t.column "user_id", :integer, :limit => 10, :default => 0, :null => false
      t.column "page_id", :integer, :limit => 10
      t.column "wiki_id", :integer, :limit => 10, :null => false
      t.column "baseline_process_id", :integer, :limit => 10
      t.column "version_id", :integer, :limit => 10
      t.column "update_id", :integer, :limit => 10
      t.column "created_on", :datetime
      t.column "updated_on", :datetime
      t.column "reviewer_id", :integer
      t.column "rel_path", :string, :limit => 1000, :default => "", :null => false
    end
    
    add_index "versions", ["version", "wiki_id", "page_id"], :name => "versions_version_index", :unique => true
    add_index "versions", ["user_id"], :name => "versions_user_id_index"
    add_index "versions", ["page_id"], :name => "versions_page_id_index"
    add_index "versions", ["wiki_id"], :name => "versions_site_id_index"
    add_index "versions", ["baseline_process_id"], :name => "versions_baseline_process_id_index"    
    add_index "versions", ["version_id"], :name => "versions_version_id_index"
    add_index "versions", ["reviewer_id"], :name => "versions_reviewer_id_index"

    create_table :sessions do |t|
      t.column :session_id, :string
      t.column :data, :text
      t.column :updated_at, :datetime
    end

    add_index :sessions, :session_id
    add_index :sessions, :updated_at
    
    create_table :uploads do |t|
      t.column :filename, :string
      t.column :upload_type, :string, :limit => 10 # 'Document'  or 'Image'
      t.column :done, :string, :limit => 1, :default => "N", :null => false
      t.column :review_note, :text
      t.column :review_note_send_on, :datetime
      t.column :content_type, :string
      t.column :description, :text
      t.column :user_id, :integer, :limit => 10
      t.column :reviewer_id, :integer, :limit => 10
      t.column :user_id_markdone, :integer, :limit => 10
      t.column :user_id_marktodo, :integer, :limit => 10
      t.column :rel_path, :string, :limit => 1000, :default => "", :null => false      
      t.column :created_on, :datetime
      t.column :updated_on, :datetime
    end
    
  end
  
  def self.down
    drop_table "checkouts"
    drop_table "comments"
    drop_table "notifications"  
    drop_table "pages"    
    drop_table  "pages_sites"
    drop_table  "sites"
    drop_table  "users"  
    drop_table  "versions"  
    drop_table :sessions  
    drop_table :uploads    
    drop_table :updates    
  end
end
