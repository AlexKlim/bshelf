# Resolves an OAuth Client ID Metadata Document (CIMD) client_id into a Doorkeeper application.
# Only hosts we trust are fetched (MCP_AUTH.md); the redirect URIs must live on the client_id host,
# so a document cannot send codes anywhere else. Replace with Doorkeeper's
# use_client_id_metadata_documents once it ships in a release.
class ClientMetadataDocument
  HOSTS = %w[claude.ai chatgpt.com].freeze
  TTL = 1.day

  def self.client_id?(client_id)
    uri = URI.parse(client_id.to_s)
    uri.scheme == "https" && HOSTS.include?(uri.host) && uri.port == 443 && uri.path.length > 1 &&
      uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
  rescue URI::InvalidURIError
    false
  end

  def self.resolve(client_id)
    return unless client_id?(client_id)

    app = Doorkeeper::Application.find_by(uid: client_id)
    return app if app && app.updated_at > TTL.ago

    redirect_uris = fetch_redirect_uris(client_id)
    return app if redirect_uris.blank?

    app ||= Doorkeeper::Application.new(uid: client_id, name: URI.parse(client_id).host, confidential: false)
    app.update!(redirect_uri: redirect_uris.join("\n"), scopes: Doorkeeper.config.scopes.to_s, updated_at: Time.current)
    app
  end

  # A failed refresh keeps the stored application, so a flaky client host does not disconnect anyone.
  def self.fetch_redirect_uris(client_id)
    document = JSON.parse(Doorkeeper::HttpFetcher.new.fetch(client_id))
    return unless document.is_a?(Hash) && document["client_id"] == client_id

    host = URI.parse(client_id).host
    Array(document["redirect_uris"]).select do |uri|
      parsed = URI.parse(uri.to_s)
      parsed.scheme == "https" && parsed.host == host && parsed.fragment.nil?
    rescue URI::InvalidURIError
      false
    end
  rescue Doorkeeper::HttpFetcher::FetchError, JSON::ParserError
    nil
  end
end
