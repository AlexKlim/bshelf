module McpTools
  class SearchShelf < BaseTool
    tool_name "search_shelf"
    description "Answers \"have I read or listened to X?\". Searches the user's shelf by title, author, " \
      "original title, ISBN or store id. answer.kind is one of listened, read, read_and_listened, " \
      "in_progress, owned, want, similar (several matches, see books), not_found."
    input_schema(properties: { query: { type: "string", description: "Title, author, ISBN or store id" } },
      required: [ "query" ])
    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

    def self.call(query:, server_context:)
      return fail_with(:blank, field: :query) if query.to_s.strip.empty?

      result = ShelfSearch.new(server_context[:user], query).call
      lines = [ "answer: #{result[:answer][:kind]}", *result[:books].map { describe(it) } ]
      respond(lines.join("\n"), result)
    end
  end
end
