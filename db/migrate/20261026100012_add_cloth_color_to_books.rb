class AddClothColorToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :cloth_color, :string
  end
end
