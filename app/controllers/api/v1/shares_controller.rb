module Api
  module V1
    class SharesController < BaseController
      include RequestLocale

      limit_rate to: 30, within: 1.minute, only: %i[create add]

      def create
        text = [ params[:title], params[:text] ].compact_blank.join("\n")
        return render_error(:blank, field: :url, status: :bad_request) if params[:url].blank? && text.blank?

        result, duration_ms = MetricEvent.measure do
          ShareCheck.new(current_user, url: params[:url].to_s.first(2048), text:).call
        end
        MetricEvent.record!("share", outcome: result[:answer][:kind], user: current_user, duration_ms:)
        render json: result
      end

      def add
        edition = params.fetch(:edition, {})
        attrs = edition.permit(:format, :status, :store, :external_id).to_h.symbolize_keys.compact_blank
        existing = attrs[:store] && attrs[:external_id] && store_edition(attrs)&.book
        return render_duplicate(existing) if existing

        book = AddBook.call(user: current_user, title: params.require(:title), author: params[:author], source: "share",
          **{ format: "unknown", status: "want" }.merge(attrs, date_params(edition)))
        edition = book.editions.first
        status = ShareCheck.status_label(edition.reading.status, edition.format)
        render json: { book: summary(book), message: I18n.t("share.added", status:) }, status: :created
      rescue AddBook::Duplicate => e
        render_duplicate(e.book)
      # Another request added the same store id between the check above and the insert.
      rescue ActiveRecord::RecordNotUnique
        render_duplicate(store_edition(attrs).book)
      rescue ActiveRecord::RecordInvalid => e
        render_model_errors(e.record)
      end

      private

      def store_edition(attrs) = current_user.editions.find_by(attrs.slice(:store, :external_id))

      def bearer_writes? = true

      def summary(book) = BookSerializer.summary(book.reload, Shelf.new(current_user).key_for(book))

      def render_duplicate(book) = render_error(:duplicate, field: :title, status: :conflict, existing: summary(book))
    end
  end
end
