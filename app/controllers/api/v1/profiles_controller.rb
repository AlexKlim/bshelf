module Api
  module V1
    class ProfilesController < BaseController
      before_action :require_session!, only: :destroy

      def show
        render json: { user: UserSerializer.call(current_user) }
      end

      # Every user-owned table cascades on users.id, so one DELETE wipes the account. A running remote
      # browser is finished first so its Steel browser is released. Audit rows survive without user or IP;
      # the deletion row keeps only the uuid, which is not personal data on its own.
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
