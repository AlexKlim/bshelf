module Api
  module V1
    class ShelvesController < BaseController
      def index
        render json: { shelves: Shelf.new(current_user).shelves(limit:) }
      end

      def show
        render json: Shelf.new(current_user).page(params[:id], offset: params[:offset].to_i.clamp(0..), limit:)
      end

      private

      def limit = (params[:limit] || 50).to_i.clamp(1, 200)
    end
  end
end
