module Api
  module V1
    class BooksController < BaseController
      def show
        render_book(book)
      end

      def create
        new_book = AddBook.call(user: current_user, title: params.require(:title), author: params[:author],
          **edition_params)
        render_book(new_book, status: :created)
      rescue AddBook::Duplicate => e
        existing = BookSerializer.summary(e.book, Shelf.new(current_user).key_for(e.book))
        render_error(:duplicate, field: :title, status: :conflict, existing:)
      rescue ActiveRecord::RecordInvalid => e
        render_model_errors(e.record)
      end

      def update
        return render_model_errors(book) unless book.update(params.permit(:title, :author, :original_title, :language, :year))

        render_book(book)
      end

      def destroy
        book.destroy!
        head :no_content
      end

      # Merging needs BookMatcher from the catalog lane (ET7); lookups stay so foreign ids still 404.
      def merge
        book
        current_user.books.find_by!(uuid: params.require(:other_id))
        render_error(:not_implemented, status: :not_implemented)
      end

      private

      def book = @book ||= current_user.books.find_by!(uuid: params[:id])

      # Nested because a top-level "format" key would be read as the request format.
      def edition_params
        attrs = params.fetch(:edition, {}).permit(:format, :status, :started_at, :finished_at).to_h.symbolize_keys
        { format: "unknown", status: "want" }.merge(attrs.compact_blank)
      end

      def render_book(record, status: :ok)
        render json: { book: BookSerializer.detail(record.reload, Shelf.new(current_user).key_for(record)) }, status:
      end
    end
  end
end
