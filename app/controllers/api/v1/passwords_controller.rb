module Api
  module V1
    class PasswordsController < BaseController
      skip_before_action :authenticate!
      limit_rate to: 5, within: 1.hour, only: :create, name: "request"
      limit_rate to: 5, within: 1.hour, only: :update, name: "reset"

      # Always 202 so the endpoint does not reveal which emails have accounts.
      def create
        user = User.send_reset_password_instructions(email: params.require(:email))
        AuditEvent.record!("password_reset_requested", request:, user:) if user.persisted?
        head :accepted
      end

      def update
        password = params.require(:password)
        user = User.reset_password_by_token(
          reset_password_token: params.require(:token), password:, password_confirmation: password
        )
        return render_model_errors(user) if user.errors.any?

        user.revoke_access!
        AuditEvent.record!("password_reset", request:, user:)
        head :no_content
      end
    end
  end
end
