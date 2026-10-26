class CatalogBook < ApplicationRecord
  FIELDS = %w[original_title isbn year language page_count].freeze
  COVER = %w[cover_url cloth cloth_color].freeze
  STORE_IDS = { "litres" => :litres_id, "amazon" => :amazon_id }.freeze

  before_validation { self.title_key = TextKey.title(title) }

  def self.for(book)
    by_store = store_ids(book).lazy.filter_map { |column, id| find_by(column => id) }.first
    return by_store if by_store
    return find_by(isbn: book.isbn) if book.isbn.present? && exists?(isbn: book.isbn)

    where(title_key: book.title_key).find { TextKey.authors(book.author, it.author) == :same }
  end

  def self.store_ids(book)
    book.editions.filter_map { |edition| [ STORE_IDS[edition.store], edition.external_id ] if STORE_IDS[edition.store] && edition.external_id }
  end

  def self.remember(book, retried: false)
    entry = self.for(book) || new(title: book.title, author: book.author)
    entry.assign_attributes(book.attributes.slice(*FIELDS, *COVER).compact.select { |field, _| entry[field].blank? })
    store_ids(book).each { |column, id| entry[column] ||= id }
    entry.save!
  rescue ActiveRecord::RecordNotUnique
    remember(book, retried: true) unless retried
  end

  def fill(book)
    FIELDS.each { |field| book[field] = self[field] if book[field].blank? }
    book.isbn_source ||= "catalog" if book.isbn_changed?
    return unless book.cover_url.nil? || book.cover_url == cover_url

    COVER.each { |field| book[field] = self[field] }
  end
end
