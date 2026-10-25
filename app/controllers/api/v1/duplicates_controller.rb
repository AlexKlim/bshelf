module Api
  module V1
    class DuplicatesController < BaseController
      def index
        candidates = current_user.duplicate_candidates.open.order(:id).to_a
        ids = candidates.flat_map { [ it.book_id, it.other_book_id ] }.uniq
        books = ids.zip(Shelf.new(current_user).summaries(ids)).to_h
        duplicates = candidates.map do |candidate|
          { id: candidate.uuid, reason: candidate.reason, created_at: candidate.created_at,
            books: [ books.fetch(candidate.book_id), books.fetch(candidate.other_book_id) ] }
        end
        render json: { duplicates: }
      end

      def destroy
        current_user.duplicate_candidates.open.find_by!(uuid: params[:id]).update!(dismissed_at: Time.current)
        head :no_content
      end
    end
  end
end
