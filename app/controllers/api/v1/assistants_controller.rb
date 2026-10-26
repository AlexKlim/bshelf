module Api
  module V1
    class AssistantsController < BaseController
      GEMINI_REDIRECT_URI = "https://vertexaisearch.cloud.google.com/oauth-redirect".freeze

      before_action :require_session!
      limit_rate to: 10, within: 1.hour, only: :create_gemini_client

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
        gemini = gemini_client
        render json: { assistants:, gemini_client: gemini && { client_id: gemini.uid, created_at: gemini.created_at } }
      end

      def destroy
        app = Doorkeeper::Application.authorized_for(current_user).find_by!(uuid: params[:id])
        Doorkeeper::Application.revoke_tokens_and_grants_for(app.id, current_user)
        AuditEvent.record!("assistant_revoked", request:, user: current_user, client_id: app.uid)
        head :no_content
      end

      def create_gemini_client
        app = Doorkeeper::Application.transaction do
          gemini_client&.destroy!
          Doorkeeper::Application.create!(user_id: current_user.id, name: "Gemini", confidential: true,
            redirect_uri: GEMINI_REDIRECT_URI, scopes: Doorkeeper.config.scopes.to_s)
        end
        AuditEvent.record!("gemini_client_created", request:, user: current_user, client_id: app.uid)
        render json: { client_id: app.uid, client_secret: app.plaintext_secret }, status: :created
      end

      def destroy_gemini_client
        app = gemini_client or raise ActiveRecord::RecordNotFound
        app.destroy!
        AuditEvent.record!("gemini_client_revoked", request:, user: current_user, client_id: app.uid)
        head :no_content
      end

      private

      def gemini_client = Doorkeeper::Application.find_by(user_id: current_user.id)
    end
  end
end
