require "rails_helper"

RSpec.describe "Profile" do
  let(:user) { create(:user) }

  it "requires authentication" do
    get "/api/v1/me"

    expect(response).to have_http_status(:unauthorized)
    expect(error_codes).to eq([ "unauthorized" ])
  end

  it "shows the current user" do
    sign_in_as(user)
    get "/api/v1/me"

    expect(json["user"]).to include("id" => user.uuid, "email" => user.email)
  end

  it "remembers the interface language for mail, but only from the browser session" do
    sign_in_as(user)
    get "/api/v1/me", headers: { "Accept-Language" => "ru" }
    expect(user.reload.locale).to eq("ru")

    get "/api/v1/me", headers: { "Accept-Language" => "en", **bearer(ApiToken.issue!(user:, name: "Shortcut").last) }
    expect(user.reload.locale).to eq("ru")
  end

  describe "DELETE /api/v1/me" do
    it "wipes the account and everything it owns, keeping an anonymous audit row" do
      ApiToken.issue!(user:, name: "Shortcut")
      sign_in_as(user)

      delete "/api/v1/me"

      expect(response).to have_http_status(:no_content)
      expect(User.exists?(user.id)).to be(false)
      expect(ApiToken.where(user_id: user.id)).to be_empty
      expect(AuditEvent.where(user_id: user.id)).to be_empty
      deleted = AuditEvent.find_by!(action: "account_deleted")
      expect(deleted.user_id).to be_nil
      expect(deleted.metadata).to eq("user_uuid" => user.uuid)
      get "/api/v1/me"
      expect(response).to have_http_status(:unauthorized)
    end

    it "releases the account's running remote browser before deleting it" do
      session = live_session(user)
      sign_in_as(user)

      delete "/api/v1/me"

      expect(response).to have_http_status(:no_content)
      expect(steel.released).to eq([ session.steel_session_id ])
      expect(RemoteBrowserSession.exists?(session.id)).to be(false)
    end

    it "keeps no IP address of the deleted account in the audit log" do
      sign_in_as(user)

      delete "/api/v1/me"

      expect(AuditEvent.where(action: %w[sign_in account_deleted]).pluck(:ip)).to eq([ nil, nil ])
    end
  end

  describe "PATCH /api/v1/me/password" do
    it "changes the password, keeps this session and signs out tokens and assistants" do
      _record, raw = ApiToken.issue!(user:, name: "Shortcut")
      mcp_token(user)
      Doorkeeper::AccessGrant.create!(application: claude_app, resource_owner_id: user.id, expires_in: 60,
        redirect_uri: OauthHelpers::CLAUDE_CALLBACK, scopes: "books:read")
      sign_in_as(user)

      patch "/api/v1/me/password", params: { current_password: "password123", password: "new-password" }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(user.reload.valid_password?("new-password")).to be(true)
      expect(AuditEvent.where(user:, action: "password_changed")).to exist
      get "/api/v1/me"
      expect(response).to have_http_status(:ok)
      get "/api/v1/me", headers: bearer(raw)
      expect(response).to have_http_status(:unauthorized)
      expect(Doorkeeper::AccessToken.where(resource_owner_id: user.id, revoked_at: nil)).to be_empty
      expect(Doorkeeper::AccessGrant.where(resource_owner_id: user.id, revoked_at: nil)).to be_empty
    end

    it "rejects a wrong current password and a short new one" do
      sign_in_as(user)

      patch "/api/v1/me/password", params: { current_password: "nope", password: "new-password" }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to eq([ { "code" => "invalid", "field" => "current_password" } ])

      patch "/api/v1/me/password", params: { current_password: "password123", password: "short" }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to eq([ { "code" => "too_short", "field" => "password" } ])
      expect(user.reload.valid_password?("password123")).to be(true)
    end

    it "needs the cookie session" do
      _record, raw = ApiToken.issue!(user:, name: "Shortcut")

      patch "/api/v1/me/password", params: { current_password: "password123", password: "new-password" },
        headers: bearer(raw), as: :json

      expect(response).to have_http_status(:forbidden)
      expect(error_codes).to eq([ "session_required" ])
    end
  end
end
