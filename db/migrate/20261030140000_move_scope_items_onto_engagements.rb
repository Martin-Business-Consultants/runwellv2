# Agreements leave the core (3.0): sections (scope items) belong to the engagement directly, and
# nothing may point at an AgreementVersion or Approval any more. Their tables stay for the
# Agreements plugin to import from, and for a later release to drop.
class MoveScopeItemsOntoEngagements < ActiveRecord::Migration[8.1]
  def up
    add_column :scope_items, :engagement_id, :integer
    add_index :scope_items, :engagement_id
    change_column_null :scope_items, :agreement_version_id, true

    execute <<~SQL
      UPDATE scope_items SET engagement_id =
        (SELECT engagement_id FROM agreement_versions WHERE agreement_versions.id = scope_items.agreement_version_id)
    SQL
    # Every version names its engagement, so this removes nothing in practice.
    execute "DELETE FROM scope_items WHERE engagement_id IS NULL"

    # A mention in a version's reason goes (one person may be mentioned in several, and an
    # engagement holds one mention each). Events, notes, notifications and documents that pointed at
    # a version or a decision now belong to its engagement, keeping their kind and payload.
    execute "DELETE FROM mentions WHERE source_type IN ('AgreementVersion', 'Approval')"
    {
      events: %w[subject_type subject_id], notes: %w[subject_type subject_id],
      documents: %w[documentable_type documentable_id], notifications: %w[source_type source_id]
    }.each do |table, (type, id)|
      next unless table_exists?(table)

      execute <<~SQL
        UPDATE #{table} SET #{type} = 'Engagement',
          #{id} = (SELECT engagement_id FROM agreement_versions WHERE agreement_versions.id = #{table}.#{id})
        WHERE #{type} = 'AgreementVersion'
      SQL
      execute <<~SQL
        UPDATE #{table} SET #{type} = 'Engagement',
          #{id} = (SELECT agreement_versions.engagement_id FROM approvals
                   JOIN agreement_versions ON agreement_versions.id = approvals.agreement_version_id
                   WHERE approvals.id = #{table}.#{id})
        WHERE #{type} = 'Approval'
      SQL
      execute "DELETE FROM #{table} WHERE #{type} = 'Engagement' AND #{id} IS NULL"
    end

    execute "DELETE FROM searchable_documents WHERE searchable_type IN ('AgreementVersion', 'Approval')" if table_exists?(:searchable_documents)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
