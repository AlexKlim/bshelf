module Api
  module V1
    class ConfirmationsController < BaseController
      skip_before_action :authenticate!
      limit_rate to: 5, within: 1.hour, only: :resend

      def create
        user = User.confirm_by_token(params.require(:token))
        return render_model_errors(user) if user.errors.any?

        AuditEvent.record!("email_confirmed", request:, user:)
        head :no_content
      end

      # Always 202 so the endpoint does not reveal which emails have accounts.
      def resend
        User.send_confirmation_instructions(email: params.require(:email))
        head :accepted
      end
    end
  end
end
