class McpTokenVerifier
  def verify(raw)
    token = Doorkeeper::AccessToken.by_token(raw)
    raise MCP::Server::OAuth::InvalidTokenError, "Token is unknown, expired or revoked" unless token&.accessible?
    # RFC 8707: only tokens bound to this server's resource are accepted.
    unless token.resource == Rails.configuration.x.mcp_resource
      raise MCP::Server::OAuth::InvalidTokenError, "Token was not issued for this resource"
    end

    token.revoke_previous_refresh_token!
    MCP::Server::OAuth::AccessToken.new(token: raw, client_id: token.application.uid, scopes: token.scopes.to_a,
      expires_at: token.expires_at&.to_i, subject: token.resource_owner_id.to_s, resource: token.resource)
  end
end
