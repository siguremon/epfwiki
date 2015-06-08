class IpAddressOptional < ActiveRecord::Migration
  def self.up
    change_column :users, :ip_address, :string, :limit => 20, :null => true
  end

  def self.down
    change_column :users, :ip_address, :string, :limit => 20, :default => "", :null => false
  end
end
