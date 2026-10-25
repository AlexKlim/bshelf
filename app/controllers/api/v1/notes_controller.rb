module Api
  module V1
    class NotesController < BaseController
      def index
        notes = book.notes.order(:created_at, :id)
        render json: { notes: notes.map { BookSerializer.note(it) } }
      end

      def create
        note = book.notes.new(user: current_user, body: params.require(:body))
        return render_model_errors(note) unless note.save

        render json: { note: BookSerializer.note(note) }, status: :created
      end

      def update
        return render_model_errors(note) unless note.update(body: params.require(:body))

        render json: { note: BookSerializer.note(note) }
      end

      def destroy
        note.destroy!
        head :no_content
      end

      private

      def book = current_user.books.find_by!(uuid: params[:book_id])

      def note = @note ||= current_user.notes.find_by!(uuid: params[:id])
    end
  end
end
