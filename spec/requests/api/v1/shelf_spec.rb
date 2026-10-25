require "rails_helper"

RSpec.describe "Shelf" do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  def book(title, **attrs) = create(:book, user:, title:, **attrs)

  def book_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 if payload[:sql].include?('FROM "books"') }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end

  it "loads every shelf with the same number of book queries" do
    book("Wanted", status: "want")
    one_shelf = book_queries { get "/api/v1/shelf" }

    book("Going", status: "in_progress")
    book("Bought", status: "owned")
    book("Old", status: "done", finished_at: Time.zone.parse("2024-05-01"))
    book("Undated", status: "done")
    five_shelves = book_queries { get "/api/v1/shelf" }

    expect(json["shelves"].size).to eq(5)
    expect(five_shelves).to eq(one_shelf)
  end

  it "answers a search without loading the found books twice" do
    book("Dune", status: "want")
    book("Dune Messiah", status: "want")

    expect(book_queries { get "/api/v1/search", params: { q: "dune" } }).to eq(2)
    expect(json["books"].size).to eq(1)
  end

  describe "GET /api/v1/shelf" do
    it "groups books into now, want, owned, years descending and no date" do
      book("Listening", format: "audio", status: "in_progress")
      book("Wanted", status: "want")
      book("Bought", status: "owned")
      book("Old", status: "done", finished_at: Time.zone.parse("2024-05-01"))
      book("Recent", status: "done", finished_at: Time.zone.parse("2025-02-01"))
      book("Later", status: "done", finished_at: Time.zone.parse("2025-11-01"))
      book("Undated", status: "done")

      get "/api/v1/shelf"

      expect(response).to have_http_status(:ok)
      shelves = json["shelves"].to_h { [ it["key"], it["books"].map { |b| b["title"] } ] }
      expect(shelves.keys).to eq(%w[now want owned 2025 2024 no_date])
      expect(shelves["2025"]).to eq(%w[Later Recent])
      expect(json["shelves"].find { it["key"] == "2025" }["count"]).to eq(2)
    end

    it "places a book once, using its strongest edition" do
      both = book("Both", format: "audio", status: "done", finished_at: Time.zone.parse("2023-03-01"))
      edition = create(:edition, book: both, format: "ebook")
      create(:reading, edition:, status: "want", status_source: "manual")

      get "/api/v1/shelf"

      expect(json["shelves"].map { it["key"] }).to eq([ "2023" ])
      entry = json["shelves"].first["books"].first
      expect(entry["id"]).to eq(both.uuid)
      expect(entry["editions"].map { it["status"] }).to eq(%w[done want])
    end

    it "limits books per shelf and pages through one shelf" do
      3.times { |i| book("Want #{i}", status: "want") }

      get "/api/v1/shelf", params: { limit: 2 }
      expect(json["shelves"].first).to include("key" => "want", "count" => 3)
      expect(json["shelves"].first["books"].size).to eq(2)

      get "/api/v1/shelf/want", params: { offset: 2, limit: 2 }
      expect(json).to include("key" => "want", "count" => 3)
      expect(json["books"].size).to eq(1)
    end

    it "is empty for a new user and never shows other users' books" do
      create(:book, status: "want")

      get "/api/v1/shelf"

      expect(json["shelves"]).to eq([])
    end

    it "works with an API token" do
      delete "/api/v1/session"
      _token, raw = ApiToken.issue!(user:, name: "Shortcut")
      book("Mine", status: "want")

      get "/api/v1/shelf", headers: bearer(raw)

      expect(json["shelves"].first["books"].first["title"]).to eq("Mine")
    end
  end

  describe "GET /api/v1/search" do
    it "answers listened with the edition dates" do
      found = book("Пикник на обочине", author: "Стругацкие", format: "audio", status: "done",
        finished_at: Time.zone.parse("2024-03-10"))

      get "/api/v1/search", params: { q: "пикник" }

      expect(json["answer"]).to eq("kind" => "listened", "book_id" => found.uuid)
      expect(json["books"].first["editions"].first).to include("format" => "audio", "status" => "done")
    end

    it "answers read and listened when both formats are done" do
      found = book("Dune", format: "audio", status: "done", finished_at: 1.year.ago)
      create(:reading, edition: create(:edition, book: found, format: "ebook"), status: "done", status_source: "manual")

      get "/api/v1/search", params: { q: "dune" }

      expect(json["answer"]["kind"]).to eq("read_and_listened")
    end

    it "answers want, in_progress and owned" do
      book("Wanted", status: "want")
      book("Going", status: "in_progress")
      book("Bought", status: "owned")

      { "wanted" => "want", "going" => "in_progress", "bought" => "owned" }.each do |q, kind|
        get "/api/v1/search", params: { q: }
        expect(json["answer"]["kind"]).to eq(kind)
      end
    end

    it "prefers an exact title among several matches, else reports similar" do
      book("Dune", status: "want")
      book("Dune Messiah", status: "want")
      book("Dune Chronicles", status: "want")

      get "/api/v1/search", params: { q: "Dune" }
      expect(json["answer"]["kind"]).to eq("want")
      expect(json["books"].size).to eq(1)

      get "/api/v1/search", params: { q: "dun" }
      expect(json["answer"]).to eq("kind" => "similar", "count" => 3)
    end

    it "matches by author, ISBN and store id" do
      by_isbn = book("Isbn book", status: "want", author: "Le Guin")
      by_isbn.update!(isbn: "9780441478125")
      create(:edition, book: by_isbn, store: "amazon", external_id: "B000FC1PJI")

      [ "le guin", "9780441478125", "B000FC1PJI" ].each do |q|
        get "/api/v1/search", params: { q: }
        expect(json["answer"]["book_id"]).to eq(by_isbn.uuid)
      end
    end

    it "answers not found without leaking other users' books" do
      create(:book, title: "Secret", status: "done")

      get "/api/v1/search", params: { q: "secret" }

      expect(json).to include("answer" => { "kind" => "not_found" }, "books" => [])
    end

    it "rejects an empty query" do
      get "/api/v1/search", params: { q: "" }

      expect(response).to have_http_status(:bad_request)
      expect(error_codes).to eq([ "blank" ])
    end
  end
end
