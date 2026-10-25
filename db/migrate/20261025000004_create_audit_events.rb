class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :action, null: false
      t.string :ip
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end
  end
end
