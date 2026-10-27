class DiscardKindleUserGuides < ActiveRecord::Migration[8.1]
  def up
    Book.where(author: "Amazon").where("title ILIKE ?", "%kindle%").find_each do |book|
      book.discard! if book.editions.all? { it.store == "amazon" }
    end
  end

  def down; end
end
