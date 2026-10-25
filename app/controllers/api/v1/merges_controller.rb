module Api
  module V1
    # Unmerge belongs to the catalog lane (ET7) together with BookMatcher.
    class MergesController < BaseController
      def destroy
        current_user.merge_events.find_by!(uuid: params[:id])
        render_error(:not_implemented, status: :not_implemented)
      end
    end
  end
end
