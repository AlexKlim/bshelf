class CreateCatalogBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_books do |t|
      t.string :title, null: false
      t.string :title_key, null: false
      t.string :author
      t.string :original_title
      t.string :isbn
      t.integer :year
      t.string :language
      t.integer :page_count
      t.string :cover_url
      t.string :cloth
      t.string :cloth_color
      t.string :litres_id
      t.string :amazon_id
      t.timestamps
    end
    add_index :catalog_books, :litres_id, unique: true, where: "litres_id IS NOT NULL"
    add_index :catalog_books, :amazon_id, unique: true, where: "amazon_id IS NOT NULL"
    add_index :catalog_books, :isbn
    add_index :catalog_books, :title_key
  end
end
