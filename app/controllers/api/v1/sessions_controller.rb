module Api
  module V1
    class SessionsController < BaseController
      skip_before_action :authenticate!, only: :create
      before_action :require_session!, only: :destroy
      FAILURES_PER_EMAIL = 10
      FAILURE_WINDOW = 3.minutes

      limit_rate to: 10, within: 3.minutes, only: :create

      def create
        email = params.require(:email)
        failures = "sign_in_failures:#{email.to_s.strip.downcase}"
        if RATE_LIMIT_STORE.read(failures).to_i >= FAILURES_PER_EMAIL
          return render_error(:rate_limited, status: :too_many_requests)
        end

        user = User.find_for_authentication(email:)
        unless user&.valid_password?(params.require(:password))
          RATE_LIMIT_STORE.increment(failures, 1, expires_in: FAILURE_WINDOW)
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
