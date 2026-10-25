require "rails_helper"

RSpec.describe "Sessions" do
  let(:user) { create(:user) }

  describe "POST /api/v1/session" do
    it "signs in a confirmed user and records an audit event" do
      post "/api/v1/session", params: { email: user.email.upcase, password: "password123" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json["user"]).to eq("id" => user.uuid, "email" => user.email, "created_at" => user.created_at.as_json)
      expect(AuditEvent.where(user:, action: "sign_in")).to exist
      get "/api/v1/me"
      expect(response).to have_http_status(:ok)
    end

    it "rejects a wrong password with a code" do
      post "/api/v1/session", params: { email: user.email, password: "nope" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(error_codes).to eq([ "invalid_credentials" ])
      expect(AuditEvent.where(user:, action: "sign_in_failed")).to exist
    end

    it "rejects an unknown email with the same code" do
      post "/api/v1/session", params: { email: "ghost@example.com", password: "x" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(error_codes).to eq([ "invalid_credentials" ])
    end

    it "rejects an unconfirmed user" do
      user = create(:user, :unconfirmed)
      post "/api/v1/session", params: { email: user.email, password: "password123" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(error_codes).to eq([ "unconfirmed" ])
    end

    it "records the client address forwarded by the platform edge" do
      post "/api/v1/session", params: { email: user.email, password: "password123" },
        headers: { "X-Forwarded-For" => "203.0.113.9, 100.64.0.2" }, env: { "REMOTE_ADDR" => "100.64.0.7" }, as: :json

      expect(AuditEvent.find_by!(action: "sign_in").ip).to eq("203.0.113.9")
    end

    it "rate limits sign in attempts" do
      10.times { post "/api/v1/session", params: { email: user.email, password: "nope" }, as: :json }
      post "/api/v1/session", params: { email: user.email, password: "password123" }, as: :json

      expect(response).to have_http_status(:too_many_requests)
      expect(error_codes).to eq([ "rate_limited" ])
    end
  end

  describe "DELETE /api/v1/session" do
    it "signs out" do
      sign_in_as(user)
      delete "/api/v1/session"

      expect(response).to have_http_status(:no_content)
      expect(AuditEvent.where(user:, action: "sign_out")).to exist
      get "/api/v1/me"
      expect(response).to have_http_status(:unauthorized)
    end

    it "requires a session" do
      delete "/api/v1/session"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "CSRF" do
    around do |example|
      Api::V1::BaseController.allow_forgery_protection = true
      example.run
    ensure
      Api::V1::BaseController.allow_forgery_protection = false
    end

    it "rejects cookie-session writes without the token and accepts the cookie value" do
      post "/api/v1/session", params: { email: user.email, password: "password123" }, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(error_codes).to eq([ "invalid_csrf" ])

      post "/api/v1/session", params: { email: user.email, password: "password123" },
        headers: { "X-CSRF-Token" => cookies["CSRF-TOKEN"] }, as: :json
      expect(response).to have_http_status(:ok)

      delete "/api/v1/session"
      expect(response).to have_http_status(:forbidden)
      delete "/api/v1/session", headers: { "X-CSRF-Token" => cookies["CSRF-TOKEN"] }
      expect(response).to have_http_status(:no_content)
    end

    it "does not apply to bearer token requests" do
      _token, raw = ApiToken.issue!(user:, name: "Shortcut")
      post "/api/v1/session", params: { email: user.email, password: "password123" },
        headers: bearer(raw), as: :json
      expect(response).not_to have_http_status(:forbidden)
    end
  end
end
