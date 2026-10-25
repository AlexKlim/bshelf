module Api
  module V1
    class ProfilesController < BaseController
      before_action :require_session!, only: :destroy

      def show
        render json: { user: UserSerializer.call(current_user) }
      end

      # Every user-owned table cascades on users.id, so one DELETE wipes the account.
      # The audit row survives with only the uuid, which is not personal data on its own.
      def destroy
        user = current_user
        User.transaction do
          user.destroy!
          AuditEvent.record!("account_deleted", request:, user_uuid: user.uuid)
        end
        warden.logout(:user)
        head :no_content
      end
    end
  end
end
