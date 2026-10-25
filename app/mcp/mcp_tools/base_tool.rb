module McpTools
  class BaseTool < MCP::Tool
    UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

    class << self
      def required_scope = "books:read"

      def respond(summary, data, error: false)
        MCP::Tool::Response.new([ MCP::Content::Text.new(summary) ], structured_content: data.as_json, error:)
      end

      def fail_with(code, field: nil, **extra)
        respond("Error: #{[ code, field ].compact.join(" ")}", { error: { code:, field: }.compact, **extra }, error: true)
      end

      def describe(book)
        editions = book[:editions].filter_map do |edition|
          next unless edition[:status]

          [ edition[:format], edition[:status], edition[:finished_at]&.to_date ].compact.join(" ")
        end
        "#{book[:title]}#{" - #{book[:author]}" if book[:author]} [#{editions.join("; ")}] (id #{book[:id]})"
      end
    end
  end
end
