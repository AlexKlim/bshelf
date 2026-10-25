module Api
  module V1
    class ApiTokensController < BaseController
      before_action :require_session!
      limit_rate to: 20, within: 1.hour, only: :create

      def index
        tokens = current_user.api_tokens.active.order(created_at: :desc)
        render json: { api_tokens: tokens.map { serialize(it) } }
      end

      def create
        token, raw = ApiToken.issue!(user: current_user, name: params.require(:name))
        AuditEvent.record!("api_token_created", request:, user: current_user, api_token: token.uuid)
        render json: { api_token: serialize(token), token: raw }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_model_errors(e.record)
      end

      def destroy
        token = current_user.api_tokens.active.find_by!(uuid: params[:id])
        token.revoke!
        AuditEvent.record!("api_token_revoked", request:, user: current_user, api_token: token.uuid)
        head :no_content
      end

      private

      def serialize(token)
        token.slice(:name, :created_at, :last_used_at).merge(id: token.uuid)
      end
    end
  end
end
