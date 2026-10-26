class AllowTranslationDuplicates < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :duplicate_candidates, name: "duplicate_candidates_reason"
    add_check_constraint :duplicate_candidates, "reason::text = ANY (ARRAY['title_author', 'title', 'translation']::text[])",
      name: "duplicate_candidates_reason"
  end
end
