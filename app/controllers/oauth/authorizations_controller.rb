module Oauth
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    layout false
    prepend_before_action :resolve_client_metadata_document, only: :new
    # Prepended after the lookup so it runs first: every request may make an outbound metadata fetch.
    rate_limit to: 20, within: 1.minute, only: :new, prepend: true, store: Api::V1::BaseController::RATE_LIMIT_STORE,
      with: -> { head :too_many_requests }
    around_action :with_locale

    private

    def resolve_client_metadata_document
      ClientMetadataDocument.resolve(params[:client_id])
    end

    def after_successful_authorization(context)
      super
      AuditEvent.record!("assistant_connected", request:, user: current_resource_owner, client_id: params[:client_id])
    end

    def with_locale(&)
      I18n.with_locale(request.headers["Accept-Language"].to_s.match?(/\A\s*en/i) ? :en : :ru, &)
    end
  end
end
