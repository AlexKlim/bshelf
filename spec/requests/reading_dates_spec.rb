require "rails_helper"

RSpec.describe "Reading dates of a type other than a string" do
  let(:user) { create(:user) }
  let(:invalid) { [ { "code" => "invalid", "field" => "finished_at" } ] }

  [ 20240310, true, false, [ "2024-03-10" ], [], { "date" => "2024-03-10" } ].each do |value|
    context "with #{value.inspect}" do
      it "answers 422 to POST /books" do
        sign_in_as(user)

        post "/api/v1/books", params: { title: "X", edition: { status: "done", finished_at: value } }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json["errors"]).to eq(invalid)
        expect(user.books).to be_empty
      end

      it "answers 422 to POST /books/:id/editions" do
        sign_in_as(user)
        book = create(:book, user:)

        post "/api/v1/books/#{book.uuid}/editions", params: { edition: { status: "done", finished_at: value } }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json["errors"]).to eq(invalid)
        expect(book.editions).to be_empty
      end

      it "answers 422 to PATCH /editions/:id and keeps the stored date" do
        sign_in_as(user)
        finished_at = Time.zone.parse("2025-03-01")
        edition = create(:book, user:, status: "done", finished_at:).editions.first

        patch "/api/v1/editions/#{edition.uuid}", params: { status: "done", finished_at: value }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json["errors"]).to eq(invalid)
        expect(edition.reading.reload.finished_at).to eq(finished_at)
      end

      it "answers 422 to POST /share/add" do
        token = ApiToken.issue!(user:, name: "iPhone").last

        post "/api/v1/share/add", params: { title: "X", edition: { status: "done", finished_at: value } },
          headers: bearer(token), as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json["errors"]).to eq(invalid)
        expect(user.books).to be_empty
      end

      it "answers an error to MCP add_book, which checks the input schema first" do
        result = tool_result(mcp_token(user), "add_book", title: "X", status: "done", finished_at: value)

        expect(result["isError"]).to be(true)
        expect(result.dig("content", 0, "text")).to include("/finished_at")
        expect(user.books).to be_empty
      end
    end
  end
end
