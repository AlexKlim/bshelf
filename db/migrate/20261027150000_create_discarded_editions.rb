class CreateDiscardedEditions < ActiveRecord::Migration[8.1]
  def change
    create_table :discarded_editions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :store, null: false
      t.string :external_id, null: false
      t.timestamps
    end
    add_index :discarded_editions, %i[user_id store external_id], unique: true
  end
end
