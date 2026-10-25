module Api
  module V1
    class MergesController < BaseController
      def destroy
        event = current_user.merge_events.find_by!(uuid: params[:id])
        books = event.unmerge!
        return render_error(:already_unmerged, status: :conflict) unless books

        render json: { books: Shelf.new(current_user).summaries(books.map(&:id)) }
      end
    end
  end
end
