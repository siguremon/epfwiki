# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 5) do

  create_table "checkouts", :force => true do |t|
    t.integer  "user_id",    :default => 0, :null => false
    t.integer  "site_id"
    t.integer  "page_id"
    t.integer  "version_id", :default => 0, :null => false
    t.datetime "created_on"
    t.datetime "updated_on"
  end

  add_index "checkouts", ["page_id"], :name => "checkouts_page_id_index"
  add_index "checkouts", ["site_id"], :name => "checkouts_site_id_index"
  add_index "checkouts", ["user_id"], :name => "checkouts_user_id_index"
  add_index "checkouts", ["version_id"], :name => "checkouts_version_id_index"

  create_table "da_texts", :force => true do |t|
    t.text     "text"
    t.string   "type",                :limit => 15,                   :null => false
    t.string   "guid",                :limit => 45
    t.string   "ip_address",          :limit => 500
    t.string   "done",                :limit => 1,   :default => "N", :null => false
    t.text     "review_note"
    t.datetime "review_note_send_on"
    t.integer  "user_id"
    t.integer  "page_id"
    t.integer  "site_id"
    t.integer  "version_id"
    t.datetime "created_on"
    t.datetime "updated_on"
    t.integer  "reviewer_id"
    t.string   "email"
  end

  add_index "da_texts", ["guid"], :name => "da_texts_guid_index"
  add_index "da_texts", ["page_id"], :name => "da_texts_page_id_index"
  add_index "da_texts", ["site_id"], :name => "da_texts_site_id_index"
  add_index "da_texts", ["user_id"], :name => "da_texts_user_id_index"
  add_index "da_texts", ["version_id"], :name => "da_texts_version_id_index"

  create_table "notifications", :force => true do |t|
    t.integer  "page_id"
    t.integer  "user_id",                         :default => 0,  :null => false
    t.string   "notification_type", :limit => 50, :default => "", :null => false
    t.datetime "created_on"
    t.datetime "updated_on"
  end

  add_index "notifications", ["page_id"], :name => "notifications_page_id_index"
  add_index "notifications", ["user_id"], :name => "notifications_user_id_index"

  create_table "pages", :force => true do |t|
    t.string   "rel_path",          :limit => 220,  :default => "",     :null => false
    t.string   "presentation_name", :limit => 500,                      :null => false
    t.string   "type",              :limit => 20,                       :null => false
    t.string   "tool",              :limit => 4,    :default => "EPFC", :null => false
    t.string   "status",            :limit => 20,   :default => "New",  :null => false
    t.string   "filename",          :limit => 250,  :default => "",     :null => false
    t.string   "uma_name",          :limit => 250,  :default => "",     :null => false
    t.integer  "site_id"
    t.integer  "user_id"
    t.datetime "created_on"
    t.datetime "updated_on"
    t.string   "body_tag",          :limit => 1000
    t.string   "treebrowser_tag",   :limit => 1000
    t.string   "copyright_tag",     :limit => 1000
    t.text     "text"
    t.text     "head_tag"
    t.text     "body_text"
    t.integer  "uma_type_id"
  end

  add_index "pages", ["rel_path"], :name => "pages_rel_path_index"

  create_table "pages_sites", :id => false, :force => true do |t|
    t.integer  "site_id"
    t.integer  "page_id"
    t.datetime "created_on"
    t.datetime "updated_on"
  end

  add_index "pages_sites", ["site_id", "page_id"], :name => "pages_sites_site_id_index", :unique => true

  create_table "sessions", :force => true do |t|
    t.string   "session_id"
    t.text     "data"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

  create_table "sites", :force => true do |t|
    t.string   "title",                  :limit => 40,  :default => "", :null => false
    t.string   "type",                   :limit => 15,                  :null => false
    t.text     "description"
    t.integer  "baseline_process_id"
    t.datetime "created_on"
    t.datetime "updated_on"
    t.datetime "baseline_updated_on"
    t.integer  "html_files_count"
    t.integer  "wikifiable_files_count"
    t.integer  "user_id"
    t.string   "folder",                 :limit => 200, :default => "", :null => false
    t.datetime "content_scanned_on"
    t.datetime "wikified_on"
    t.datetime "obsolete_on"
    t.integer  "obsolete_by"
    t.datetime "zip_removed_on"
    t.integer  "zip_removed_by"
    t.datetime "content_removed_on"
    t.integer  "content_removed_by"
  end

  add_index "sites", ["baseline_process_id"], :name => "sites_baseline_process_id_index"
  add_index "sites", ["user_id"], :name => "sites_user_id_index"

  create_table "uma_types", :force => true do |t|
    t.string "name", :limit => 100, :null => false
  end

  create_table "updates", :force => true do |t|
    t.integer  "wiki_id",             :null => false
    t.integer  "baseline_process_id", :null => false
    t.integer  "user_id",             :null => false
    t.datetime "started_on"
    t.datetime "finished_on"
    t.datetime "created_on"
    t.datetime "updated_on"
  end

  create_table "uploads", :force => true do |t|
    t.string   "filename"
    t.string   "upload_type",         :limit => 10
    t.string   "done",                :limit => 1,    :default => "N", :null => false
    t.text     "review_note"
    t.datetime "review_note_send_on"
    t.string   "content_type"
    t.text     "description"
    t.integer  "user_id"
    t.integer  "reviewer_id"
    t.integer  "user_id_markdone"
    t.integer  "user_id_marktodo"
    t.string   "rel_path",            :limit => 1000, :default => "",  :null => false
    t.datetime "created_on"
    t.datetime "updated_on"
  end

  create_table "users", :force => true do |t|
    t.string   "email",                    :limit => 250, :default => "",  :null => false
    t.string   "account"
    t.string   "name",                     :limit => 50,  :default => "",  :null => false
    t.text     "page"
    t.string   "ip_address",               :limit => 20,  :default => ""
    t.string   "hashed_password",          :limit => 40
    t.string   "hashed_password_new",      :limit => 40
    t.string   "admin",                    :limit => 1,   :default => "N", :null => false
    t.integer  "notify_daily",             :limit => 1,   :default => 0,   :null => false
    t.integer  "notify_weekly",            :limit => 1,   :default => 0,   :null => false
    t.integer  "notify_monthly",           :limit => 1,   :default => 0,   :null => false
    t.integer  "notify_immediate",         :limit => 1,   :default => 0,   :null => false
    t.integer  "site_id"
    t.datetime "created_on"
    t.datetime "updated_on"
    t.string   "http_user_agent",          :limit => 250
    t.integer  "logon_count",              :limit => 8,   :default => 0
    t.integer  "logon_using_cookie_count", :limit => 8,   :default => 0
    t.datetime "last_logon"
    t.datetime "confirmed_on"
  end

  add_index "users", ["email"], :name => "users_email_index", :unique => true
  add_index "users", ["site_id"], :name => "users_site_id_index"

  create_table "versions", :force => true do |t|
    t.integer  "version"
    t.string   "type",                :limit => 25,                    :null => false
    t.text     "note"
    t.string   "done",                :limit => 1,    :default => "N", :null => false
    t.boolean  "current"
    t.text     "review_note"
    t.datetime "review_note_send_on"
    t.integer  "user_id",                             :default => 0,   :null => false
    t.integer  "page_id"
    t.integer  "wiki_id",                                              :null => false
    t.integer  "baseline_process_id"
    t.integer  "version_id"
    t.integer  "update_id"
    t.datetime "created_on"
    t.datetime "updated_on"
    t.integer  "reviewer_id"
    t.string   "rel_path",            :limit => 1000, :default => "",  :null => false
  end

  add_index "versions", ["baseline_process_id"], :name => "versions_baseline_process_id_index"
  add_index "versions", ["page_id"], :name => "versions_page_id_index"
  add_index "versions", ["reviewer_id"], :name => "versions_reviewer_id_index"
  add_index "versions", ["user_id"], :name => "versions_user_id_index"
  add_index "versions", ["version", "wiki_id", "page_id"], :name => "versions_version_index", :unique => true
  add_index "versions", ["version_id"], :name => "versions_version_id_index"
  add_index "versions", ["wiki_id"], :name => "versions_site_id_index"

end
