module Api
  module V1
    class SourcesController < BaseController
      LITRES_REMINDER_AFTER = 30.days
      RECENT_SESSION = 1.day

      def index
        rows = current_user.source_connections.index_by(&:kind)
        counts = current_user.editions.where(source: SourceConnection::KINDS).group(:source).count
        sessions = recent_sessions
        sources = SourceConnection::KINDS.map do |kind|
          row = rows[kind]
          { kind:, status: row&.status || "never", last_sync_at: row&.last_sync_at, error: row&.error,
            books_count: counts.fetch(kind, 0), session: sessions[kind] }
        end
        render json: { sources:, banner: banner(rows) }
      end

      private

      def recent_sessions
        current_user.remote_browser_sessions
          .where(status: RemoteBrowserSession::ACTIVE).or(current_user.remote_browser_sessions.where(finished_at: RECENT_SESSION.ago..))
          .order(:id).to_h do |session|
            [ RemoteBrowserSession::PURPOSES.fetch(session.purpose),
              session.slice(:status, :result, :interruption).merge(id: session.uuid) ]
          end
      end

      # export_ready (ET5) slots in between source_error and litres_reminder once the import exists.
      def banner(rows)
        failed = SourceConnection::KINDS.filter_map { rows[it] }.find { it.status.in?(%w[error needs_login]) }
        if failed
          { kind: "source_error", source: failed.kind, error: failed.error || failed.status, dismissible: false,
            key: "source_error:#{failed.kind}:#{failed.updated_at.to_i}" }
        elsif (litres = rows["litres"]&.last_sync_at) && litres < LITRES_REMINDER_AFTER.ago
          { kind: "litres_reminder", dismissible: true, key: "litres_reminder:#{litres.to_i}" }
        elsif (latest = current_user.duplicate_candidates.open.maximum(:id))
          { kind: "possible_duplicates", count: current_user.duplicate_candidates.open.count, dismissible: true,
            key: "possible_duplicates:#{latest}" }
        end
      end
    end
  end
end
