require "rails_helper"

RSpec.describe "Rate limits" do
  let(:user) { create(:user) }
  let(:token) { ApiToken.issue!(user:, name: "Shortcut").last }

  [
    [ :post, "/api/v1/registration", 5, :none, { email: "new@example.com", password: "password123" } ],
    [ :post, "/api/v1/confirmation/resend", 5, :none, { email: "ghost@example.com" } ],
    [ :post, "/api/v1/password", 5, :none, { email: "ghost@example.com" } ],
    [ :patch, "/api/v1/password", 5, :none, { token: "nope", password: "new-password" } ],
    [ :post, "/api/v1/session", 10, :none, { email: "ghost@example.com", password: "nope" } ],
    [ :post, "/api/v1/api_tokens", 20, :session, { name: "Shortcut" } ],
    [ :post, "/api/v1/remote_browser_sessions", 10, :session, { purpose: "kindle", disclosure_accepted: true } ],
    [ :post, "/api/v1/share", 30, :bearer, { text: "Solaris" } ],
    [ :post, "/api/v1/share/add", 30, :bearer, { title: "Solaris" } ],
    [ :get, "/oauth/authorize", 20, :none, { client_id: "https://evil.example/client.json" } ]
  ].each do |method, path, limit, auth, params|
    it "allows #{limit} #{method.upcase} #{path} per client, then answers 429" do
      sign_in_as(user) if auth == :session
      headers = auth == :bearer ? bearer(token) : {}
      call = -> { public_send(method, path, params:, headers:, as: (method == :get ? nil : :json)) }

      limit.times do
        call.call
        expect(response).not_to have_http_status(:too_many_requests)
      end
      call.call

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  it "limits sign in attempts per email across addresses" do
    10.times do |i|
      post "/api/v1/session", params: { email: user.email, password: "nope" }, env: { "REMOTE_ADDR" => "203.0.113.#{i}" }, as: :json
    end

    post "/api/v1/session", params: { email: " #{user.email.upcase}", password: "password123" },
      env: { "REMOTE_ADDR" => "198.51.100.1" }, as: :json

    expect(response).to have_http_status(:too_many_requests)
  end

  it "counts only failed sign ins toward the per-email limit" do
    sign_in = ->(password, i) do
      post "/api/v1/session", params: { email: user.email, password: }, env: { "REMOTE_ADDR" => "203.0.113.#{i}" }, as: :json
    end

    10.times { |i| sign_in.call("password123", i) }
    9.times { |i| sign_in.call("nope", 10 + i) }
    expect(response).to have_http_status(:unauthorized)

    sign_in.call("password123", 19)
    expect(response).to have_http_status(:ok)

    sign_in.call("nope", 20)
    sign_in.call("password123", 21)
    expect(response).to have_http_status(:too_many_requests)

    post "/api/v1/session", params: { email: "other@example.com", password: "nope" },
      env: { "REMOTE_ADDR" => "203.0.113.22" }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "keeps the reset request and the reset itself in separate buckets" do
    5.times { post "/api/v1/password", params: { email: user.email }, as: :json }
    token = user.send_reset_password_instructions

    patch "/api/v1/password", params: { token:, password: "new-password" }, as: :json

    expect(response).to have_http_status(:no_content)
  end
end
