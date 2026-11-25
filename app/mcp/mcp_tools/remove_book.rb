module McpTools
  class RemoveBook < BaseTool
    tool_name "remove_book"
    description "Removes a book from the user's shelf by id (from search_shelf) with its editions, notes and " \
      "highlights. It cannot be undone, so confirm with the user first. A store copy is remembered, so a sync " \
      "does not bring the book back."
    input_schema(properties: { book_id: { type: "string", description: "Book id (UUID)" } }, required: [ "book_id" ])
    annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: true, open_world_hint: false)

    def self.required_scope = "books:write"

    def self.call(book_id:, server_context:)
      user = server_context[:user]
      book = user.books.find_by(uuid: book_id) if book_id.to_s.match?(UUID)
      return fail_with(:not_found, field: :book_id) unless book

      summary = Shelf.new(user).summaries([ book.id ]).first
      book.discard!
      respond("Removed: #{describe(summary)}", { code: "removed", book: summary })
    end
  end
end
