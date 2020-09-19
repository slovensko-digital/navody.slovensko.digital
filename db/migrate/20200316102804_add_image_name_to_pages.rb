class AddImageNameToPages < ActiveRecord::Migration[6.0]
  def change
    add_column :pages, :image_name, :string
  end
end
