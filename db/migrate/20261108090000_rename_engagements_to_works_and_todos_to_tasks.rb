# 6.0: engagements are Work and todos are Tasks, down to the schema. Renames the two tables and
# the columns that point at them, and every place a record's type or an event's kind is stored
# by name: polymorphic types ("Engagement" → "Work", "Todo" → "Task"), event kinds
# (engagement.closed → work.closed, todo.created → task.created), webhook filters, and the keys of
# Settings > Names (what was "work", the todos' word, is now "task"; "engagement" is now "work").
# SQLite renames are instant and repoint other tables' foreign keys; the update backs the
# databases up first. Tables left for plugins to import from (commitments, requests,
# agreement_versions) keep their columns.
class RenameEngagementsToWorksAndTodosToTasks < ActiveRecord::Migration[8.1]
  TYPES = { "Engagement" => "Work", "Todo" => "Task" }.freeze
  TYPE_COLUMNS = { active_storage_attachments: :record_type, custom_fields: :model_type, custom_values: :subject_type,
                   documents: :documentable_type, events: :subject_type, mentions: :source_type, notes: :subject_type,
                   notifications: :source_type, searchable_documents: :searchable_type }.freeze

  class Setting < ActiveRecord::Base
    self.table_name = "settings"
  end

  class WebhookEndpoint < ActiveRecord::Base
    self.table_name = "webhook_endpoints"
  end

  def up
    rename_table :engagements, :works
    rename_table :todos, :tasks
    rename_column :tasks, :engagement_id, :work_id
    rename_column :scope_items, :engagement_id, :work_id
    rename_column :assignments, :todo_id, :task_id

    TYPE_COLUMNS.each do |table, column|
      next unless table_exists?(table)

      TYPES.each { |old, new| execute "UPDATE #{table} SET #{column} = #{quote(new)} WHERE #{column} = #{quote(old)}" }
    end

    execute "UPDATE events SET kind = 'work.' || substr(kind, 12) WHERE kind LIKE 'engagement.%'"
    execute "UPDATE events SET kind = 'task.' || substr(kind, 6) WHERE kind LIKE 'todo.%'"

    WebhookEndpoint.find_each do |endpoint|
      kinds = Array(endpoint.kinds).map { rename_kind(it) }
      endpoint.update_columns(kinds: kinds) if kinds != Array(endpoint.kinds)
    end

    Setting.find_each do |setting|
      terms = (setting.terminology || {}).dup
      renamed = terms.except("work", "engagement")
      renamed["task"] = terms["work"] if terms.key?("work")
      renamed["work"] = terms["engagement"] if terms.key?("engagement")
      setting.update_columns(terminology: renamed) if renamed != terms
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Restore the backup taken before the update instead."
  end

  private
    def quote(value) = connection.quote(value)

    def rename_kind(kind)
      kind.to_s.sub(/\Aengagement\./, "work.").sub(/\Atodo\./, "task.")
    end
end
