class CreateMetricEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :metric_events do |t|
      t.string :name, null: false
      t.string :outcome, null: false
      t.references :user, foreign_key: { on_delete: :nullify }
      t.integer :duration_ms
      t.datetime :created_at, null: false
      t.index %i[name created_at]
    end
  end
end
