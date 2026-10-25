class BackfillIsbnSource < ActiveRecord::Migration[8.1]
  def change
    up_only { execute "UPDATE books SET isbn_source = 'catalog' WHERE isbn IS NOT NULL AND isbn_source IS NULL" }
  end
end
