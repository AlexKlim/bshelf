require "rails_helper"

RSpec.describe "API tokens" do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  it "shows a new token once and lists it without the secret" do
    post "/api/v1/api_tokens", params: { name: "iPhone shortcut" }, as: :json

    expect(response).to have_http_status(:created)
    raw = json["token"]
    expect(raw).to start_with("bsh_")
    expect(ApiToken.last.token_digest).not_to include(raw)
    expect(AuditEvent.where(user:, action: "api_token_created")).to exist

    get "/api/v1/api_tokens"
    expect(json["api_tokens"]).to match([ hash_including("id" => ApiToken.last.uuid, "name" => "iPhone shortcut") ])
    expect(response.body).not_to include(raw)
  end

  it "authenticates API requests with the token" do
    _token, raw = ApiToken.issue!(user:, name: "Shortcut")

    get "/api/v1/me", headers: bearer(raw)

    expect(response).to have_http_status(:ok)
    expect(json["user"]["id"]).to eq(user.uuid)
  end

  it "revokes a token so it stops working" do
    token, raw = ApiToken.issue!(user:, name: "Shortcut")

    delete "/api/v1/api_tokens/#{token.uuid}"

    expect(response).to have_http_status(:no_content)
    expect(AuditEvent.where(user:, action: "api_token_revoked")).to exist
    get "/api/v1/me", headers: bearer(raw)
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 404 for another user's token" do
    other, raw = ApiToken.issue!(user: create(:user), name: "Theirs")

    delete "/api/v1/api_tokens/#{other.uuid}"

    expect(response).to have_http_status(:not_found)
    expect(error_codes).to eq([ "not_found" ])
    expect(other.reload.revoked_at).to be_nil
    get "/api/v1/me", headers: bearer(raw)
    expect(response).to have_http_status(:ok)
  end

  it "rejects an unknown bearer token instead of falling back to the session" do
    get "/api/v1/me", headers: bearer("bsh_forged")
    expect(response).to have_http_status(:unauthorized)
  end

  it "cannot manage tokens or the account with a token" do
    _token, raw = ApiToken.issue!(user:, name: "Shortcut")

    post "/api/v1/api_tokens", params: { name: "escalate" }, headers: bearer(raw), as: :json
    expect(response).to have_http_status(:forbidden)
    expect(error_codes).to eq([ "session_required" ])

    delete "/api/v1/me", headers: bearer(raw)
    expect(response).to have_http_status(:forbidden)
    expect(User.exists?(user.id)).to be(true)
  end

  it "requires a name" do
    post "/api/v1/api_tokens", params: { name: "" }, as: :json

    expect(response).to have_http_status(:bad_request)
    expect(json["errors"]).to eq([ { "code" => "blank", "field" => "name" } ])
  end
end
