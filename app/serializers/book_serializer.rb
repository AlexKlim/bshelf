module BookSerializer
  HIGHLIGHTS_PREVIEW = 5

  def self.summary(book, shelf_key)
    {
      id: book.uuid,
      title: book.title,
      author: book.author,
      original_title: book.original_title,
      language: book.language,
      year: book.year,
      page_count: book.page_count,
      audio_minutes: book.audio_minutes,
      cover_url: book.cover_url,
      cloth: book.cloth || Cloth.for_uuid(book.uuid),
      shelf: shelf_key,
      editions: book.editions.sort_by(&:id).map { edition(it) }
    }
  end

  def self.detail(book, shelf_key)
    highlights = book.highlights.order(:highlighted_at, :id).limit(HIGHLIGHTS_PREVIEW)
    summary(book, shelf_key).merge(
      isbn: book.isbn,
      match_source: book.match_source,
      notes: book.notes.order(:created_at, :id).map { note(it) },
      highlights: highlights.map { highlight(it) },
      highlights_count: book.highlights.count
    )
  end

  def self.edition(edition)
    reading = edition.reading
    {
      id: edition.uuid,
      format: edition.format,
      store: edition.store,
      source: edition.source,
      purchased_at: edition.purchased_at,
      status: reading&.status,
      status_source: reading&.status_source,
      status_updated_at: reading&.updated_at,
      started_at: reading&.started_at,
      finished_at: reading&.finished_at,
      total_minutes: reading&.total_minutes
    }
  end

  def self.note(note) = { id: note.uuid, body: note.body, created_at: note.created_at, updated_at: note.updated_at }

  def self.highlight(highlight)
    highlight.slice(:text, :note, :location, :source, :highlighted_at).merge(id: highlight.uuid)
  end
end
