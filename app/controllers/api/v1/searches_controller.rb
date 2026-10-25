module Api
  module V1
    class SearchesController < BaseController
      def show
        render json: ShelfSearch.new(current_user, params.require(:q)).call
      end
    end
  end
end
