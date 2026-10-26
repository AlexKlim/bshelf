class AddTargetIdToRemoteBrowserSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :remote_browser_sessions, :target_id, :string
  end
end
