class TightenIndexesAndChecks < ActiveRecord::Migration[8.1]
  def change
    # Both are prefixes of a composite index on the same table.
    remove_index :readings, :user_id, name: "index_readings_on_user_id"
    remove_index :source_connections, :user_id, name: "index_source_connections_on_user_id"

    add_index :books, :id, where: "enriched_at IS NULL", name: "index_books_not_enriched"

    add_check_constraint :remote_browser_sessions,
      "status IN ('queued', 'connecting', 'live', 'collecting', 'done', 'interrupted')", name: "remote_browser_sessions_status"
    add_check_constraint :remote_browser_sessions, "purpose IN ('kindle', 'litres')", name: "remote_browser_sessions_purpose"
    add_check_constraint :remote_browser_sessions,
      "interruption IN ('aborted', 'timeout', 'provider_refused', 'deploy_interrupted', 'browser_failed')",
      name: "remote_browser_sessions_interruption"
    add_check_constraint :duplicate_candidates, "reason IN ('title_author', 'title')", name: "duplicate_candidates_reason"
    add_check_constraint :source_connections, "kind IN ('litres', 'kindle_export', 'kindle_browser')",
      name: "source_connections_kind"
    add_check_constraint :source_connections, "status IN ('never', 'ok', 'error', 'needs_login')",
      name: "source_connections_status"
  end
end
