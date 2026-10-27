# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_27_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "api_tokens", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "token_digest", null: false
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
    t.index ["uuid"], name: "index_api_tokens_on_uuid", unique: true
  end

  create_table "audit_events", force: :cascade do |t|
    t.bigint "user_id"
    t.string "action", null: false
    t.string "ip"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "books", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.string "author"
    t.string "original_title"
    t.string "language"
    t.string "isbn"
    t.integer "year"
    t.integer "page_count"
    t.integer "audio_minutes"
    t.string "cover_url"
    t.string "match_source", default: "manual", null: false
    t.float "match_confidence"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cloth"
    t.datetime "enriched_at"
    t.string "isbn_source"
    t.string "title_key", null: false
    t.string "original_title_key", null: false
    t.string "shelved_key"
    t.datetime "shelved_at"
    t.string "cloth_color"
    t.index ["author"], name: "index_books_on_author", opclass: :gin_trgm_ops, using: :gin
    t.index ["id"], name: "index_books_not_enriched", where: "(enriched_at IS NULL)"
    t.index ["original_title"], name: "index_books_on_original_title", opclass: :gin_trgm_ops, using: :gin
    t.index ["title"], name: "index_books_on_title", opclass: :gin_trgm_ops, using: :gin
    t.index ["user_id", "title_key"], name: "index_books_on_user_id_and_title_key"
    t.index ["user_id"], name: "index_books_on_user_id"
    t.index ["uuid"], name: "index_books_on_uuid", unique: true
  end

  create_table "catalog_books", force: :cascade do |t|
    t.string "title", null: false
    t.string "title_key", null: false
    t.string "author"
    t.string "original_title"
    t.string "isbn"
    t.integer "year"
    t.string "language"
    t.integer "page_count"
    t.string "cover_url"
    t.string "cloth"
    t.string "cloth_color"
    t.string "litres_id"
    t.string "amazon_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["amazon_id"], name: "index_catalog_books_on_amazon_id", unique: true, where: "(amazon_id IS NOT NULL)"
    t.index ["isbn"], name: "index_catalog_books_on_isbn"
    t.index ["litres_id"], name: "index_catalog_books_on_litres_id", unique: true, where: "(litres_id IS NOT NULL)"
    t.index ["title_key"], name: "index_catalog_books_on_title_key"
  end

  create_table "catalog_entries", force: :cascade do |t|
    t.string "key", null: false
    t.jsonb "data", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_catalog_entries_on_key", unique: true
  end

  create_table "duplicate_candidates", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "user_id", null: false
    t.bigint "book_id", null: false
    t.bigint "other_book_id", null: false
    t.string "reason", null: false
    t.datetime "dismissed_at"
    t.datetime "created_at", null: false
    t.index ["book_id", "other_book_id"], name: "index_duplicate_candidates_on_book_id_and_other_book_id", unique: true
    t.index ["other_book_id"], name: "index_duplicate_candidates_on_other_book_id"
    t.index ["user_id"], name: "index_duplicate_candidates_on_user_id"
    t.index ["uuid"], name: "index_duplicate_candidates_on_uuid", unique: true
    t.check_constraint "book_id < other_book_id", name: "duplicate_candidates_ordered_pair"
    t.check_constraint "reason::text = ANY (ARRAY['title_author'::text, 'title'::text, 'translation'::text])", name: "duplicate_candidates_reason"
  end

  create_table "editions", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "user_id", null: false
    t.bigint "book_id", null: false
    t.string "format", default: "unknown", null: false
    t.string "store"
    t.string "source", null: false
    t.string "external_id"
    t.datetime "purchased_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_editions_on_book_id"
    t.index ["user_id", "store", "external_id"], name: "index_editions_on_user_id_and_store_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["user_id"], name: "index_editions_on_user_id"
    t.index ["uuid"], name: "index_editions_on_uuid", unique: true
    t.check_constraint "format::text = ANY (ARRAY['audio'::character varying::text, 'ebook'::character varying::text, 'personal_doc'::character varying::text, 'unknown'::character varying::text])", name: "editions_format"
  end

  create_table "highlights", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "user_id", null: false
    t.bigint "book_id", null: false
    t.string "source", null: false
    t.text "text", null: false
    t.text "note"
    t.string "location"
    t.datetime "highlighted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_highlights_on_book_id"
    t.index ["user_id"], name: "index_highlights_on_user_id"
    t.index ["uuid"], name: "index_highlights_on_uuid", unique: true
  end

  create_table "merge_events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "book_id", null: false
    t.jsonb "merged_book", default: {}, null: false
    t.jsonb "moved", default: {}, null: false
    t.datetime "unmerged_at"
    t.datetime "created_at", null: false
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.jsonb "filled", default: {}, null: false
    t.index ["book_id"], name: "index_merge_events_on_book_id"
    t.index ["user_id"], name: "index_merge_events_on_user_id"
    t.index ["uuid"], name: "index_merge_events_on_uuid", unique: true
  end

  create_table "metric_events", force: :cascade do |t|
    t.string "name", null: false
    t.string "outcome", null: false
    t.bigint "user_id"
    t.integer "duration_ms"
    t.datetime "created_at", null: false
    t.index ["name", "created_at"], name: "index_metric_events_on_name_and_created_at"
    t.index ["user_id"], name: "index_metric_events_on_user_id"
  end

  create_table "notes", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "user_id", null: false
    t.bigint "book_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_notes_on_book_id"
    t.index ["user_id"], name: "index_notes_on_user_id"
    t.index ["uuid"], name: "index_notes_on_uuid", unique: true
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.bigint "resource_owner_id", null: false
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.string "code_challenge"
    t.string "code_challenge_method"
    t.text "resource"
    t.bigint "access_token_id"
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.index ["access_token_id"], name: "index_oauth_access_grants_on_access_token_id"
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.bigint "resource_owner_id", null: false
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.string "scopes"
    t.string "refresh_token_scopes"
    t.string "previous_refresh_token", default: "", null: false
    t.text "resource"
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret"
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.boolean "confidential", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
    t.index ["user_id"], name: "index_oauth_applications_on_user_id", unique: true
    t.index ["uuid"], name: "index_oauth_applications_on_uuid", unique: true
  end

  create_table "readings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "edition_id", null: false
    t.string "status", null: false
    t.string "status_source", null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer "total_minutes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["edition_id"], name: "index_readings_on_edition_id", unique: true
    t.index ["user_id", "status"], name: "index_readings_on_user_id_and_status"
    t.check_constraint "status::text = ANY (ARRAY['want'::character varying::text, 'owned'::character varying::text, 'in_progress'::character varying::text, 'done'::character varying::text])", name: "readings_status"
    t.check_constraint "status_source::text = ANY (ARRAY['manual'::character varying::text, 'litres'::character varying::text, 'kindle_browser'::character varying::text, 'kindle_export'::character varying::text, 'purchase'::character varying::text])", name: "readings_status_source"
  end

  create_table "remote_browser_sessions", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "user_id", null: false
    t.string "purpose", null: false
    t.string "status", default: "queued", null: false
    t.string "interruption"
    t.string "steel_session_id"
    t.string "websocket_url"
    t.string "viewer_path"
    t.string "viewer_token_digest"
    t.datetime "viewer_token_expires_at"
    t.jsonb "steps", default: [], null: false
    t.jsonb "result"
    t.datetime "expires_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "target_id"
    t.jsonb "viewport"
    t.index ["status"], name: "index_remote_browser_sessions_on_status"
    t.index ["user_id"], name: "index_remote_browser_sessions_on_user_id"
    t.index ["user_id"], name: "index_remote_browser_sessions_one_active_per_user", unique: true, where: "((status)::text = ANY (ARRAY[('queued'::character varying)::text, ('connecting'::character varying)::text, ('live'::character varying)::text, ('collecting'::character varying)::text]))"
    t.index ["uuid"], name: "index_remote_browser_sessions_on_uuid", unique: true
    t.check_constraint "interruption::text = ANY (ARRAY['aborted'::character varying::text, 'timeout'::character varying::text, 'provider_refused'::character varying::text, 'deploy_interrupted'::character varying::text, 'browser_failed'::character varying::text])", name: "remote_browser_sessions_interruption"
    t.check_constraint "purpose::text = ANY (ARRAY['kindle'::character varying::text, 'litres'::character varying::text])", name: "remote_browser_sessions_purpose"
    t.check_constraint "status::text = ANY (ARRAY['queued'::character varying::text, 'connecting'::character varying::text, 'live'::character varying::text, 'collecting'::character varying::text, 'done'::character varying::text, 'interrupted'::character varying::text])", name: "remote_browser_sessions_status"
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batch_id"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "source_connections", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "kind", null: false
    t.string "status", default: "never", null: false
    t.string "error"
    t.datetime "last_sync_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "kind"], name: "index_source_connections_on_user_id_and_kind", unique: true
    t.check_constraint "kind::text = ANY (ARRAY['litres'::character varying::text, 'kindle_export'::character varying::text, 'kindle_browser'::character varying::text])", name: "source_connections_kind"
    t.check_constraint "status::text = ANY (ARRAY['never'::character varying::text, 'ok'::character varying::text, 'error'::character varying::text, 'needs_login'::character varying::text])", name: "source_connections_status"
  end

  create_table "status_changes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "reading_id", null: false
    t.string "from_status"
    t.string "to_status", null: false
    t.string "source", null: false
    t.datetime "created_at", null: false
    t.index ["reading_id"], name: "index_status_changes_on_reading_id"
    t.index ["user_id"], name: "index_status_changes_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.uuid "uuid", default: -> { "gen_random_uuid()" }, null: false
    t.string "email", null: false
    t.string "encrypted_password", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale", default: "en", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["uuid"], name: "index_users_on_uuid", unique: true
  end

  add_foreign_key "api_tokens", "users", on_delete: :cascade
  add_foreign_key "audit_events", "users", on_delete: :nullify
  add_foreign_key "books", "users", on_delete: :cascade
  add_foreign_key "duplicate_candidates", "books", column: "other_book_id", on_delete: :cascade
  add_foreign_key "duplicate_candidates", "books", on_delete: :cascade
  add_foreign_key "duplicate_candidates", "users", on_delete: :cascade
  add_foreign_key "editions", "books", on_delete: :cascade
  add_foreign_key "editions", "users", on_delete: :cascade
  add_foreign_key "highlights", "books", on_delete: :cascade
  add_foreign_key "highlights", "users", on_delete: :cascade
  add_foreign_key "merge_events", "books", on_delete: :cascade
  add_foreign_key "merge_events", "users", on_delete: :cascade
  add_foreign_key "metric_events", "users", on_delete: :nullify
  add_foreign_key "notes", "books", on_delete: :cascade
  add_foreign_key "notes", "users", on_delete: :cascade
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id", on_delete: :cascade
  add_foreign_key "oauth_access_grants", "users", column: "resource_owner_id", on_delete: :cascade
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id", on_delete: :cascade
  add_foreign_key "oauth_access_tokens", "users", column: "resource_owner_id", on_delete: :cascade
  add_foreign_key "oauth_applications", "users", on_delete: :cascade
  add_foreign_key "readings", "editions", on_delete: :cascade
  add_foreign_key "readings", "users", on_delete: :cascade
  add_foreign_key "remote_browser_sessions", "users", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "source_connections", "users", on_delete: :cascade
  add_foreign_key "status_changes", "readings", on_delete: :cascade
  add_foreign_key "status_changes", "users", on_delete: :cascade
end
