# A merge moves rows, it never rewrites them: editions keep their readings and statuses, so unmerge only has
# to move the same ids back and recreate the absorbed book with its original id, uuid and timestamps.
class MergeEvent < ApplicationRecord
  FILLABLE = %w[author original_title language isbn isbn_source year page_count audio_minutes cover_url cloth].freeze
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
      moved.merge!(hand_over_candidates(survivor, absorbed))
      survivor.update!(filled)
      merged_book = snapshot(absorbed)
      absorbed.delete
      create!(user_id: survivor.user_id, book: survivor, merged_book:, moved:, filled: filled.as_json)
    end
  end

  def self.snapshot(record) = record.attributes.transform_values { it.is_a?(Time) ? it.iso8601(6) : it }

  # Candidates cannot simply move like editions: a pair is ordered and unique, and the merged pair itself
  # goes away. So the absorbed book's rows are kept as they were and copies point at the survivor.
  # Dismissed pairs come along, so the matcher keeps leaving them alone.
  def self.hand_over_candidates(survivor, absorbed)
    removed = DuplicateCandidate.involving(absorbed).to_a
    added = removed.filter_map do |candidate|
      other = candidate.other_id(absorbed)
      first, second = [ survivor.id, other ].sort
      next if other == survivor.id || DuplicateCandidate.exists?(book_id: first, other_book_id: second)

      DuplicateCandidate.create!(user_id: survivor.user_id, book_id: first, other_book_id: second,
        reason: candidate.reason, dismissed_at: candidate.dismissed_at, created_at: candidate.created_at).id
    end
    { "candidates_removed" => removed.map { snapshot(it) }, "candidates_added" => added }
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
      restore_candidates
      DuplicateCandidate.record!(book, restored, reason: "title", dismissed_at: Time.current)
      update!(unmerged_at: Time.current)
      [ book, restored ]
    end
  end

  private

  # The pair with the survivor is skipped: unmerge records it as dismissed instead.
  def restore_candidates
    DuplicateCandidate.where(id: moved["candidates_added"]).delete_all
    Array(moved["candidates_removed"]).each do |attrs|
      pair = attrs.values_at("book_id", "other_book_id")
      next if pair.include?(book_id) || Book.where(id: pair).count < 2 ||
        DuplicateCandidate.exists?(book_id: pair.first, other_book_id: pair.last)

      DuplicateCandidate.create!(attrs)
    end
  end
end
