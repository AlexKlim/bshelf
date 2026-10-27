class KindleDocumentsBecomeBooks < ActiveRecord::Migration[8.1]
  def up
    documents = Edition.where(format: "personal_doc", store: "amazon")
    Book.where(id: documents.select(:book_id)).update_all(enriched_at: nil)
    documents.update_all(format: "ebook")

    placeholder = ->(scope) { scope.where("cover_url LIKE ?", "%amazon%").where.not("cover_url LIKE ?", "%/images/I/%") }
    placeholder.(CatalogBook).update_all(cover_url: nil, cloth: nil, cloth_color: nil)
    placeholder.(Book).find_each { it.update!(cover_url: nil, enriched_at: nil) }
  end

  def down; end
end
