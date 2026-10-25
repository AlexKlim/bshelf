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
end
