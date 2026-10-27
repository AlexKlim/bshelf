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
        book.discard!
        head :no_content
      end

      def merge
        other = current_user.books.find_by!(uuid: params.require(:other_id))
        return render_error(:invalid, field: :other_id, status: :unprocessable_content) if other.id == book.id

        render_book(book, merge_id: MergeEvent.merge!(book, other).uuid)
      end

      def shelf
        key = params.require(:shelf).to_s
        return render_error(:inclusion, field: :shelf, status: :unprocessable_content) unless ShelfMove.key?(key)

        before, after = %i[before after].map { params[it].presence && current_user.books.find_by!(uuid: params[it]) }
        ShelfMove.call(book, key:, before:, after:)
        record = book.reload
        render json: { book: BookSerializer.summary(record, Shelf.new(current_user).key_for(record)) }
      end

      def add_edition
        AddBook.add_edition(book, **edition_params)
        render_book(book, status: :created)
      rescue ActiveRecord::RecordInvalid => e
        render_model_errors(e.record)
      end

      private

      def book = @book ||= current_user.books.find_by!(uuid: params[:id])

      def edition_params
        edition = params.fetch(:edition, {})
        attrs = edition.permit(:format, :store, :status).to_h.symbolize_keys
        { format: "unknown", status: "want" }.merge(attrs.compact_blank, date_params(edition))
      end

      def render_book(record, status: :ok, **extra)
        book = BookSerializer.detail(record.reload, Shelf.new(current_user).key_for(record))
        render json: { book:, **extra }, status:
      end
    end
  end
end
