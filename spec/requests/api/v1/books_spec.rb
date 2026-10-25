require "rails_helper"

RSpec.describe "Books, editions, notes and highlights" do
  let(:user) { create(:user) }
  let(:stranger) { create(:book, status: "want") }

  before { sign_in_as(user) }

  describe "POST /api/v1/books" do
    it "adds a book in any format and status" do
      post "/api/v1/books", params: {
        title: " Solaris ", author: "Stanisław Lem", edition: { format: "audio", status: "done", finished_at: "2024-03-10" }
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json["book"]).to include("title" => "Solaris", "author" => "Stanisław Lem", "shelf" => "2024")
      expect(json["book"]["editions"].first).to include("format" => "audio", "status" => "done",
        "status_source" => "manual", "source" => "manual")
      reading = Book.find_by!(uuid: json["book"]["id"]).readings.first
      expect(reading.status_changes.last).to have_attributes(from_status: nil, to_status: "done")
    end

    it "defaults to want with an unknown format" do
      post "/api/v1/books", params: { title: "Someday" }, as: :json

      expect(json["book"]["shelf"]).to eq("want")
      expect(json["book"]["editions"].first).to include("format" => "unknown", "status" => "want")
    end

    it "returns the existing book on a duplicate" do
      existing = create(:book, user:, title: "Solaris", author: "Lem", format: "audio", status: "done",
        finished_at: Time.zone.parse("2024-03-10"))

      post "/api/v1/books", params: { title: "solaris ", author: "LEM", edition: { status: "want" } }, as: :json

      expect(response).to have_http_status(:conflict)
      expect(json["errors"]).to eq([ { "code" => "duplicate", "field" => "title" } ])
      expect(json["existing"]).to include("id" => existing.uuid, "shelf" => "2024")
      expect(json["existing"]["editions"].first).to include("status" => "done", "format" => "audio")
    end

    it "compares titles and authors the way the matcher does" do
      existing = create(:book, user:, title: "Dune", author: "Frank Herbert")

      post "/api/v1/books", params: { title: "DUNE.", author: "Herbert" }, as: :json

      expect(response).to have_http_status(:conflict)
      expect(json["existing"]["id"]).to eq(existing.uuid)
    end

    it "treats a different author as a different book" do
      create(:book, user:, title: "Solaris", author: "Lem", status: "done")

      post "/api/v1/books", params: { title: "Solaris", author: "Someone Else" }, as: :json

      expect(response).to have_http_status(:created)
    end

    it "returns field codes for invalid input" do
      post "/api/v1/books", params: { title: "X", edition: { format: "vinyl" } }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to eq([ { "field" => "format", "code" => "inclusion" } ])

      post "/api/v1/books", params: { title: "Y", edition: { status: "abandoned" } }, as: :json
      expect(json["errors"]).to eq([ { "field" => "status", "code" => "inclusion" } ])

      post "/api/v1/books", params: { author: "Z" }, as: :json
      expect(response).to have_http_status(:bad_request)
      expect(json["errors"]).to eq([ { "code" => "blank", "field" => "title" } ])
    end

    it "rejects a finish date it cannot read instead of dropping it" do
      post "/api/v1/books", params: { title: "X", edition: { status: "done", finished_at: "someday" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to eq([ { "code" => "invalid", "field" => "finished_at" } ])
      expect(user.books).to be_empty
    end

    it "adds a finished book without a date to no date" do
      post "/api/v1/books", params: { title: "Long ago", edition: { status: "done" } }, as: :json

      expect(json["book"]["shelf"]).to eq("no_date")
    end
  end

  describe "GET/PATCH/DELETE /api/v1/books/:id" do
    let(:book) { create(:book, user:, title: "Dune", status: "in_progress") }

    it "shows the book with notes and the first five highlights" do
      create(:note, book:, body: "Spice")
      7.times { create(:highlight, book:) }

      get "/api/v1/books/#{book.uuid}"

      expect(json["book"]).to include("id" => book.uuid, "shelf" => "now", "highlights_count" => 7)
      expect(json["book"]["highlights"].size).to eq(5)
      expect(json["book"]["notes"].map { it["body"] }).to eq([ "Spice" ])
    end

    it "updates title fields" do
      patch "/api/v1/books/#{book.uuid}", params: { title: "Dune (1965)", author: "Frank Herbert" }, as: :json

      expect(json["book"]).to include("title" => "Dune (1965)", "author" => "Frank Herbert")
      patch "/api/v1/books/#{book.uuid}", params: { title: "" }, as: :json
      expect(json["errors"]).to eq([ { "field" => "title", "code" => "blank" } ])
    end

    it "deletes the book with its editions" do
      delete "/api/v1/books/#{book.uuid}"

      expect(response).to have_http_status(:no_content)
      expect(Edition.where(book_id: book.id)).to be_empty
    end

    it "returns 404 for another user's book on every action" do
      get "/api/v1/books/#{stranger.uuid}"
      expect(response).to have_http_status(:not_found)
      patch "/api/v1/books/#{stranger.uuid}", params: { title: "Mine now" }, as: :json
      expect(response).to have_http_status(:not_found)
      delete "/api/v1/books/#{stranger.uuid}"
      expect(response).to have_http_status(:not_found)
      expect(stranger.reload.title).not_to eq("Mine now")
    end
  end

  describe "PATCH /api/v1/editions/:id" do
    let(:book) { create(:book, user:, status: "in_progress", status_source: "kindle_export") }
    let(:edition) { book.editions.first }

    it "sets a manual status and dates and moves the book to its shelf" do
      patch "/api/v1/editions/#{edition.uuid}", params: { status: "done", finished_at: "2025-06-01" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json["book"]["shelf"]).to eq("2025")
      expect(json["book"]["editions"].first).to include("status" => "done", "status_source" => "manual")
    end

    it "clears a date with an empty value" do
      edition.reading.update!(finished_at: 1.day.ago, status: "done")

      patch "/api/v1/editions/#{edition.uuid}", params: { status: "done", finished_at: "" }, as: :json

      expect(json["book"]["shelf"]).to eq("no_date")
    end

    it "rejects a date that is not a real date in range and keeps the stored one" do
      edition.reading.update!(started_at: Time.zone.parse("2025-03-01"))

      [ "someday", "2025-13-45", "0002-01-01", "3025-01-01" ].each do |value|
        patch "/api/v1/editions/#{edition.uuid}", params: { status: "in_progress", started_at: value }, as: :json

        expect(response).to have_http_status(:unprocessable_content), value
        expect(json["errors"]).to eq([ { "code" => "invalid", "field" => "started_at" } ])
      end
      expect(edition.reading.reload.started_at).to eq(Time.zone.parse("2025-03-01"))
    end

    it "accepts dates up to tomorrow and rejects later ones" do
      freeze_time

      %w[started_at finished_at].each do |field|
        patch "/api/v1/editions/#{edition.uuid}", params: { :status => "done", field => Date.tomorrow.iso8601 }, as: :json
        expect(response).to have_http_status(:ok), field

        patch "/api/v1/editions/#{edition.uuid}", params: { :status => "done", field => (Date.current + 2).iso8601 },
          as: :json
        expect(response).to have_http_status(:unprocessable_content), field
        expect(json["errors"]).to eq([ { "code" => "invalid", "field" => field } ])
      end
    end

    it "dates a book marked finished now when it has no finish date yet" do
      freeze_time

      patch "/api/v1/editions/#{edition.uuid}", params: { status: "done" }, as: :json

      expect(json["book"]["shelf"]).to eq(Date.current.year.to_s)
      expect(edition.reading.reload.finished_at).to eq(Time.current)
    end

    it "dates the start when a wanted book moves to reading" do
      edition.reading.update!(status: "want", status_source: "manual")
      freeze_time

      patch "/api/v1/editions/#{edition.uuid}", params: { status: "in_progress" }, as: :json

      expect(edition.reading.reload.started_at).to eq(Time.current)
    end

    it "keeps a stored finish date when the book is marked finished again" do
      edition.reading.update!(finished_at: Time.zone.parse("2023-05-01"))

      patch "/api/v1/editions/#{edition.uuid}", params: { status: "done" }, as: :json

      expect(json["book"]["shelf"]).to eq("2023")
    end

    it "rejects an unknown status" do
      patch "/api/v1/editions/#{edition.uuid}", params: { status: "abandoned" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to eq([ { "code" => "inclusion", "field" => "status" } ])
    end

    it "returns 404 for another user's edition" do
      patch "/api/v1/editions/#{stranger.editions.first.uuid}", params: { status: "done" }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(stranger.readings.first.reload.status).to eq("want")
    end
  end

  describe "notes" do
    let(:book) { create(:book, user:, status: "want") }

    it "creates, lists, updates and deletes notes" do
      post "/api/v1/books/#{book.uuid}/notes", params: { body: "First" }, as: :json
      expect(response).to have_http_status(:created)
      id = json["note"]["id"]

      patch "/api/v1/notes/#{id}", params: { body: "Edited" }, as: :json
      expect(json["note"]["body"]).to eq("Edited")

      get "/api/v1/books/#{book.uuid}/notes"
      expect(json["notes"].map { it["body"] }).to eq([ "Edited" ])

      delete "/api/v1/notes/#{id}"
      expect(response).to have_http_status(:no_content)
      expect(book.notes).to be_empty
    end

    it "rejects an empty body" do
      post "/api/v1/books/#{book.uuid}/notes", params: { body: "" }, as: :json
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 404 for another user's book or note" do
      foreign = create(:note, book: stranger)

      post "/api/v1/books/#{stranger.uuid}/notes", params: { body: "x" }, as: :json
      expect(response).to have_http_status(:not_found)
      get "/api/v1/books/#{stranger.uuid}/notes"
      expect(response).to have_http_status(:not_found)
      patch "/api/v1/notes/#{foreign.uuid}", params: { body: "x" }, as: :json
      expect(response).to have_http_status(:not_found)
      delete "/api/v1/notes/#{foreign.uuid}"
      expect(response).to have_http_status(:not_found)
      expect(foreign.reload.body).to eq("A thought")
    end
  end

  describe "GET /api/v1/books/:id/highlights" do
    it "pages highlights with a total count" do
      book = create(:book, user:)
      7.times { |i| create(:highlight, book:, highlighted_at: i.days.ago) }

      get "/api/v1/books/#{book.uuid}/highlights", params: { offset: 5 }

      expect(json["count"]).to eq(7)
      expect(json["highlights"].size).to eq(2)
      expect(json["highlights"].first.keys).to contain_exactly("id", "text", "note", "location", "source", "highlighted_at")
    end

    it "returns 404 for another user's book" do
      get "/api/v1/books/#{stranger.uuid}/highlights"
      expect(response).to have_http_status(:not_found)
    end
  end
end
