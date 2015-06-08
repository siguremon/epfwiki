class SphinxChanges < ActiveRecord::Migration
  def self.up # TODO support migration
    create_table :uma_types, :force => true do |t|
      t.column :name, :string, :limit => 100, :null => false 
    end
    add_column :pages, :body_text, :text
    add_column :pages, :uma_type_id, :integer
    remove_column :pages, :uma_type
  end

  def self.down
    remove_column :pages, :body_text
    remove_column :pages, :uma_type_id
    add_column :pages, :uma_type, :string, :limit => 100, :default => "", :null => false 
    drop_table :uma_types
  end
end 
