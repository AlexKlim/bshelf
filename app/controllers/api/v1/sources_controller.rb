module Api
  module V1
    class SourcesController < BaseController
      def index
        rows = current_user.source_connections.index_by(&:kind)
        sources = SourceConnection::KINDS.map do |kind|
          row = rows[kind]
          { kind:, status: row&.status || "never", last_sync_at: row&.last_sync_at, error: row&.error }
        end
        render json: { sources: }
      end
    end
  end
end
