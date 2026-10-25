class AddTitleKeysToBooks < ActiveRecord::Migration[8.1]
  class MigrationBook < ActiveRecord::Base
    self.table_name = "books"
  end

  def up
    add_column :books, :title_key, :string
    add_column :books, :original_title_key, :string
    MigrationBook.reset_column_information
    MigrationBook.find_each do |book|
      book.update_columns(title_key: TextKey.title(book.title), original_title_key: TextKey.title(book.original_title))
    end
    change_column_null :books, :title_key, false
    change_column_null :books, :original_title_key, false
    add_index :books, %i[user_id title_key]
  end

  def down
    remove_column :books, :title_key
    remove_column :books, :original_title_key
  end
end
