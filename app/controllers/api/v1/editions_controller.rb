module Api
  module V1
    class EditionsController < BaseController
      def update
        edition = current_user.editions.find_by!(uuid: params[:id])
        status = params.require(:status)
        return render_error(:inclusion, field: :status, status: :unprocessable_content) unless Reading::STATUSES.include?(status)

        reading = edition.reading || edition.create_reading!(user: current_user, status:, status_source: "manual")
        StatusResolver.manual!(reading, status:, **dates)

        book = edition.book.reload
        render json: { book: BookSerializer.summary(book, Shelf.new(current_user).key_for(book)) }
      end

      private

      def dates
        params.permit(:started_at, :finished_at).to_h.to_h do |field, value|
          [ field.to_sym, value.presence && Time.zone.parse(value) ]
        end
      end
    end
  end
end
