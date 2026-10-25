class McpController < ActionController::API
  INSTRUCTIONS = "Book Shelf is the user's reading and listening history plus a want-to-read list. " \
    "Before answering whether the user has read or listened to a book, call search_shelf."

  def handle
    access_token = authenticator.authenticate(request.env)
    request.env[MCP::Server::OAuth::ENV_KEY] = access_token
    user = User.find(access_token.subject)

    server = MCP::Server.new(name: "bshelf", title: "Book Shelf", instructions: INSTRUCTIONS,
      tools: McpTools.allowed_for(access_token.scopes), server_context: { user: })
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(server, stateless: true,
      enable_json_response: true, serve_subscriptions_listen: false,
      allowed_hosts: [ URI.parse(Rails.configuration.x.mcp_resource).host ])
    rack_response(*transport.handle_request(Rack::Request.new(request.env)))
  rescue MCP::Server::OAuth::Error => e
    rack_response(*authenticator.challenge_response(e))
  end

  def metadata
    render json: self.class.resource_metadata
  end

  def self.resource_metadata
    @resource_metadata ||= MCP::Server::OAuth::ProtectedResourceMetadata.new(
      resource: Rails.configuration.x.mcp_resource,
      authorization_servers: [ Doorkeeper.config.issuer ],
      scopes_supported: Doorkeeper.config.scopes.to_a,
      resource_name: "Book Shelf"
    )
  end

  private

  def authenticator
    @authenticator ||= MCP::Server::OAuth::Authenticator.new(token_verifier: McpTokenVerifier.new,
      resource_metadata: self.class.resource_metadata)
  end

  def rack_response(status, headers, body)
    headers.each { |name, value| response.set_header(name, value) }
    self.status = status
    self.response_body = body
  end
end
