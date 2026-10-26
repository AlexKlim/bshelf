class DecodeKindleTitles < ActiveRecord::Migration[8.1]
  def up
    Book.where("title ~ '&#?[[:alnum:]]+;' OR author ~ '&#?[[:alnum:]]+;'").find_each do |book|
      book.update!(title: CGI.unescapeHTML(book.title), author: book.author && CGI.unescapeHTML(book.author))
    end
  end

  def down; end
end
