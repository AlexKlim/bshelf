class AddViewportToRemoteBrowserSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :remote_browser_sessions, :viewport, :jsonb
  end
end
