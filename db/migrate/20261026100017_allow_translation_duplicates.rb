class AllowTranslationDuplicates < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :duplicate_candidates, name: "duplicate_candidates_reason"
    add_check_constraint :duplicate_candidates, "reason::text = ANY (ARRAY['title_author', 'title', 'translation']::text[])",
      name: "duplicate_candidates_reason"
  end

  def down
    execute "DELETE FROM duplicate_candidates WHERE reason = 'translation'"
    remove_check_constraint :duplicate_candidates, name: "duplicate_candidates_reason"
    add_check_constraint :duplicate_candidates, "reason::text = ANY (ARRAY['title_author', 'title']::text[])",
      name: "duplicate_candidates_reason"
  end
end
