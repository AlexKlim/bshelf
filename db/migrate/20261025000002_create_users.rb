class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.uuid :uuid, null: false, default: -> { "gen_random_uuid()" }, index: { unique: true }
      t.string :email, null: false, index: { unique: true }
      t.string :encrypted_password, null: false
      t.string :reset_password_token, index: { unique: true }
      t.datetime :reset_password_sent_at
      t.string :confirmation_token, index: { unique: true }
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.timestamps
    end
  end
end
