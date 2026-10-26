class AddShelvedToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :shelved_key, :string
    add_column :books, :shelved_at, :datetime
  end
end
