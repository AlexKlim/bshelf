require "rails_helper"

RSpec.describe User do
  include OauthHelpers

  it "leaves no row pointing at a deleted account in any table" do
    book = create(:book, status: "done", finished_at: 1.day.ago)
    user = book.user
    other = create(:book, user:)
    create(:note, book:)
    create(:highlight, book:)
    user.source_connections.create!(kind: "litres")
    StatusResolver.manual!(book.readings.first, status: "in_progress")
    MergeEvent.create!(user:, book:)
    DuplicateCandidate.record!(book, other, reason: "title")
    live_session(user)
    ApiToken.issue!(user:, name: "Shortcut")
    mcp_token(user)
    Doorkeeper::AccessGrant.create!(application: claude_app, resource_owner_id: user.id, expires_in: 60,
      redirect_uri: OauthHelpers::CLAUDE_CALLBACK, scopes: "books:read")
    AuditEvent.create!(user:, action: "sign_in", ip: "203.0.113.9")
    MetricEvent.record!("share", outcome: "read", user:)

    user.destroy!

    connection = ActiveRecord::Base.connection
    owner_columns = connection.tables.flat_map do |table|
      (connection.columns(table).map(&:name) & %w[user_id resource_owner_id]).map { [ table, it ] }
    end
    expect(owner_columns.map(&:first)).to include("books", "remote_browser_sessions", "oauth_access_tokens")
    owner_columns.each do |table, column|
      count = connection.select_value("SELECT count(*) FROM #{connection.quote_table_name(table)} WHERE #{column} = #{user.id}")
      expect(count).to eq(0), "#{table}.#{column} rows survived"
    end
  end
end
