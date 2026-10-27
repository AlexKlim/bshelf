class KindleDocumentsBecomeBooks < ActiveRecord::Migration[8.1]
  def up
    documents = Edition.where(format: "personal_doc")
    Book.where(id: documents.select(:book_id)).update_all(enriched_at: nil)
    documents.update_all(format: "ebook")
    Book.where("cover_url LIKE ?", "%amazon%").where.not("cover_url LIKE ?", "%/images/I/%").find_each do |book|
      book.update!(cover_url: nil, enriched_at: nil)
    end
  end

  def down; end
end
