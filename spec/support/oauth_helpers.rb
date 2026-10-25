module OauthHelpers
  CLAUDE_CLIENT_ID = "https://claude.ai/oauth/mcp-client-metadata".freeze
  CLAUDE_CALLBACK = "https://claude.ai/api/mcp/auth_callback".freeze

  def mcp_resource = Rails.configuration.x.mcp_resource

  def stub_client_metadata(client_id = CLAUDE_CLIENT_ID, redirect_uris: [ CLAUDE_CALLBACK ])
    document = { client_id:, client_name: "Claude", redirect_uris:, token_endpoint_auth_method: "none" }
    allow_any_instance_of(Doorkeeper::HttpFetcher).to receive(:fetch).with(client_id).and_return(document.to_json)
  end

  def claude_app
    Doorkeeper::Application.find_or_create_by!(uid: CLAUDE_CLIENT_ID) do |app|
      app.name = "claude.ai"
      app.redirect_uri = CLAUDE_CALLBACK
      app.scopes = "books:read books:write"
      app.confidential = false
    end
  end

  def mcp_token(user, scopes: "books:read books:write", resource: mcp_resource, application: claude_app)
    Doorkeeper::AccessToken.create!(application:, resource_owner_id: user.id, scopes:, resource:,
      expires_in: 3600, use_refresh_token: true).plaintext_token
  end

  def mcp_call(token, method, params = {})
    headers = { "Accept" => "application/json, text/event-stream", "Content-Type" => "application/json",
      "Host" => URI.parse(mcp_resource).host }
    headers["Authorization"] = "Bearer #{token}" if token
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method:, params: }.to_json, headers:
  end

  def tool_result(token, name, **arguments)
    mcp_call(token, "tools/call", { name:, arguments: })
    expect(response).to have_http_status(:ok)
    json.fetch("result")
  end
end

RSpec.configure do |config|
  config.include OauthHelpers, type: :request
end
