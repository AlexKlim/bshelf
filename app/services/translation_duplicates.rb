class TranslationDuplicates
  SAME = 0.9
  CHECKS = 30

  def self.call(user, client: JevClient.new) = new(user, client).call

  def initialize(user, client)
    @user = user
    @client = client
  end

  def call
    answers = CatalogEntry.where(key: candidates.map { key(*it) }).pluck(:key, :data).to_h
    candidates.reject { answers.key?(key(*it)) }.first(CHECKS).each do |a, b|
      answers[key(a, b)] = CatalogEntry.fetch(key(a, b)) { { "noul" => @client.same_book(a, b) } }
    end
    candidates.count { |a, b| answers[key(a, b)].to_h["noul"].to_f >= SAME && DuplicateCandidate.record!(a, b, reason: "translation") }
  end

  private

  def candidates
    @candidates ||= pairs
  end

  def pairs
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

  def key(a, b) = JevClient.cache_key(a, b)

  def surname(book) = Translit.words(Translit.to_cyrillic(book.author.split(",").first.to_s)).last.to_s
end
