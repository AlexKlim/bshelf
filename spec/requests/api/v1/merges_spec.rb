require "rails_helper"

RSpec.describe "Merges, duplicates and editions" do
  let(:user) { create(:user) }
  let(:stranger) { create(:book, status: "want") }
  let!(:audio) { create(:book, user:, title: "Солярис", author: "Станислав Лем", format: "audio", status: "done") }
  let!(:ebook) { create(:book, user:, title: "Solaris", author: "Stanisław Lem", isbn: "9780156027601", status: "want") }

  before { sign_in_as(user) }

  describe "POST /api/v1/books/:id/merge and DELETE /api/v1/merges/:id" do
    it "merges, lists the merge on the book, and unmerges back to two books" do
      post "/api/v1/books/#{audio.uuid}/merge", params: { other_id: ebook.uuid }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json["book"]).to include("id" => audio.uuid, "isbn" => "9780156027601", "shelf" => audio_shelf)
      expect(json["book"]["editions"].map { it["status"] }).to contain_exactly("done", "want")
      expect(json["book"]["merges"]).to eq([ { "id" => json["merge_id"], "title" => "Solaris",
        "author" => "Stanisław Lem", "created_at" => MergeEvent.last.created_at.as_json } ])
      merge_id = json["merge_id"]
      get "/api/v1/books/#{ebook.uuid}"
      expect(response).to have_http_status(:not_found)

      delete "/api/v1/merges/#{merge_id}"

      expect(response).to have_http_status(:ok)
      expect(json["books"].map { it["id"] }).to eq([ audio.uuid, ebook.uuid ])
      expect(json["books"].map { it["editions"].map { |e| e["status"] } }).to eq([ [ "done" ], [ "want" ] ])
      get "/api/v1/books/#{audio.uuid}"
      expect(json["book"]).to include("isbn" => nil, "merges" => [])
    end

    it "answers 409 when the merge was already undone" do
      event = MergeEvent.merge!(audio, ebook)
      event.unmerge!

      delete "/api/v1/merges/#{event.uuid}"

      expect(response).to have_http_status(:conflict)
      expect(error_codes).to eq([ "already_unmerged" ])
    end

    it "rejects merging a book with itself and scopes every id to the caller" do
      post "/api/v1/books/#{audio.uuid}/merge", params: { other_id: audio.uuid }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to eq([ { "code" => "invalid", "field" => "other_id" } ])

      post "/api/v1/books/#{audio.uuid}/merge", params: { other_id: stranger.uuid }, as: :json
      expect(response).to have_http_status(:not_found)
      post "/api/v1/books/#{stranger.uuid}/merge", params: { other_id: audio.uuid }, as: :json
      expect(response).to have_http_status(:not_found)

      foreign = MergeEvent.merge!(stranger, create(:book, user: stranger.user))
      delete "/api/v1/merges/#{foreign.uuid}"
      expect(response).to have_http_status(:not_found)
      expect(Book.where(user: stranger.user).count).to eq(1)
    end
  end

  describe "GET /api/v1/duplicates and DELETE /api/v1/duplicates/:id" do
    let!(:candidate) { DuplicateCandidate.record!(audio, ebook, reason: "title") }

    it "lists open possible duplicates with both books" do
      get "/api/v1/duplicates"

      expect(json["duplicates"]).to match([ hash_including("id" => candidate.uuid, "reason" => "title") ])
      expect(json["duplicates"].first["books"].map { it["id"] }).to eq([ audio.uuid, ebook.uuid ])
    end

    it "dismisses one for good" do
      delete "/api/v1/duplicates/#{candidate.uuid}"
      expect(response).to have_http_status(:no_content)

      get "/api/v1/duplicates"
      expect(json["duplicates"]).to eq([])
      delete "/api/v1/duplicates/#{candidate.uuid}"
      expect(response).to have_http_status(:not_found)
    end

    it "drops the candidate when the pair is merged" do
      post "/api/v1/books/#{audio.uuid}/merge", params: { other_id: ebook.uuid }, as: :json

      get "/api/v1/duplicates"
      expect(json["duplicates"]).to eq([])
    end

    it "hides another user's candidates" do
      foreign = DuplicateCandidate.record!(stranger, create(:book, user: stranger.user), reason: "title")

      get "/api/v1/duplicates"
      expect(json["duplicates"].map { it["id"] }).to eq([ candidate.uuid ])
      delete "/api/v1/duplicates/#{foreign.uuid}"
      expect(response).to have_http_status(:not_found)
    end
  end

  def audio_shelf = Shelf.new(user).key_for(audio)
end
