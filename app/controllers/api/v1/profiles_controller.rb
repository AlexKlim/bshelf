module Api
  module V1
    class ProfilesController < BaseController
      before_action :require_session!, only: %i[destroy password]
      limit_rate to: 10, within: 1.hour, only: :password, by: -> { current_user.id }

      def show
        render json: { user: UserSerializer.call(current_user) }
      end

      def password
        user = current_user
        new_password = params.require(:password).to_s
        updated = user.update_with_password(current_password: params.require(:current_password).to_s,
          password: new_password, password_confirmation: new_password)
        return render_model_errors(user) unless updated

        user.revoke_access!
        warden.set_user(user, scope: :user)
        AuditEvent.record!("password_changed", request:, user:)
        head :no_content
      end

      def destroy
        user = current_user
        user.remote_browser_sessions.active.find_each { it.finish!(interruption: "aborted") }
        User.transaction do
          user.audit_events.update_all(ip: nil)
          user.destroy!
          AuditEvent.create!(action: "account_deleted", metadata: { user_uuid: user.uuid })
        end
        warden.logout(:user)
        head :no_content
      end
    end
  end
end
