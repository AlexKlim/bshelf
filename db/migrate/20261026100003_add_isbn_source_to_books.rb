class AddIsbnSourceToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :isbn_source, :string
  end
end
