class AddCustomTitleToJourneys < ActiveRecord::Migration[5.2]
  def up
    add_column :journeys, :custom_title, :string, {:default => nil}
  end

  def down
    remove_column :journeys, :custom_title
  end
end
