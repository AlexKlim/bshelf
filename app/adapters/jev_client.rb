class JevClient
  ENDPOINT = URI("https://openrouter.ai/api/alpha/decisions")
  MODEL = "~typesafe/jev-latest".freeze
  SAME_BOOK = {
    type: "noul",
    instructions: "These are two books from one reader's shelf. Translate both titles into the same language. " \
      "Is book B the original or a translation of book A, so that both name the same book? A shared author is not enough.",
    criteria: {
      true: "Book B's title means the same as book A's title, it is one book",
      false: "The titles mean different things, they are two books by the same or different authors"
    }
  }.freeze

  class Error < StandardError; end

  def self.configured? = ENV["OPENROUTER_API_KEY"].present?

  def same_book(a, b)
    describe = ->(label, book) { "Book #{label}, a book: «#{book.title}», #{book.author}" }
    body = { model: MODEL, state: [ describe.("A", a), describe.("B", b) ], questions: { same_book: SAME_BOOK } }
    res = Net::HTTP.post(ENDPOINT, body.to_json, "Authorization" => "Bearer #{ENV.fetch("OPENROUTER_API_KEY")}",
      "Content-Type" => "application/json")
    raise Error, "openrouter answered #{res.code}" unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body).dig("answers", "same_book", "noul")
  rescue Timeout::Error, SocketError, SystemCallError, JSON::ParserError => e
    raise Error, e.class.name
  end
end
