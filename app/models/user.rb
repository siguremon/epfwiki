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

require 'digest/sha1'
require 'net/http'

# require 'net/https'
# TODO disabled this, because this causes some error and we are not using Bugzilla integration
# see http://jira.codehaus.org/browse/JRUBY-986
 
class User < ActiveRecord::Base

    DOMAIN_PATTERN = /@.*/

    has_many :sites
    has_many :checkouts
    has_many :versions
    has_many :user_versions, :class_name => "Version", :conditions => ['baseline_process_id is null']
    has_many :comments
    has_many :notifications
    has_many :uploads
    has_many :versions2review, :class_name => "Version", :foreign_key => "reviewer_id"
    has_many :comments2review, :class_name => "Comment", :foreign_key => "reviewer_id"
    belongs_to :site # default site of user TODO: not used

    after_create :templates
    before_save :downcase_email
    validate :validate_domains
    validate :validate_passwords_cadmin, :on => :create
    validate :validate_pw_admin, :on => :update
    
    validates_confirmation_of :password
    validates_presence_of :name, :email
    validates_uniqueness_of :name, :email
    validates_format_of :email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
    validates_format_of :admin, :with => /Y|N|C/

    attr_accessor :password, :remember_me, :email_extension#, :i_agree_to_the_terms_of_use TODO reactivate this
    
    # Changing account to admin or cadmin requires that 
    # you specify the user that is requesting the change
    attr_accessor :user
    validates_associated :user
    
    # #new_cadmin creates the central adminstrator user
    def self.new_cadmin(params)
      raise 'Already create central admin' if User.count > 0      
      u= User.new(params)
      u.hashed_password = Utils.hash_pw(u.password) if u.password
      u.admin = "C"
      u.confirmed_on = Time.now
      return u
    end

    # #new_signup creates an ordinary user account
    def self.new_signup(params)
      user = User.new(params)
      user.email = user.email + user.email_extension if ENV['EPFWIKI_DOMAINS'] && user.email_extension
      logger.info("Creating account with supplied password for #{user.email}")
      user.hashed_password = Utils.hash_pw(user.password) if user.password
      return user
    end

    # #login searches the user on email and hashed_password and returns it, see also #try_to_login
    def self.login(email, password)
      user = nil
      ENV['EPFWIKI_AUTH_METHODS'].split(',').each do |method|
        logger.info("Doing login of #{email} using method #{method}")
        if method == 'bugzilla' #&& user.nil?
          user = User.login_bugzilla(email, password)
        elsif method == 'validemail' #&& user.nil?
          user = User.login_validemail(email, password)
        elsif method == 'basic' #&& user.nil?
          user = User.login_basicauthentication(email, password)     
        end
        break if !user.nil?
      end
      return user
    end
    
    def self.login_bugzilla(email, password)
      user = nil
      host, port = ENV['EPFWIKI_AUTH_BUGZILLA'].split(',')
      logger.debug("Login using bugzilla with settings: #{host} with port #{port}")
      http = Net::HTTP.new(host, port)

      # avoid console message "peer certificate won't be verified in this SSL session"
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE 

      http.use_ssl = true
      path = '/bugs/index.cgi'

      # POST request -> logging in
      data = "Bugzilla_login=#{email}&Bugzilla_password=#{password}&GoAheadAndLogIn=1"
      logger.debug('data = ' + data)
      headers = {
      'Referer' => "https://#{host}/bugs/index.cgi?GoAheadAndLogIn=",
      'Content-Type' => 'application/x-www-form-urlencoded'
      }

      resp, data = http.post(path, data, headers)
      logger.info('Code = ' + resp.code)
      logger.info('Message = ' + resp.message)
      resp.each {|key, val| logger.info(key + ' = ' + val)}

      if resp['set-cookie'].nil?
        logger.info("Unauthorized (didn't get a cookie)")
      else
          logger.debug("Authorized #{email}/#{password}")
          user = User.find_by_email(email)
          if user
            logger.info("User #{email} has account")
          else
            logger.info("Creating account #{email}")
            user = User.new(:email => email, :name => email.split('@')[0])
            user.set_new_pw
            user.password_confirmation = user.password
            user.hashed_password = Utils.hash_pw(user.password) if user.password
            if user.save
              logger.info("Succesfully created account: #{user.inspect}")
            else
              logger.info("Failed to create account #{user.errors.full_messages.join(", ")}")
              Notifier.email(User.find_central_admin, 
              "[#{ENV['EPFWIKI_APP_NAME']}] Error creating account using bugzilla!",[],
              "#{user.errors.full_messages.join(", ")}").deliver
              user = nil
            end
          end
        end      
      return user
    end
    
    def self.login_basicauthentication(account, password)
      logger.info("Checking un/pw using basic authentication") 
      user = nil
      hostname, fail_code, maildomain = ENV['EPFWIKI_AUTH_BASIC'].split(',')
      logger.debug("BASIC AUTH Settings: #{hostname},#{fail_code},#{maildomain}")
      Net::HTTP.start(hostname) {|http|
        req = Net::HTTP::Get.new('/')
        req.basic_auth account, password
        response = http.request(req)
        logger.debug("response.code: #{response.code.inspect}, fail_code #{fail_code.inspect}")
        if response.code == fail_code
          logger.debug("Unauthorized #{account}/#{password}: #{response.inspect}")
          return nil
        else
          logger.debug("Authorized #{account}/#{password}: #{response.inspect}")
          user = User.find_by_account(account)
          if user
            logger.info("User #{account} has account")
          else
            logger.info("Creating account #{account}")
            user = User.new(:account => account, :email => "#{account}@#{maildomain}", :name => account)
            user.set_new_pw
            user.password_confirmation = user.password
            user.hashed_password = Utils.hash_pw(user.password) if user.password
            if user.save
              logger.info("Succesfully created account: #{user.inspect}")
            else
              logger.info("Failed to create account #{user.errors.full_messages.join(", ")}")
              Notifier.email(User.find_central_admin, 
              "[#{ENV['EPFWIKI_APP_NAME']}] Error creating account using basic authentication!",[],
              "#{user.errors.full_messages.join(", ")}").deliver
              user = nil
            end
            #return User.create() if user.nil
          end
        end      
      }
      return user
    end
    
    def self.login_validemail(email, password)
      logger.info("Checking un/pw of valid email #{email} hash_pw is #{Utils.hash_pw(password)}")
	logger.debug("Password is #{password}")
        hashed_password = Utils.hash_pw(password)
        user = find(:first,  :conditions => ["email = ? and hashed_password = ?", email.downcase, hashed_password])
        return nil if user && (password.nil? ||  user.confirmed_on.nil?)
        return user 
    end
    
    # #confirm_account is used to confirm new accounts or confirm new passwords in case user requested on
    def confirm_account(token)
      logger.debug("Confirming account with token: " + token)
      logger.debug("Hashed password is: " + self.hashed_password)
      logger.debug("Hashed password new is: " + (self.hashed_password_new || '')) 
      if  self.hashed_password && (Utils.hash_pw(self.hashed_password) == token)
          logger.debug('Confirming new account:' + self.inspect) 
          self.confirmed_on = Time.now
          return true
      elsif self.hashed_password_new && (Utils.hash_pw(self.hashed_password_new) == token)
          logger.debug('Confirming a lost password:' + self.inspect) 
          self.confirmed_on = Time.now
          self.hashed_password = self.hashed_password_new
          self.hashed_password_new = nil
          return true
      else
        return false
      end
    end

    # Use #set_new_pw to set and return a new password for a user.
    # Needs to be confirmed using #confirm_account 
    def set_new_pw(new_pw)
        self.password = new_pw
        self.hashed_password_new = Utils.hash_pw(new_pw)
        logger.debug("This is the new password #{new_pw}")        
    end

    # Log in if the name and password (after hashing)
    # match the database, or if the name matches
    # an entry in the database with no password
    def try_to_login
        User.login(self.email.downcase, self.password) 
    end 

    # #change_password changes the password of a User
    def change_password(user)
      raise "Password can't be blank" if user.password.blank?
      self.password = user.password
      self.password_confirmation = user.password_confirmation
      self.hashed_password = Utils.hash_pw(user.password)
      self.confirmed_on = Time.now
    end
    
    def self.cadmin(from, to)
      raise 'From needs to be central admin' if !from.cadmin?
      User.transaction do
        to.admin = 'C'
        to.user = from
        from.admin = 'Y'
        to.save 
        from.save
      end
    end
    
    # Token that can be used to confirm a new account
    def token
      return Utils.hash_pw(self.hashed_password)
    end

    # Token that can be used to confirm a lost password (existing account)
    def token_new
      return Utils.hash_pw(self.hashed_password_new)
    end

    def user?
      return admin == 'N'    
    end
  
    def admin?
        return admin == 'Y' || admin == 'C'
    end

    def cadmin?
        return admin  == 'C'
    end

    def self.find_central_admin
        return  User.find(:first, :conditions => ["admin=?", "C"] )
    end

    def documents_path
        return "users/" + id.to_s + "/docs"
    end

    def images_path
        return  "users/" + id.to_s + "/images"
    end

    # #sites returns Site records where user created versions or comments
    def sites
        return Site.find(:all, :conditions => ['exists (select * from versions where user_id = ? and wiki_id = sites.id) or exists (select * from da_texts where user_id = ? and site_id = sites.id)', id, id])
    end
    
    #def before_validation_on_update
    #end
  
    def validate_domains
      if  ENV['EPFWIKI_DOMAINS']
        valid_domain = !ENV['EPFWIKI_DOMAINS'].split(" ").index(DOMAIN_PATTERN.match(email.downcase).to_s).nil?
        errors.add(:email, "domain not valid") if !valid_domain && !self.cadmin?
      end
    end
    
    def validate_passwords_cadmin
      errors.add(:password, "can't be blank") if password.blank? || hashed_password.blank?
      errors.add(:password_confirmation, "can't be blank") if password_confirmation.blank?
      errors.add("Central admin already exists") if User.count > 0 && admin == 'C'
      # all users have to agree to the terms of use (except the first user)
      # errors.add_to_base("You have to agree to the terms of use") if i_agree_to_the_terms_of_use != "1" && User.count != 0
    end
    
    def validate_pw_admin
      errors.add(:hashed_password, "can't be blank") if hashed_password.blank?
      old_admin = User.find(id).admin
      if admin == 'C' and old_admin != 'C'
        if user.nil? || User.find(user.id).admin != 'C'
          errors.add(:admin, 'can only be set to C by the central admin') 
        end
      end
      if admin == 'Y' and old_admin == 'N'
        errors.add(:admin, 'can only be set by an admin') if user.nil? || user.admin == 'N'
      end
      if admin == 'N' and !old_admin.index(/Y|C/).nil?
        errors.add(:admin, 'can only be revoked by the central admin') if user.nil? || user.admin != 'C'
      end
    end

    def templates
      create_templates if User.count == 1
    end

    def downcase_email
      self.email = self.email.downcase 
    end
          
end
