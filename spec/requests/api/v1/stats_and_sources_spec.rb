require "rails_helper"

RSpec.describe "Stats and sources" do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  describe "GET /api/v1/stats" do
    def done(title, author, format, finished_at)
      create(:book, user:, title:, author:, format:, status: "done", finished_at: finished_at && Time.zone.parse(finished_at))
    end

    it "counts finished books per month and format, once per book" do
      both = done("Dune", "Herbert", "audio", "2025-03-10")
      create(:reading, edition: create(:edition, book: both, format: "ebook"), status: "done",
        status_source: "manual", finished_at: Time.zone.parse("2025-05-02"))
      done("Solaris", "Lem", "ebook", "2025-05-20")
      done("Eden", "Lem", "audio", "2024-01-01")
      done("Undated", "Lem", "audio", nil)
      create(:book, user:, title: "Bought", status: "owned")
      create(:book, status: "done", finished_at: Time.zone.parse("2025-05-01"))

      get "/api/v1/stats", params: { year: 2025 }

      expect(response).to have_http_status(:ok)
      expect(json).to include("year" => 2025, "years" => [ 2025, 2024 ], "total" => 2, "no_date_count" => 1,
        "by_format" => { "audio" => 1, "ebook" => 2 })
      may = json["months"].find { it["month"] == 5 }["books"]
      expect(may.map { it["title"] }).to eq(%w[Dune Solaris])
      expect(may.first).to include("id" => both.uuid, "formats" => %w[audio ebook])
      expect(json["months"].size).to eq(12)
      expect(json["top_authors"]).to eq([ { "author" => "Herbert", "count" => 1 }, { "author" => "Lem", "count" => 1 } ])
    end

    it "handles a year without finished books" do
      get "/api/v1/stats", params: { year: 2001 }

      expect(json).to include("total" => 0, "by_format" => {}, "top_authors" => [], "total_minutes" => nil)
    end
  end

  describe "GET /api/v1/sources" do
    it "lists every source kind with its last sync state" do
      user.source_connections.create!(kind: "litres", status: "error", error: "needs_login",
        last_sync_at: Time.zone.parse("2026-10-01"))
      create(:user).source_connections.create!(kind: "kindle_export", status: "ok")

      get "/api/v1/sources"

      expect(json["sources"]).to eq([
        { "kind" => "litres", "status" => "error", "last_sync_at" => "2026-10-01T00:00:00.000Z", "error" => "needs_login",
          "books_count" => 0, "session" => nil },
        { "kind" => "kindle_export", "status" => "never", "last_sync_at" => nil, "error" => nil,
          "books_count" => 0, "session" => nil },
        { "kind" => "kindle_browser", "status" => "never", "last_sync_at" => nil, "error" => nil,
          "books_count" => 0, "session" => nil }
      ])
    end

    it "counts books per source and shows the latest browser session" do
      create(:edition, book: create(:book, user:), source: "kindle_browser")
      old = live_session(user)
      old.finish!(interruption: "aborted")
      running = RemoteBrowserSession.start!(user, "kindle")

      get "/api/v1/sources"

      kindle = json["sources"].find { it["kind"] == "kindle_browser" }
      expect(kindle).to include("books_count" => 1)
      expect(kindle["session"]).to eq("id" => running.uuid, "status" => "connecting", "result" => nil, "interruption" => nil)
    end

    describe "banner" do
      it "is empty when nothing waits for the person" do
        get "/api/v1/sources"

        expect(json["banner"]).to be_nil
      end

      it "shows a source error before the Litres reminder and keeps it undismissable" do
        user.source_connections.create!(kind: "litres", status: "ok", last_sync_at: 40.days.ago)
        row = user.source_connections.create!(kind: "kindle_browser", status: "error", error: "provider_refused")

        get "/api/v1/sources"

        expect(json["banner"]).to eq("kind" => "source_error", "source" => "kindle_browser", "error" => "provider_refused",
          "dismissible" => false, "key" => "source_error:kindle_browser:#{row.updated_at.to_i}")
      end

      it "reminds to sign in to Litres a month after the last sync" do
        synced = user.source_connections.create!(kind: "litres", status: "ok", last_sync_at: 31.days.ago)

        get "/api/v1/sources"

        expect(json["banner"]).to eq("kind" => "litres_reminder", "dismissible" => true,
          "key" => "litres_reminder:#{synced.last_sync_at.to_i}")
      end

      it "shows open possible duplicates last, keyed by the newest so a dismissed banner returns on a new pair" do
        books = Array.new(3) { |i| user.books.create!(title: "Солярис #{i}") }
        DuplicateCandidate.record!(books[0], books[1], reason: "title")
        DuplicateCandidate.record!(books[0], books[2], reason: "title", dismissed_at: Time.current)
        newest = DuplicateCandidate.record!(books[1], books[2], reason: "title")

        get "/api/v1/sources"

        expect(json["banner"]).to eq("kind" => "possible_duplicates", "count" => 2, "dismissible" => true,
          "key" => "possible_duplicates:#{newest.id}")
      end

      it "shows needs_login as a source error" do
        user.source_connections.create!(kind: "litres", status: "needs_login")

        get "/api/v1/sources"

        expect(json["banner"]).to include("kind" => "source_error", "error" => "needs_login")
      end
    end
  end
end
