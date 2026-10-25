module McpTools
  class AddBook < BaseTool
    tool_name "add_book"
    description "Adds a book to the user's shelf. Default status is want (the want-to-read list). " \
      "For a finished book pass status done and format audio (listened) or ebook (read). " \
      "If the book is already on the shelf nothing changes and code is duplicate with the existing book."
    input_schema(
      properties: {
        title: { type: "string" },
        author: { type: "string" },
        status: { type: "string", enum: Reading::STATUSES, default: "want" },
        format: { type: "string", enum: Edition::FORMATS, default: "unknown" },
        finished_at: { type: "string", description: "YYYY-MM-DD, for status done" }
      },
      required: [ "title" ]
    )
    annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: false, open_world_hint: false)

    def self.required_scope = "books:write"

    def self.call(title:, server_context:, author: nil, status: "want", format: "unknown", finished_at: nil)
      user = server_context[:user]
      return fail_with(:inclusion, field: :status) unless Reading::STATUSES.include?(status)
      return fail_with(:inclusion, field: :format) unless Edition::FORMATS.include?(format)

      book = ::AddBook.call(user:, title:, author:, status:, format:, source: "mcp", finished_at:)
      summary = Shelf.new(user).summaries([ book.id ]).first
      respond("Added: #{describe(summary)}", { code: "added", book: summary })
    rescue ReadingDates::Invalid => e
      fail_with(:invalid, field: e.field)
    rescue ::AddBook::Duplicate => e
      existing = Shelf.new(user).summaries([ e.book.id ]).first
      respond("Already on the shelf: #{describe(existing)}", { code: "duplicate", book: existing })
    rescue ActiveRecord::RecordInvalid => e
      error = e.record.errors.first
      fail_with(error.type, field: error.attribute)
    end
  end
end
