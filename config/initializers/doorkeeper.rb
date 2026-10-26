# Doorkeeper ships error descriptions in English only; the consent page also renders in Russian.
Rails.application.config.i18n.fallbacks = [ :en ]
Rails.application.config.x.mcp_resource = "#{Rails.configuration.x.app_url.chomp("/")}/mcp"

Doorkeeper.configure do
  orm :active_record
  issuer Rails.configuration.x.app_url.chomp("/")

  resource_owner_authenticator do
    request.env["warden"].user(:user) || redirect_to(
      "#{Rails.configuration.x.app_url.chomp("/")}/login?return_to=#{CGI.escape(request.fullpath)}",
      allow_other_host: true
    )
  end

  grant_flows %w[authorization_code]
  pkce_code_challenge_methods %w[S256]
  # CIMD clients (Claude, ChatGPT) are public: PKCE replaces the client secret. Gemini keys are
  # confidential clients owned by one user and authenticate with their secret.
  client_authentication :none, :client_secret_basic, :client_secret_post
  hash_application_secrets
  authorize_resource_owner_for_client ->(app, user) { app.user_id.nil? || app.user_id == user.id }
  validate_client_before_resource_owner_authentication
  handle_auth_errors :redirect

  use_refresh_token
  access_token_expires_in 1.hour
  hash_token_secrets
  revoke_previous_authorization_code_token
  allow_token_introspection false

  default_scopes :"books:read"
  optional_scopes :"books:write"
  enforce_configured_scopes

  resource_indicator_validator ->(resources, _client) { resources == [ Rails.configuration.x.mcp_resource ] }
  custom_metadata client_id_metadata_document_supported: true
end

# force_pkce would also demand PKCE from Gemini, which may not send it; public clients still must.
Doorkeeper::OAuth::PreAuthorization.prepend(Module.new do
  def validate_code_challenge
    return true if client.application.confidential? || code_challenge.present?

    @invalid_request_reason = :invalid_code_challenge
    false
  end
end)
