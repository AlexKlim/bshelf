class AllowStorytelSource < ActiveRecord::Migration[8.1]
  CHECKS = {
    remote_browser_sessions: [ "remote_browser_sessions_purpose", "purpose", %w[kindle litres] ],
    source_connections: [ "source_connections_kind", "kind", %w[litres kindle_export kindle_browser] ],
    readings: [ "readings_status_source", "status_source", %w[manual litres kindle_browser kindle_export purchase] ]
  }.freeze

  def up = CHECKS.each { |table, (name, column, values)| replace(table, name, column, values + %w[storytel]) }

  def down = CHECKS.each { |table, (name, column, values)| replace(table, name, column, values) }

  private

  def replace(table, name, column, values)
    remove_check_constraint table, name: name
    add_check_constraint table, "#{column} IN (#{values.map { "'#{it}'" }.join(", ")})", name: name
  end
end
