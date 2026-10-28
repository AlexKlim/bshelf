class BookNamer
  ENDPOINT = URI("https://openrouter.ai/api/v1/chat/completions")
  MODEL = "openai/gpt-5.4-mini".freeze
  PROMPT = <<~TEXT.squish.freeze
    You get a book title, and sometimes an author, taken from an e-book file name. Russian words are often written
    in Latin letters, and numbers or hyphens may be leftovers of the file name. Return JSON {"title": "...", "author": "..."}.
    If the words are Russian, write the title and the author in correct Russian Cyrillic spelling, as the book is
    titled in Russian. Otherwise keep the original language with normal capitalization. Do not translate, do not
    name a different book and keep the meaning of every word. Write the author given name first, in the alphabet
    of the title, so "Gibson Uilyam" becomes "Уильям Гибсон" and "Bardugo Li" becomes "Ли Бардуго". A file name
    may start with the author before the title, move it to the author. Use null when the author is unknown.
  TEXT

  class Error < StandardError; end

  def self.configured? = ENV["OPENROUTER_API_KEY"].present?

  def self.cache_key(title, author) = "namer:#{Digest::SHA256.hexdigest([ MODEL, PROMPT, title, author ].to_json)}"

  def name(title, author)
    body = { model: MODEL, response_format: { type: "json_object" },
             messages: [ { role: "system", content: PROMPT }, { role: "user", content: { title:, author: }.to_json } ] }
    res = Net::HTTP.post(ENDPOINT, body.to_json, "Authorization" => "Bearer #{ENV.fetch("OPENROUTER_API_KEY")}",
      "Content-Type" => "application/json")
    raise Error, "openrouter answered #{res.code}" unless res.is_a?(Net::HTTPSuccess)

    named = JSON.parse(JSON.parse(res.body).dig("choices", 0, "message", "content").to_s)
    raise Error, "openrouter answered without a title" unless named.is_a?(Hash) && named["title"].is_a?(String) && named["title"].strip.size.between?(1, 500)

    author = named["author"].to_s.strip
    { "title" => named["title"].strip, "author" => (author unless author.match?(/\A(null|none|unknown)?\z/i)) }
  rescue Timeout::Error, SocketError, SystemCallError, JSON::ParserError, TypeError => e
    raise Error, e.class.name
  end
end
