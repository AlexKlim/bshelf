class AddGenreToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :genre, :string
    add_check_constraint :books, "genre IN ('fiction', 'fantasy', 'crime', 'psychology', 'business', 'science', 'history', 'other')", name: "books_genre"
  end
end
