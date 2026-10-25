module Api
  module V1
    class SessionsController < BaseController
      skip_before_action :authenticate!, only: :create
      before_action :require_session!, only: :destroy
      limit_rate to: 10, within: 3.minutes, only: :create

      def create
        user = User.find_for_authentication(email: params.require(:email))
        unless user&.valid_password?(params.require(:password))
          AuditEvent.record!("sign_in_failed", request:, user:) if user
          return render_error(:invalid_credentials, status: :unauthorized)
        end
        return render_error(:unconfirmed, status: :forbidden) unless user.confirmed?

        warden.set_user(user, scope: :user)
        AuditEvent.record!("sign_in", request:, user:)
        render json: { user: UserSerializer.call(user) }
      end

      def destroy
        AuditEvent.record!("sign_out", request:, user: current_user)
        warden.logout(:user)
        head :no_content
      end
    end
  end
end
