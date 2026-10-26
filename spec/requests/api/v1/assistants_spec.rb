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

  it "dates the connection from the first grant and the activity from the latest token" do
    connected = travel_to(10.days.ago) do
      Doorkeeper::AccessGrant.create!(application: claude_app, resource_owner_id: user.id, expires_in: 60,
        redirect_uri: OauthHelpers::CLAUDE_CALLBACK, scopes: "books:read", revoked_at: Time.current)
      mcp_token(user)
      Time.current
    end
    Doorkeeper::AccessToken.update_all(revoked_at: 9.days.ago)
    latest = travel_to(1.hour.ago) do
      mcp_token(user)
      Time.current
    end
    sign_in_as(user)

    get "/api/v1/assistants"

    expect(json["assistants"].sole).to include("connected_at" => connected.as_json, "last_active_at" => latest.as_json)
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

    post "/api/v1/assistants/gemini_client", headers: bearer(raw)
    expect(response).to have_http_status(:forbidden)
    expect(error_codes).to eq([ "session_required" ])
  end

  describe "Gemini client" do
    it "shows the secret once, stores only its hash and lists the key without it" do
      sign_in_as(user)

      post "/api/v1/assistants/gemini_client"

      expect(response).to have_http_status(:created)
      app = Doorkeeper::Application.find_by!(user_id: user.id)
      expect(json).to eq("client_id" => app.uid, "client_secret" => json["client_secret"])
      expect(json["client_secret"]).to be_present
      expect(app.secret).not_to eq(json["client_secret"])
      expect(app.secret_matches?(json["client_secret"])).to be(true)
      expect(app).to have_attributes(name: "Gemini", confidential: true,
        redirect_uri: Api::V1::AssistantsController::GEMINI_REDIRECT_URI)
      expect(app.scopes.to_a).to match_array(%w[books:read books:write])
      expect(AuditEvent.last).to have_attributes(action: "gemini_client_created", user:)

      get "/api/v1/assistants"
      expect(json["gemini_client"]).to eq("client_id" => app.uid, "created_at" => app.created_at.as_json)
      expect(response.body).not_to include(app.secret)
    end

    it "replaces the key and its tokens on a second create" do
      sign_in_as(user)
      post "/api/v1/assistants/gemini_client"
      old = Doorkeeper::Application.find_by!(user_id: user.id)
      token = mcp_token(user, application: old)

      post "/api/v1/assistants/gemini_client"

      expect(Doorkeeper::Application.where(user_id: user.id).sole.uid).not_to eq(old.uid)
      mcp_call(token, "tools/list")
      expect(response).to have_http_status(:unauthorized)
    end

    it "revokes the key and every token issued to it" do
      sign_in_as(user)
      post "/api/v1/assistants/gemini_client"
      app = Doorkeeper::Application.find_by!(user_id: user.id)
      token = mcp_token(user, application: app)

      get "/api/v1/assistants"
      expect(json["assistants"].sole).to include("name" => "Gemini")

      delete "/api/v1/assistants/gemini_client"

      expect(response).to have_http_status(:no_content)
      expect(AuditEvent.last).to have_attributes(action: "gemini_client_revoked", user:)
      mcp_call(token, "tools/list")
      expect(response).to have_http_status(:unauthorized)
      get "/api/v1/assistants"
      expect(json).to eq("assistants" => [], "gemini_client" => nil)

      delete "/api/v1/assistants/gemini_client"
      expect(response).to have_http_status(:not_found)
    end
  end
end
