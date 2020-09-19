class RenameFeaturedPositions < ActiveRecord::Migration[6.0]
  def change
    rename_column :journeys, :featured_position, :position
    rename_column :pg_search_documents, :position, :featured_position
  end
end
