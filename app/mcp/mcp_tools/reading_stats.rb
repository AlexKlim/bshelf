module McpTools
  class ReadingStats < BaseTool
    tool_name "reading_stats"
    description "Lists the books finished in a year with their authors, formats and finish dates, and counts them: " \
      "total, listened (audio), read (any other format), top authors. Use it for \"what did I read in 2026\". " \
      "Pass author to keep only that author's books. A book with both formats counts in both."
    input_schema(properties: {
      year: { type: "integer", description: "Defaults to the current year" },
      author: { type: "string", description: "Substring of the author name" }
    })
    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

    def self.call(server_context:, year: nil, author: nil)
      stats = YearStats.new(server_context[:user], (year || Date.current.year).to_i).call
      books = stats[:months].flat_map { it[:books] }
      books = books.select { it[:author].to_s.downcase.include?(author.downcase) } if author.present?
      data = {
        year: stats[:year], author: author.presence, total: books.size, **YearStats.counts(books),
        top_authors: stats[:top_authors], years: stats[:years],
        books: books.map { it.slice(:id, :title, :author, :formats, :finished_at) }
      }.compact
      summary = [ "#{data[:year]}#{" #{author}" if author.present?}: #{data[:total]} books, " \
        "listened #{data[:listened]}, read #{data[:read]}", *books.map { finished(it) } ].join("\n")
      respond(summary, data)
    end

    def self.finished(book)
      "#{book[:title]}#{" - #{book[:author]}" if book[:author]} (#{book[:formats].join(", ")}, #{book[:finished_at]&.to_date})"
    end
  end
end
