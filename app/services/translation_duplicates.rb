class TranslationDuplicates
  SAME = 0.9
  CHECKS = 30

  def self.call(user, client: JevClient.new) = new(user, client).call

  def initialize(user, client)
    @user = user
    @client = client
  end

  def call
    candidates.first(CHECKS).count do |a, b|
      noul = CatalogEntry.fetch("jev:#{[ a, b ].map { "#{it.title_key}|#{surname(it)}" }.sort.join("~")}") { { "noul" => @client.same_book(a, b) } }["noul"]
      noul.to_f >= SAME && DuplicateCandidate.record!(a, b, reason: "translation")
    end
  end

  private

  def candidates
    books = @user.books.where.not(author: [ nil, "" ]).to_a
    cyrillic, latin = books.partition { it.title.match?(/\p{Cyrillic}/) }
    known = DuplicateCandidate.where(user: @user).pluck(:book_id, :other_book_id).to_set
    cyrillic.product(latin).select do |a, b|
      same_author?(a, b) && !known.include?([ a, b ].map(&:id).sort)
    end
  end

  def same_author?(a, b)
    x, y = surname(a), surname(b)
    x.size > 3 && y.size > 3 && DidYouMean::Levenshtein.distance(x, y) <= 2
  end

  def surname(book) = Translit.words(Translit.to_cyrillic(book.author.split(",").first.to_s)).last.to_s
end
