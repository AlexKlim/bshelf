# A merge moves rows, it never rewrites them: editions keep their readings and statuses, so unmerge only has
# to move the same ids back and recreate the absorbed book with its original id, uuid and timestamps.
class MergeEvent < ApplicationRecord
  FILLABLE = %w[author original_title language isbn year page_count audio_minutes cover_url cloth].freeze
  MOVED = { "editions" => Edition, "highlights" => Highlight, "notes" => Note, "merge_events" => MergeEvent }.freeze

  belongs_to :user
  belongs_to :book

  scope :active, -> { where(unmerged_at: nil) }

  def self.merge!(survivor, absorbed)
    raise ArgumentError, "a book cannot absorb itself" if survivor.id == absorbed.id
    raise ArgumentError, "books of different users" if survivor.user_id != absorbed.user_id

    transaction do
      locked = Book.where(id: [ survivor.id, absorbed.id ]).order(:id).lock.index_by(&:id)
      raise ActiveRecord::RecordNotFound, "book already merged" unless locked.size == 2

      survivor = locked.fetch(survivor.id)
      absorbed = locked.fetch(absorbed.id)
      moved = MOVED.to_h { |key, model| [ key, model.where(book_id: absorbed.id).ids ] }
      filled = absorbed.attributes.slice(*FILLABLE).select { |field, value| !value.nil? && survivor[field].nil? }

      MOVED.each { |key, model| model.where(id: moved[key]).update_all(book_id: survivor.id) }
      survivor.update!(filled)
      merged_book = absorbed.attributes.transform_values { it.is_a?(Time) ? it.iso8601(6) : it }
      absorbed.delete
      create!(user_id: survivor.user_id, book: survivor, merged_book:, moved:, filled: filled.as_json)
    end
  end

  # Returns [survivor, restored], or nil if another request unmerged it first.
  # ponytail: in a chain (A absorbs B, then C absorbs A) undoing B first leaves B's filled fields in A's
  # snapshot; editions and statuses still come back exactly. Rewrite later snapshots if that ever matters.
  def unmerge!
    transaction do
      lock!
      next if unmerged_at

      restored = Book.create!(merged_book)
      # book_id follows the rows through later merges, so rows a newer merge took elsewhere stay put.
      MOVED.each { |key, model| model.where(id: moved[key], book_id:).update_all(book_id: restored.id) }
      untouched = filled.select { |field, value| book[field].as_json == value }
      book.update!(untouched.transform_values { nil })
      DuplicateCandidate.record!(book, restored, reason: "title", dismissed_at: Time.current)
      update!(unmerged_at: Time.current)
      [ book, restored ]
    end
  end
end
