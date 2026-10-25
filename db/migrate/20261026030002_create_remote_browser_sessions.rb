class CreateRemoteBrowserSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :remote_browser_sessions do |t|
      t.uuid :uuid, null: false, default: -> { "gen_random_uuid()" }, index: { unique: true }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :purpose, null: false
      t.string :status, null: false, default: "queued"
      t.string :interruption
      t.string :steel_session_id
      t.string :websocket_url
      t.string :viewer_path
      t.string :viewer_token_digest
      t.datetime :viewer_token_expires_at
      t.jsonb :steps, null: false, default: []
      t.jsonb :result
      t.datetime :expires_at
      t.datetime :finished_at
      t.timestamps
      t.index :status
      t.index :user_id, unique: true, where: "status IN ('queued', 'connecting', 'live', 'collecting')",
        name: "index_remote_browser_sessions_one_active_per_user"
    end
  end
end
