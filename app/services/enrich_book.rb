# Fills only blank fields, so manual values and covers from a store sync always win over the catalog.
class EnrichBook
  ISBN_CONFIDENCE = 1.0
  TITLE_AUTHOR_CONFIDENCE = 0.9
  TITLE_CONFIDENCE = 0.6

  attr_reader :book, :client

  def self.call(book, client: CatalogClient.new) = new(book, client).call

  def initialize(book, client)
    @book = book
    @client = client
  end

  def call
    rate_limited = lookup unless book.enriched_at
    retry_later = rate_limited && book.cover_url.nil?
    book.cloth ||= cloth
    book.enriched_at ||= Time.current unless retry_later
    book.save!
    raise rate_limited if retry_later
  end

  private

  def lookup
    rate_limited = nil
    CatalogClient::PROVIDERS.each do |provider|
      break if complete?

      match = (book.isbn.present? && pick(client.search(provider, isbn: book.isbn), by_isbn: true)) ||
        pick(client.search(provider, title: book.title, author: book.author), by_isbn: false)
      apply(*match) if match
    rescue CatalogClient::RateLimited => e
      rate_limited = e
    end
    rate_limited
  end

  def complete? = book.cover_url && book.year && book.language && book.page_count

  def pick(candidates, by_isbn:)
    return [ candidates.first, ISBN_CONFIDENCE ] if by_isbn && candidates.any?

    titles = TextKey.titles(book.title, book.original_title)
    candidates.each do |candidate|
      next unless TextKey.titles(candidate["title"]).intersect?(titles)

      case TextKey.authors(book.author, Array(candidate["authors"]).join(" "))
      when :same then return [ candidate, TITLE_AUTHOR_CONFIDENCE ]
      when :unknown then return [ candidate, TITLE_CONFIDENCE ]
      end
    end
    nil
  end

  def apply(candidate, confidence)
    book.cover_url ||= candidate["cover_url"]
    book.year ||= candidate["year"]
    book.language ||= candidate["language"]
    book.page_count ||= candidate["page_count"]
    # ISBN is a confident merge key in BookMatcher, so a title-only hit must not plant one.
    book.isbn ||= candidate["isbn"] if confidence >= TITLE_AUTHOR_CONFIDENCE
    work = candidate["work_title"]
    book.original_title ||= work if confidence == ISBN_CONFIDENCE && TextKey.title(work) != TextKey.title(book.title)
    book.match_source = "catalog"
    book.match_confidence = [ book.match_confidence.to_f, confidence ].max
  end

  def cloth
    bytes = book.cover_url && client.cover(book.cover_url)
    Cloth.from_image(bytes) if bytes
  rescue CatalogClient::Error => e
    Rails.logger.info("cover #{book.uuid}: #{e.message}")
    nil
  end
end
