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
        { "kind" => "litres", "status" => "error", "last_sync_at" => "2026-10-01T00:00:00.000Z", "error" => "needs_login" },
        { "kind" => "kindle_export", "status" => "never", "last_sync_at" => nil, "error" => nil },
        { "kind" => "kindle_browser", "status" => "never", "last_sync_at" => nil, "error" => nil }
      ])
    end
  end
end
