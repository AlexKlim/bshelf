require "rails_helper"

RSpec.describe "OAuth for MCP clients" do
  let(:user) { create(:user) }
  let(:verifier) { SecureRandom.urlsafe_base64(48) }
  let(:challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false) }
  let(:issuer) { Rails.configuration.x.app_url }

  def authorize_params(**overrides)
    {
      client_id: OauthHelpers::CLAUDE_CLIENT_ID, redirect_uri: OauthHelpers::CLAUDE_CALLBACK, response_type: "code",
      scope: "books:read books:write", state: "xyz", code_challenge: challenge, code_challenge_method: "S256",
      resource: mcp_resource
    }.merge(overrides)
  end

  def token_params(code, **overrides)
    {
      grant_type: "authorization_code", code:, code_verifier: verifier, client_id: OauthHelpers::CLAUDE_CLIENT_ID,
      redirect_uri: OauthHelpers::CLAUDE_CALLBACK, resource: mcp_resource
    }.merge(overrides)
  end

  def approve(**overrides)
    get "/oauth/authorize", params: authorize_params(**overrides)
    expect(response).to have_http_status(:ok)
    post "/oauth/authorize", params: authorize_params(**overrides)
    expect(response).to have_http_status(:redirect)
    Rack::Utils.parse_query(URI.parse(response.location).query)
  end

  describe "metadata" do
    it "serves RFC 8414 authorization server metadata with CIMD, PKCE S256, public and secret clients" do
      get "/.well-known/oauth-authorization-server"

      expect(json).to include(
        "issuer" => issuer,
        "authorization_endpoint" => "http://www.example.com/oauth/authorize",
        "token_endpoint" => "http://www.example.com/oauth/token",
        "code_challenge_methods_supported" => [ "S256" ],
        "token_endpoint_auth_methods_supported" => %w[none client_secret_basic client_secret_post],
        "grant_types_supported" => match_array(%w[authorization_code refresh_token]),
        "scopes_supported" => match_array(%w[books:read books:write]),
        "client_id_metadata_document_supported" => true,
        "authorization_response_iss_parameter_supported" => true
      )
      expect(json).not_to have_key("registration_endpoint")
    end

    it "serves RFC 9728 protected resource metadata at both well-known paths" do
      %w[/.well-known/oauth-protected-resource /.well-known/oauth-protected-resource/mcp].each do |path|
        get path

        expect(json).to include("resource" => mcp_resource, "authorization_servers" => [ issuer ],
          "scopes_supported" => %w[books:read books:write], "bearer_methods_supported" => [ "header" ])
      end
    end
  end

  describe "authorization code + PKCE" do
    before { stub_client_metadata }

    it "sends a signed-out user to the SPA login and back" do
      get "/oauth/authorize", params: authorize_params

      expect(response).to have_http_status(:redirect)
      location = URI.parse(response.location)
      expect("#{location.scheme}://#{location.host}:#{location.port}#{location.path}").to eq("#{issuer}/login")
      expect(Rack::Utils.parse_query(location.query)["return_to"]).to start_with("/oauth/authorize?")
    end

    it "registers the client from its metadata document, asks for consent and issues an audience-bound token" do
      sign_in_as(user)

      get "/oauth/authorize", params: authorize_params, headers: { "Accept-Language" => "en" }
      expect(response.body).to include("claude.ai asks for access to your shelf", "Add books to your shelf")
      expect(Doorkeeper::Application.find_by(uid: OauthHelpers::CLAUDE_CLIENT_ID)).to have_attributes(
        name: "claude.ai", confidential: false, redirect_uri: OauthHelpers::CLAUDE_CALLBACK)

      post "/oauth/authorize", params: authorize_params
      redirect = URI.parse(response.location)
      query = Rack::Utils.parse_query(redirect.query)
      expect("#{redirect.scheme}://#{redirect.host}#{redirect.path}").to eq(OauthHelpers::CLAUDE_CALLBACK)
      expect(query).to include("state" => "xyz", "iss" => issuer)
      expect(AuditEvent.last).to have_attributes(action: "assistant_connected", user:)

      post "/oauth/token", params: token_params(query["code"])

      expect(response).to have_http_status(:ok)
      expect(json).to include("token_type" => "Bearer", "scope" => "books:read books:write", "expires_in" => 3600)
      expect(json["refresh_token"]).to be_present
      expect(Doorkeeper::AccessToken.last.resource).to eq(mcp_resource)

      mcp_call(json["access_token"], "tools/list")
      expect(response).to have_http_status(:ok)
    end

    it "renders the consent page in the language the share answers use" do
      sign_in_as(user)

      get "/oauth/authorize", params: authorize_params, headers: { "Accept-Language" => "ru-RU,ru;q=0.9" }
      expect(response.body).to include("claude.ai просит доступ к вашей полке")

      get "/oauth/authorize", params: authorize_params
      expect(response.body).to include("claude.ai asks for access to your shelf")
    end

    it "protects the consent form with the session CSRF token" do
      sign_in_as(user)
      ActionController::Base.allow_forgery_protection = true

      get "/oauth/authorize", params: authorize_params
      csrf = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
      # Under no-referrer Chrome posts the form with Origin: null, which the origin check refuses.
      expect(response.body).to include('<meta name="referrer" content="same-origin">')

      post "/oauth/authorize", params: authorize_params
      expect(response).to have_http_status(:unprocessable_content)

      post "/oauth/authorize", params: authorize_params.merge(authenticity_token: csrf), headers: { "Origin" => "null" }
      expect(response).to have_http_status(:unprocessable_content)

      post "/oauth/authorize", params: authorize_params.merge(authenticity_token: csrf), headers: { "Origin" => "http://www.example.com" }
      expect(response.location).to start_with(OauthHelpers::CLAUDE_CALLBACK)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end

    it "redirects with access_denied when the user denies" do
      sign_in_as(user)
      get "/oauth/authorize", params: authorize_params

      delete "/oauth/authorize", params: authorize_params

      expect(response.location).to start_with(OauthHelpers::CLAUDE_CALLBACK)
      expect(response.location).to include("error=access_denied", "state=xyz")
      expect(Doorkeeper::AccessGrant.count).to eq(0)
    end

    it "denies when the browser form posts _method=delete" do
      sign_in_as(user)
      get "/oauth/authorize", params: authorize_params

      post "/oauth/authorize", params: authorize_params.merge(_method: "delete")

      expect(response.location).to include("error=access_denied")
      expect(Doorkeeper::AccessGrant.count).to eq(0)
    end

    it "rotates the refresh token" do
      sign_in_as(user)
      post "/oauth/token", params: token_params(approve["code"])
      first = json

      post "/oauth/token", params: { grant_type: "refresh_token", refresh_token: first["refresh_token"],
        client_id: OauthHelpers::CLAUDE_CLIENT_ID, resource: mcp_resource }

      expect(response).to have_http_status(:ok)
      expect(json["refresh_token"]).not_to eq(first["refresh_token"])
      mcp_call(json["access_token"], "tools/list")
      expect(response).to have_http_status(:ok)

      post "/oauth/token", params: { grant_type: "refresh_token", refresh_token: first["refresh_token"],
        client_id: OauthHelpers::CLAUDE_CLIENT_ID }
      expect(json["error"]).to eq("invalid_grant")
    end

    it "refuses a refresh token once the assistant is revoked" do
      sign_in_as(user)
      post "/oauth/token", params: token_params(approve["code"])
      refresh_token = json["refresh_token"]

      delete "/api/v1/assistants/#{claude_app.uuid}"
      expect(response).to have_http_status(:no_content)

      post "/oauth/token", params: { grant_type: "refresh_token", refresh_token:,
        client_id: OauthHelpers::CLAUDE_CLIENT_ID, resource: mcp_resource }
      expect(response).to have_http_status(:bad_request)
      expect(json["error"]).to eq("invalid_grant")
    end

    it "accepts an authorization code once" do
      sign_in_as(user)
      code = approve["code"]

      post "/oauth/token", params: token_params(code)
      expect(response).to have_http_status(:ok)

      post "/oauth/token", params: token_params(code)
      expect(response).to have_http_status(:bad_request)
      expect(json["error"]).to eq("invalid_grant")
    end

    it "does not fetch the client metadata once GET /oauth/authorize is rate limited" do
      sign_in_as(user)
      20.times { get "/oauth/authorize", params: authorize_params }
      expect_any_instance_of(Doorkeeper::HttpFetcher).not_to receive(:fetch)
      Doorkeeper::Application.update_all(updated_at: 2.days.ago)

      get "/oauth/authorize", params: authorize_params

      expect(response).to have_http_status(:too_many_requests)
    end

    it "rejects a wrong code_verifier" do
      sign_in_as(user)

      post "/oauth/token", params: token_params(approve["code"], code_verifier: "wrong" * 10)

      expect(response).to have_http_status(:bad_request)
      expect(json["error"]).to eq("invalid_grant")
    end

    it "requires PKCE with S256" do
      sign_in_as(user)

      get "/oauth/authorize", params: authorize_params(code_challenge_method: "plain")
      expect(response.location.to_s).to include("error=invalid_code_challenge_method")

      get "/oauth/authorize", params: authorize_params.except(:code_challenge, :code_challenge_method)
      expect(response.location.to_s).to include("error=invalid_request")
    end

    it "refuses a resource other than this MCP server" do
      sign_in_as(user)

      get "/oauth/authorize", params: authorize_params(resource: "https://evil.example/mcp")

      expect(response.location.to_s).to include("error=invalid_target")
    end

    it "refuses scopes outside the server list" do
      sign_in_as(user)

      get "/oauth/authorize", params: authorize_params(scope: "books:read admin")

      expect(response.location.to_s).to include("error=invalid_scope")
    end

    it "refuses a redirect_uri the metadata document does not list" do
      sign_in_as(user)

      get "/oauth/authorize", params: authorize_params(redirect_uri: "https://claude.ai/elsewhere")

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to include("invalid_redirect_uri")
    end
  end

  describe "Gemini client" do
    let(:redirect) { Api::V1::AssistantsController::GEMINI_REDIRECT_URI }

    def gemini_key(owner)
      sign_in_as(owner)
      post "/api/v1/assistants/gemini_client"
      json.symbolize_keys
    end

    def gemini_params(client_id, **overrides)
      { client_id:, redirect_uri: redirect, response_type: "code", scope: "books:read books:write", state: "g" }
        .merge(overrides)
    end

    def gemini_code(client_id, **overrides)
      post "/oauth/authorize", params: gemini_params(client_id, **overrides)
      expect(response.location).to start_with(redirect)
      Rack::Utils.parse_query(URI.parse(response.location).query)["code"]
    end

    it "lets the owner authorize without PKCE or resource and trades the code with the secret" do
      key = gemini_key(user)

      get "/oauth/authorize", params: gemini_params(key[:client_id]), headers: { "Accept-Language" => "en" }
      expect(response.body).to include("Gemini asks for access to your shelf")
      code = gemini_code(key[:client_id])

      post "/oauth/token", params: { grant_type: "authorization_code", code:, redirect_uri: redirect },
        headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(key[:client_id], key[:client_secret]) }

      expect(response).to have_http_status(:ok)
      expect(Doorkeeper::AccessToken.last.resource).to eq(mcp_resource)
      tokens = json
      mcp_call(tokens["access_token"], "tools/list")
      expect(response).to have_http_status(:ok)

      post "/oauth/token", params: { grant_type: "refresh_token", refresh_token: tokens["refresh_token"], **key }
      expect(response).to have_http_status(:ok)
    end

    it "checks PKCE when Gemini sends it" do
      key = gemini_key(user)
      code = gemini_code(key[:client_id], code_challenge: challenge, code_challenge_method: "S256")

      post "/oauth/token", params: { grant_type: "authorization_code", code:, redirect_uri: redirect, **key }
      expect(json["error"]).to eq("invalid_request")

      post "/oauth/token", params: { grant_type: "authorization_code", code:, redirect_uri: redirect, code_verifier: verifier, **key }
      expect(response).to have_http_status(:ok)
    end

    it "refuses the token without the right secret" do
      key = gemini_key(user)

      post "/oauth/token", params: { grant_type: "authorization_code", code: gemini_code(key[:client_id]),
        redirect_uri: redirect, client_id: key[:client_id] }
      expect(response).to have_http_status(:unauthorized)
      expect(json["error"]).to eq("invalid_client")

      post "/oauth/token", params: { grant_type: "authorization_code", code: gemini_code(key[:client_id]),
        redirect_uri: redirect, client_id: key[:client_id], client_secret: "wrong" }
      expect(json["error"]).to eq("invalid_client")
    end

    it "refuses another user" do
      key = gemini_key(user)
      delete "/api/v1/session"
      sign_in_as(create(:user))

      get "/oauth/authorize", params: gemini_params(key[:client_id])

      expect(response.location).to start_with(redirect)
      expect(response.location).to include("error=access_denied")
      post "/oauth/authorize", params: gemini_params(key[:client_id])
      expect(response.location).to include("error=access_denied")
      expect(Doorkeeper::AccessGrant.count).to eq(0)
    end

    it "refuses any other redirect_uri" do
      key = gemini_key(user)

      get "/oauth/authorize", params: gemini_params(key[:client_id], redirect_uri: "https://evil.example/oauth-redirect")

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to include("invalid_redirect_uri")
    end
  end

  describe "clients without a supported registration" do
    it "refuses a client_id on a host outside the allowlist without fetching it" do
      expect_any_instance_of(Doorkeeper::HttpFetcher).not_to receive(:fetch)

      get "/oauth/authorize", params: authorize_params(client_id: "https://evil.example/client.json")

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("invalid_client")
    end

    it "ignores redirect URIs on another host and a document whose client_id does not match" do
      stub_client_metadata(redirect_uris: [ "https://evil.example/callback" ])
      get "/oauth/authorize", params: authorize_params(redirect_uri: "https://evil.example/callback")
      expect(response.body).to include("invalid_client")

      other = "https://chatgpt.com/oauth/client.json"
      allow_any_instance_of(Doorkeeper::HttpFetcher).to receive(:fetch).with(other)
        .and_return({ client_id: "https://chatgpt.com/other.json", redirect_uris: [ "https://chatgpt.com/cb" ] }.to_json)
      get "/oauth/authorize", params: authorize_params(client_id: other, redirect_uri: "https://chatgpt.com/cb")
      expect(response.body).to include("invalid_client")
      expect(Doorkeeper::Application.count).to eq(0)
    end
  end
end
