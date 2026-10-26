class DecodeKindleTitles < ActiveRecord::Migration[8.1]
  def up
    Book.joins(:editions).where(editions: { store: "amazon" }).distinct
      .where("books.title ~ '&#?[[:alnum:]]+;' OR books.author ~ '&#?[[:alnum:]]+;'").find_each do |book|
      title = KindleImport.decode(book.title).strip
      next if title.blank?

      book.update!(title:, author: book.author && KindleImport.decode(book.author))
    end
  end

  def down; end
end
