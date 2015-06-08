class GuidShouldAllowNilValues < ActiveRecord::Migration
  def self.up
    change_column :da_texts, :guid, :string, :limit => 45, :null => true
  end

  def self.down
    change_column :da_texts, :guid, :string, :limit => 45, :null => true
  end
end 
