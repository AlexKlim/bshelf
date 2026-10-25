class AddCatalogEnrichment < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_entries do |t|
      t.string :key, null: false, index: { unique: true }
      t.jsonb :data, null: false, default: []
      t.timestamps
    end

    add_column :books, :cloth, :string
    add_column :books, :enriched_at, :datetime
  end
end
