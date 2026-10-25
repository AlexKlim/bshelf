require "rails_helper"

RSpec.describe "Assistants" do
  let(:user) { create(:user) }

  it "lists connected assistants and revokes one" do
    mcp_token(user)
    mcp_token(create(:user))
    sign_in_as(user)

    get "/api/v1/assistants"

    expect(json["assistants"]).to match([
      hash_including("id" => claude_app.uuid, "name" => "claude.ai", "client_id" => OauthHelpers::CLAUDE_CLIENT_ID,
        "scopes" => %w[books:read books:write], "connected_at" => be_present, "last_active_at" => be_present)
    ])

    delete "/api/v1/assistants/#{claude_app.uuid}"

    expect(response).to have_http_status(:no_content)
    expect(AuditEvent.last).to have_attributes(action: "assistant_revoked", user:)
    get "/api/v1/assistants"
    expect(json["assistants"]).to eq([])
    expect(Doorkeeper::AccessToken.where(revoked_at: nil).count).to eq(1)
  end

  it "answers 404 for an assistant the user never connected" do
    mcp_token(create(:user))
    sign_in_as(user)

    delete "/api/v1/assistants/#{claude_app.uuid}"

    expect(response).to have_http_status(:not_found)
  end

  it "needs the cookie session" do
    _record, raw = ApiToken.issue!(user:, name: "Shortcut")

    get "/api/v1/assistants", headers: bearer(raw)

    expect(response).to have_http_status(:forbidden)
    expect(error_codes).to eq([ "session_required" ])
  end
end
