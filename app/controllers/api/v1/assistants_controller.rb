module Api
  module V1
    class AssistantsController < BaseController
      before_action :require_session!

      def index
        tokens = Doorkeeper::AccessToken.active_for(current_user).includes(:application).order(:created_at)
        assistants = tokens.group_by(&:application).map do |app, app_tokens|
          {
            id: app.uuid, name: app.name, client_id: app.uid, scopes: app_tokens.last.scopes.to_a,
            connected_at: app_tokens.first.created_at, last_active_at: app_tokens.last.created_at
          }
        end
        render json: { assistants: }
      end

      def destroy
        app = Doorkeeper::Application.authorized_for(current_user).find_by!(uuid: params[:id])
        Doorkeeper::Application.revoke_tokens_and_grants_for(app.id, current_user)
        AuditEvent.record!("assistant_revoked", request:, user: current_user, client_id: app.uid)
        head :no_content
      end
    end
  end
end
