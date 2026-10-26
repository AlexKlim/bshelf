module Api
  module V1
    class RegistrationsController < BaseController
      skip_before_action :authenticate!
      limit_rate to: 5, within: 1.hour, only: :create

      def create
        user = User.new(email: params.require(:email), password: params.require(:password), locale: I18n.locale)
        return render_model_errors(user) unless user.save

        AuditEvent.record!("sign_up", request:, user:)
        head :created
      end
    end
  end
end
