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
  force_pkce
  pkce_code_challenge_methods %w[S256]
  # CIMD clients (Claude, ChatGPT) are public: PKCE replaces the client secret.
  client_authentication :none
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
