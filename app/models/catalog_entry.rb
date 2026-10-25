class CatalogEntry < ApplicationRecord
  TTL = 30.days

  def self.fetch(key)
    entry = find_by(key:)
    return entry.data if entry && entry.updated_at > TTL.ago

    data = yield.as_json
    upsert({ key:, data: }, unique_by: :key)
    data
  end

  def self.prune = where(updated_at: ...TTL.ago).in_batches.delete_all
end
