class AddUserToOauthApplications < ActiveRecord::Migration[8.1]
  def change
    add_reference :oauth_applications, :user, foreign_key: { on_delete: :cascade }, index: { unique: true }
  end
end
