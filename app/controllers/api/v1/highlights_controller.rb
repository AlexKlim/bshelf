module Api
  module V1
    class HighlightsController < BaseController
      def index
        book = current_user.books.find_by!(uuid: params[:book_id])
        highlights = book.highlights.order(:highlighted_at, :id)
          .offset(params[:offset].to_i.clamp(0..)).limit((params[:limit] || 50).to_i.clamp(1, 200))
        render json: { highlights: highlights.map { BookSerializer.highlight(it) }, count: book.highlights.count }
      end
    end
  end
end
