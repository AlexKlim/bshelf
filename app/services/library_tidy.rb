class LibraryTidy
  def self.call(user)
    books = user.books
    coverless = books.where(cover_url: nil).where.not(enriched_at: nil)
    coverless.update_all(enriched_at: nil)
    books.where(id: books.pluck(:id, :title).filter_map { |id, title| id if FileTitle.parse(title) }).update_all(enriched_at: nil)
    ids = books.where(enriched_at: nil).or(books.where.not(cover_url: nil).where(cloth_color: nil)).ids
    ActiveJob.perform_all_later(ids.map { EnrichBookJob.new(it) })
    if JevClient.configured?
      FindTranslationsJob.perform_later(user.id)
      BookGenresJob.perform_later(user.id)
    end
    { queued: ids.size, duplicates: JevClient.configured? }
  end
end
