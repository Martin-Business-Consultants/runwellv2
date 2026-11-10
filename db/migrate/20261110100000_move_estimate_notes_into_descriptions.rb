# A piece of work's estimate notes (from the v1 import's context, and the seeds) were written but
# shown nowhere. They now follow its description, under a Context heading; the column stays, unread,
# for a later release to drop.
class MoveEstimateNotesIntoDescriptions < ActiveRecord::Migration[8.1]
  def up
    select_rows("SELECT id, description, estimate_notes FROM works WHERE trim(coalesce(estimate_notes, '')) <> ''").each do |id, description, notes|
      combined = [ description.presence && as_html(description), "<h3>Context</h3>", as_html(notes) ].compact.join
      execute "UPDATE works SET description = #{quote(combined)}, estimate_notes = NULL WHERE id = #{id.to_i}"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private
    def as_html(text) = text.include?("<") ? text : ActionController::Base.helpers.simple_format(text)
end
