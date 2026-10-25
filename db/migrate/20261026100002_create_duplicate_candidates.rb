class CreateDuplicateCandidates < ActiveRecord::Migration[8.1]
  def change
    create_table :duplicate_candidates do |t|
      t.uuid :uuid, null: false, default: -> { "gen_random_uuid()" }, index: { unique: true }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :book, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :other_book, null: false, foreign_key: { to_table: :books, on_delete: :cascade }
      t.string :reason, null: false
      t.datetime :dismissed_at
      t.datetime :created_at, null: false
      t.index %i[book_id other_book_id], unique: true
      t.check_constraint "book_id < other_book_id", name: "duplicate_candidates_ordered_pair"
    end

    add_column :merge_events, :filled, :jsonb, null: false, default: {}
  end
end
