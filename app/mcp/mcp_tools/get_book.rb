module McpTools
  class GetBook < BaseTool
    tool_name "get_book"
    description "Returns one book from the user's shelf by id (from search_shelf): editions with status and " \
      "dates, notes and the first highlights."
    input_schema(properties: { book_id: { type: "string", description: "Book id (UUID)" } }, required: [ "book_id" ])
    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

    def self.call(book_id:, server_context:)
      user = server_context[:user]
      book = user.books.find_by(uuid: book_id) if book_id.to_s.match?(UUID)
      return fail_with(:not_found, field: :book_id) unless book

      detail = BookSerializer.detail(book, Shelf.new(user).key_for(book))
      respond(describe(detail), { book: detail })
    end
  end
end
