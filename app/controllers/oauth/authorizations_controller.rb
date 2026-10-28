module Oauth
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    include RequestLocale

    GEMINI_APP_REDIRECT = %r{\Ahttps://oauth-redirect\.googleusercontent\.com/r/user_bound_custom-mcp-\d+-\w+\z}

    layout false
    prepend_before_action :resolve_client_metadata_document, only: :new
    prepend_before_action :default_resource_for_owned_client, only: %i[new create]
    prepend_before_action :accept_gemini_app_redirect, only: :new
    # Prepended after the lookup so it runs first: every request may make an outbound metadata fetch.
    rate_limit to: 20, within: 1.minute, only: :new, prepend: true, store: Api::V1::BaseController::RATE_LIMIT_STORE,
      with: -> { head :too_many_requests }

    private

    def resolve_client_metadata_document
      ClientMetadataDocument.resolve(params[:client_id])
    end

    def default_resource_for_owned_client
      return if params[:resource].present?

      # Gemini may omit the RFC 8707 resource; its key can only ever reach this MCP server.
      owned = Doorkeeper::Application.where.not(user_id: nil).exists?(uid: params[:client_id].to_s)
      params[:resource] = Rails.configuration.x.mcp_resource if owned
    end

    def accept_gemini_app_redirect
      # The Gemini app returns to a Google address that carries the Google account id, so the key
      # cannot list it up front. Trading the code still needs the key's secret.
      uri = params[:redirect_uri].to_s
      return unless uri.match?(GEMINI_APP_REDIRECT)

      app = Doorkeeper::Application.where.not(user_id: nil).find_by(uid: params[:client_id].to_s)
      app.update!(redirect_uri: "#{app.redirect_uri}\n#{uri}") if app && app.redirect_uri.split.exclude?(uri)
    end

    def after_successful_authorization(context)
      super
      AuditEvent.record!("assistant_connected", request:, user: current_resource_owner, client_id: params[:client_id])
    end
  end
end
