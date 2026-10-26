module Api
  module V1
    class LibraryController < BaseController
      limit_rate to: 3, within: 1.minute, only: :tidy, by: -> { current_user.id }

      def tidy
        render json: LibraryTidy.call(current_user)
      end
    end
  end
end
