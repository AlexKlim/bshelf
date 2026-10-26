class CleanKindleDocumentTitles < ActiveRecord::Migration[8.1]
  def up
    documents = Book.joins(:editions).where(editions: { store: "amazon", format: "personal_doc" }).distinct
    others = Book.joins(:editions).where.not(editions: { format: "personal_doc" }).select(:id)
    documents.where.not(id: others).find_each do |book|
      placeholder = book.cover_url.present? && book.cover_url.include?("media-amazon") && !book.cover_url.include?("/images/I/")
      book.update!(title: FileTitle.clean(book.title), cover_url: placeholder ? nil : book.cover_url, enriched_at: nil)
    end
  end

  def down; end
end
