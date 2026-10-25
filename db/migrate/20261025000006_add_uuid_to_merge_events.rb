class AddUuidToMergeEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :merge_events, :uuid, :uuid, null: false, default: -> { "gen_random_uuid()" }
    add_index :merge_events, :uuid, unique: true
  end
end
