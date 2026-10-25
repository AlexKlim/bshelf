module Api
  module V1
    class StatsController < BaseController
      def show
        year = (params[:year] || Date.current.year).to_i
        render json: YearStats.new(current_user, year).call
      end
    end
  end
end
