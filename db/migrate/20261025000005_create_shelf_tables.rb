class CreateShelfTables < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm"

    create_table :books do |t|
      t.uuid :uuid, null: false, default: -> { "gen_random_uuid()" }, index: { unique: true }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :title, null: false
      t.string :author
      t.string :original_title
      t.string :language
      t.string :isbn
      t.integer :year
      t.integer :page_count
      t.integer :audio_minutes
      t.string :cover_url
      t.string :match_source, null: false, default: "manual"
      t.float :match_confidence
      t.timestamps
    end
    add_index :books, :title, using: :gin, opclass: :gin_trgm_ops
    add_index :books, :author, using: :gin, opclass: :gin_trgm_ops
    add_index :books, :original_title, using: :gin, opclass: :gin_trgm_ops

    create_table :editions do |t|
      t.uuid :uuid, null: false, default: -> { "gen_random_uuid()" }, index: { unique: true }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :book, null: false, foreign_key: { on_delete: :cascade }
      t.string :format, null: false, default: "unknown"
      t.string :store
      t.string :source, null: false
      t.string :external_id
      t.datetime :purchased_at
      t.timestamps
    end
    add_index :editions, %i[user_id store external_id], unique: true, where: "external_id IS NOT NULL"
    add_check_constraint :editions, "format IN ('audio', 'ebook', 'personal_doc', 'unknown')", name: "editions_format"

    create_table :readings do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :edition, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :status, null: false
      t.string :status_source, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :total_minutes
      t.timestamps
    end
    add_index :readings, %i[user_id status]
    add_check_constraint :readings, "status IN ('want', 'owned', 'in_progress', 'done')", name: "readings_status"
    add_check_constraint :readings,
      "status_source IN ('manual', 'litres', 'kindle_browser', 'kindle_export', 'purchase')",
      name: "readings_status_source"

    create_table :status_changes do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :reading, null: false, foreign_key: { on_delete: :cascade }
      t.string :from_status
      t.string :to_status, null: false
      t.string :source, null: false
      t.datetime :created_at, null: false
    end

    create_table :highlights do |t|
      t.uuid :uuid, null: false, default: -> { "gen_random_uuid()" }, index: { unique: true }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :book, null: false, foreign_key: { on_delete: :cascade }
      t.string :source, null: false
      t.text :text, null: false
      t.text :note
      t.string :location
      t.datetime :highlighted_at
      t.timestamps
    end

    create_table :notes do |t|
      t.uuid :uuid, null: false, default: -> { "gen_random_uuid()" }, index: { unique: true }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :book, null: false, foreign_key: { on_delete: :cascade }
      t.text :body, null: false
      t.timestamps
    end

    create_table :source_connections do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.string :status, null: false, default: "never"
      t.string :error
      t.datetime :last_sync_at
      t.timestamps
    end
    add_index :source_connections, %i[user_id kind], unique: true

    create_table :merge_events do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :book, null: false, foreign_key: { on_delete: :cascade }
      t.jsonb :merged_book, null: false, default: {}
      t.jsonb :moved, null: false, default: {}
      t.datetime :unmerged_at
      t.datetime :created_at, null: false
    end
  end
end
