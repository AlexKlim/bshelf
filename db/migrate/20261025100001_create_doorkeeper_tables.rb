class CreateDoorkeeperTables < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_applications do |t|
      t.uuid :uuid, null: false, default: -> { "gen_random_uuid()" }, index: { unique: true }
      t.string :name, null: false
      t.string :uid, null: false, index: { unique: true }
      t.string :secret
      t.text :redirect_uri, null: false
      t.string :scopes, null: false, default: ""
      t.boolean :confidential, null: false, default: false
      t.timestamps
    end

    create_table :oauth_access_grants do |t|
      t.references :resource_owner, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :application, null: false, foreign_key: { to_table: :oauth_applications, on_delete: :cascade }
      t.string :token, null: false, index: { unique: true }
      t.integer :expires_in, null: false
      t.text :redirect_uri, null: false
      t.string :scopes, null: false, default: ""
      t.string :code_challenge
      t.string :code_challenge_method
      t.text :resource
      t.references :access_token
      t.datetime :created_at, null: false
      t.datetime :revoked_at
    end

    create_table :oauth_access_tokens do |t|
      t.references :resource_owner, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :application, null: false, foreign_key: { to_table: :oauth_applications, on_delete: :cascade }
      t.string :token, null: false, index: { unique: true }
      t.string :refresh_token, index: { unique: true }
      t.integer :expires_in
      t.string :scopes
      t.string :refresh_token_scopes
      t.string :previous_refresh_token, null: false, default: ""
      t.text :resource
      t.datetime :created_at, null: false
      t.datetime :revoked_at
    end
  end
end
