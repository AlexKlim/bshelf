module Api
  module V1
    class AssistantsController < BaseController
      before_action :require_session!

      # Refresh tokens rotate, so the live token is always new: the connection dates from the first grant or
      # token ever issued to the app, revoked ones included.
      def index
        tokens = Doorkeeper::AccessToken.active_for(current_user).includes(:application).order(:created_at)
        apps = tokens.group_by(&:application)
        history = ->(model) { model.where(resource_owner_id: current_user.id, application_id: apps.keys).group(:application_id) }
        first_grant = history.call(Doorkeeper::AccessGrant).minimum(:created_at)
        first_token = history.call(Doorkeeper::AccessToken).minimum(:created_at)
        latest_token = history.call(Doorkeeper::AccessToken).maximum(:created_at)
        assistants = apps.map do |app, app_tokens|
          { id: app.uuid, name: app.name, client_id: app.uid, scopes: app_tokens.last.scopes.to_a,
            connected_at: [ first_grant[app.id], first_token[app.id] ].compact.min, last_active_at: latest_token[app.id] }
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
