require "rails_helper"

RSpec.describe "MCP endpoint" do
  let(:user) { create(:user) }
  let(:token) { mcp_token(user) }
  let(:metadata_url) { "#{mcp_resource.sub(%r{/mcp\z}, "")}/.well-known/oauth-protected-resource/mcp" }

  describe "authentication" do
    it "answers 401 with a challenge pointing to the protected resource metadata" do
      mcp_call(nil, "tools/list")

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"])
        .to eq(%(Bearer scope="books:read books:write", resource_metadata="#{metadata_url}"))
    end

    it "rejects an unknown token as invalid_token" do
      mcp_call("nope", "tools/list")

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to include('error="invalid_token"', "resource_metadata=")
    end

    it "rejects a token issued for another resource" do
      mcp_call(mcp_token(user, resource: "https://other.example/mcp"), "tools/list")

      expect(response).to have_http_status(:unauthorized)
      expect(json["error_description"]).to eq("Token was not issued for this resource")
    end

    it "rejects a token without a resource" do
      mcp_call(mcp_token(user, resource: nil), "tools/list")

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects an expired token" do
      raw = token
      Doorkeeper::AccessToken.last.update!(created_at: 2.hours.ago)

      mcp_call(raw, "tools/list")

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects the token once the grant is revoked from the profile" do
      raw = token
      sign_in_as(user)
      delete "/api/v1/assistants/#{claude_app.uuid}"
      expect(response).to have_http_status(:no_content)

      mcp_call(raw, "tools/list")

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to include('error="invalid_token"')
    end

    it "does not accept a REST API token" do
      _record, raw = ApiToken.issue!(user:, name: "Shortcut")

      mcp_call(raw, "tools/list")

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "tools" do
    it "completes the initialize handshake statelessly" do
      mcp_call(token, "initialize", { protocolVersion: "2025-11-25", capabilities: {},
        clientInfo: { name: "Claude", version: "1" } })

      expect(response).to have_http_status(:ok)
      expect(json["result"]).to include("protocolVersion" => "2025-11-25")
      expect(json.dig("result", "serverInfo", "name")).to eq("bshelf")
      expect(response.headers["Mcp-Session-Id"]).to be_nil
    end

    it "answers a tool call in claude.ai's stateless 2026-07-28 shape with typed text content" do
      create(:book, user:, title: "Solaris", status: "done", finished_at: Time.zone.local(2026, 3, 1))
      meta = { "io.modelcontextprotocol/protocolVersion" => "2026-07-28", "io.modelcontextprotocol/clientInfo" => { name: "claude-ai", version: "1" },
        "io.modelcontextprotocol/clientCapabilities" => {} }
      headers = { "Accept" => "application/json, text/event-stream", "Content-Type" => "application/json", "Host" => URI.parse(mcp_resource).host,
        "Authorization" => "Bearer #{token}", "MCP-Protocol-Version" => "2026-07-28", "Mcp-Method" => "tools/call", "Mcp-Name" => "reading_stats" }

      post "/mcp", params: { jsonrpc: "2.0", id: 7, method: "tools/call",
        params: { _meta: meta, name: "reading_stats", arguments: { year: 2026 } } }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json.dig("result", "content")).to eq([ { "type" => "text",
        "text" => "2026: 1 books, listened 0, read 1\nSolaris - Author (ebook, 2026-03-01)" } ])
    end

    it "lists only the tools the token's scopes allow" do
      mcp_call(token, "tools/list")
      expect(json.dig("result", "tools").map { it["name"] })
        .to match_array(%w[search_shelf get_book add_book reading_stats])

      mcp_call(mcp_token(user, scopes: "books:read"), "tools/list")
      expect(json.dig("result", "tools").map { it["name"] }).to match_array(%w[search_shelf get_book reading_stats])
    end

    it "answers have I read X with the same kinds as REST search" do
      book = create(:book, user:, title: "Солярис", author: "Лем", format: "audio", status: "done",
        finished_at: Time.zone.parse("2024-03-10"))

      result = tool_result(token, "search_shelf", query: "солярис")

      expect(result["isError"]).to be(false)
      expect(result.dig("structuredContent", "answer")).to eq("kind" => "listened", "book_id" => book.uuid)
      expect(result.dig("content", 0, "text")).to eq("answer: listened\nСолярис - Лем [audio done 2024-03-10] (id #{book.uuid})")

      result = tool_result(token, "search_shelf", query: "Пикник")
      expect(result.dig("structuredContent", "answer")).to eq("kind" => "not_found")
    end

    it "never finds another user's books" do
      create(:book, title: "Чужая", status: "done")

      result = tool_result(token, "search_shelf", query: "Чужая")

      expect(result.dig("structuredContent", "answer", "kind")).to eq("not_found")
    end

    it "adds a book to Want with source mcp" do
      result = tool_result(token, "add_book", title: "Пикник на обочине", author: "Стругацкие")

      expect(result.dig("structuredContent", "code")).to eq("added")
      book = user.books.sole
      expect(result.dig("structuredContent", "book", "id")).to eq(book.uuid)
      expect(book.editions.sole).to have_attributes(source: "mcp", format: "unknown")
      expect(book.editions.sole.reading).to have_attributes(status: "want", status_source: "manual")
    end

    it "adds a listened book with its finish date" do
      tool_result(token, "add_book", title: "Дюна", status: "done", format: "audio", finished_at: "2025-02-01")

      reading = user.readings.sole
      expect(reading).to have_attributes(status: "done", finished_at: Time.zone.parse("2025-02-01"))
      expect(reading.edition.format).to eq("audio")
    end

    it "reports a duplicate instead of adding it twice" do
      existing = create(:book, user:, title: "Дюна", author: "Герберт", status: "want")

      result = tool_result(token, "add_book", title: "дюна ", author: "Герберт")

      expect(result["isError"]).to be(false)
      expect(result["structuredContent"]).to include("code" => "duplicate")
      expect(result.dig("structuredContent", "book", "id")).to eq(existing.uuid)
      expect(user.books.count).to eq(1)
    end

    it "returns codes for invalid input" do
      result = tool_result(token, "add_book", title: "X", finished_at: "someday")

      expect(result["isError"]).to be(true)
      expect(result.dig("structuredContent", "error")).to eq("code" => "invalid", "field" => "finished_at")
    end

    it "refuses add_book to a read-only token" do
      mcp_call(mcp_token(user, scopes: "books:read"), "tools/call", { name: "add_book", arguments: { title: "X" } })

      expect(json["error"]).to be_present
      expect(user.books.count).to eq(0)
    end

    it "returns a book by id and not_found for another user's id" do
      mine = create(:book, user:, title: "Мой", status: "want")
      foreign = create(:book, title: "Чужой", status: "want")

      expect(tool_result(token, "get_book", book_id: mine.uuid).dig("structuredContent", "book", "title")).to eq("Мой")

      [ foreign.uuid, "not-a-uuid" ].each do |id|
        result = tool_result(token, "get_book", book_id: id)
        expect(result["isError"]).to be(true)
        expect(result.dig("structuredContent", "error")).to eq("code" => "not_found", "field" => "book_id")
      end
    end

    it "counts read and listened books for a year, optionally by author" do
      create(:book, user:, title: "A", author: "Лем", format: "audio", status: "done",
        finished_at: Time.zone.parse("2025-03-01"))
      create(:book, user:, title: "B", author: "Лем", format: "ebook", status: "done",
        finished_at: Time.zone.parse("2025-04-01"))
      create(:book, user:, title: "C", author: "Кинг", format: "ebook", status: "done",
        finished_at: Time.zone.parse("2025-05-01"))
      create(:book, user:, title: "D", author: "Лем", format: "ebook", status: "done",
        finished_at: Time.zone.parse("2024-05-01"))

      result = tool_result(token, "reading_stats", year: 2025)
      expect(result["structuredContent"]).to include("year" => 2025, "total" => 3, "listened" => 1, "read" => 2)
      expect(result.dig("structuredContent", "top_authors").first).to eq("author" => "Лем", "count" => 2)
      expect(result.dig("content", 0, "text")).to eq("2025: 3 books, listened 1, read 2\n" \
        "A - Лем (audio, 2025-03-01)\nB - Лем (ebook, 2025-04-01)\nC - Кинг (ebook, 2025-05-01)")

      result = tool_result(token, "reading_stats", year: 2025, author: "лем")
      expect(result["structuredContent"]).to include("author" => "лем", "total" => 2, "listened" => 1, "read" => 1)
    end
  end
end
