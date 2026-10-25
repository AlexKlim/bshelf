module Oauth
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    layout false
    prepend_before_action :resolve_client_metadata_document, only: :new
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
