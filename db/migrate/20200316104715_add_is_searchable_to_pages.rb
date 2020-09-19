class AddIsSearchableToPages < ActiveRecord::Migration[6.0]
  def change
    add_column :pages, :is_searchable, :boolean, default: false, null: false
  end
end
