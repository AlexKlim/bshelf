module Api
  module V1
    class SharesController < BaseController
      LOCALES = %w[en ru].freeze

      limit_rate to: 30, within: 1.minute, only: %i[create add]
      around_action :with_locale

      def create
        text = [ params[:title], params[:text] ].compact_blank.join("\n")
        return render_error(:blank, field: :url, status: :bad_request) if params[:url].blank? && text.blank?

        render json: ShareCheck.new(current_user, url: params[:url].to_s.first(2048), text:).call
      end

      def add
        attrs = params.fetch(:edition, {}).permit(:format, :status, :store, :external_id, :started_at, :finished_at)
          .to_h.symbolize_keys.compact_blank
        existing = attrs[:external_id] && current_user.editions.find_by(attrs.slice(:store, :external_id))&.book
        return render_duplicate(existing) if existing

        book = AddBook.call(user: current_user, title: params.require(:title), author: params[:author], source: "share",
          **{ format: "unknown", status: "want" }.merge(attrs))
        edition = book.editions.first
        status = ShareCheck.status_label(edition.reading.status, edition.format)
        render json: { book: summary(book), message: I18n.t("share.added", status:) }, status: :created
      rescue AddBook::Duplicate => e
        render_duplicate(e.book)
      rescue ActiveRecord::RecordInvalid => e
        render_model_errors(e.record)
      end

      private

      def with_locale(&)
        requested = [ params[:locale], *request.headers["Accept-Language"].to_s.scan(/[a-z]{2}/i) ].compact.map(&:downcase)
        I18n.with_locale(requested.find { LOCALES.include?(it) } || "en", &)
      end

      def summary(book) = BookSerializer.summary(book.reload, Shelf.new(current_user).key_for(book))

      def render_duplicate(book) = render_error(:duplicate, field: :title, status: :conflict, existing: summary(book))
    end
  end
end
