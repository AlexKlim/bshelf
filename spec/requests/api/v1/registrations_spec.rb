require "rails_helper"

RSpec.describe "Registration, confirmation and password reset" do
  include ActiveJob::TestHelper

  describe "POST /api/v1/registration" do
    it "creates an unconfirmed user and mails a client confirmation link" do
      perform_enqueued_jobs do
        post "/api/v1/registration", params: { email: "new@example.com", password: "password123" }, as: :json
      end

      expect(response).to have_http_status(:created)
      user = User.find_by!(email: "new@example.com")
      expect(user).not_to be_confirmed
      expect(AuditEvent.where(user:, action: "sign_up")).to exist
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ "new@example.com" ])
      expect(mail.body.encoded).to match(%r{http://localhost:5173/confirm\?token=\S+})
    end

    it "returns field error codes" do
      create(:user, email: "taken@example.com")
      post "/api/v1/registration", params: { email: "taken@example.com", password: "short" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to contain_exactly(
        { "field" => "email", "code" => "taken" }, { "field" => "password", "code" => "too_short" }
      )
    end

    it "rate limits sign ups" do
      5.times { |i| post "/api/v1/registration", params: { email: "u#{i}@example.com", password: "password123" }, as: :json }
      post "/api/v1/registration", params: { email: "u9@example.com", password: "password123" }, as: :json

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "POST /api/v1/confirmation" do
    it "confirms by token" do
      user = create(:user, :unconfirmed)
      token = user.confirmation_token

      post "/api/v1/confirmation", params: { token: }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(user.reload).to be_confirmed
      expect(AuditEvent.where(user:, action: "email_confirmed")).to exist
    end

    it "rejects a bad token" do
      post "/api/v1/confirmation", params: { token: "nope" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to eq([ { "field" => "confirmation_token", "code" => "invalid" } ])
    end

    it "resends without revealing whether the email exists" do
      user = create(:user, :unconfirmed)

      post "/api/v1/confirmation/resend", params: { email: user.email }, as: :json
      expect(response).to have_http_status(:accepted)
      post "/api/v1/confirmation/resend", params: { email: "ghost@example.com" }, as: :json
      expect(response).to have_http_status(:accepted)
    end
  end

  describe "password reset" do
    let(:user) { create(:user) }

    it "mails a reset link and accepts unknown emails silently" do
      perform_enqueued_jobs { post "/api/v1/password", params: { email: user.email }, as: :json }
      expect(response).to have_http_status(:accepted)
      expect(ActionMailer::Base.deliveries.last.body.encoded).to include("/reset-password?token=")

      post "/api/v1/password", params: { email: "ghost@example.com" }, as: :json
      expect(response).to have_http_status(:accepted)
    end

    it "sets a new password by token" do
      token = user.send_reset_password_instructions

      patch "/api/v1/password", params: { token:, password: "new-password" }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(user.reload.valid_password?("new-password")).to be(true)
      expect(AuditEvent.where(user:, action: "password_reset")).to exist
    end

    it "rejects a bad token" do
      patch "/api/v1/password", params: { token: "nope", password: "new-password" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(error_codes).to eq([ "invalid" ])
    end
  end
end
