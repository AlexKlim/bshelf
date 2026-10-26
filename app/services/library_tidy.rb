class LibraryTidy
  def self.call(user)
    books = user.books
    coverless = books.where(cover_url: nil).where.not(enriched_at: nil)
    coverless.update_all(enriched_at: nil)
    ids = books.where(enriched_at: nil).or(books.where.not(cover_url: nil).where(cloth_color: nil)).ids
    ActiveJob.perform_all_later(ids.map { EnrichBookJob.new(it) })
    ids.size
  end
end
