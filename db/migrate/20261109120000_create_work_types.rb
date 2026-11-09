# Kinds of work become records an owner manages (Settings > Names > Types): the three the core has
# always had (project, work order, service) as system types, each with the names, prefix and
# on/off it had in Settings#terminology, which is left as it was (unread from now on). A type also
# says how its work runs (fixed scope or recurring, and how often) and what sections it starts
# with. A piece of work keeps its type's key in works.label, as before, plus its own cadence; a
# task may repeat.
class CreateWorkTypes < ActiveRecord::Migration[8.1]
  DEFAULTS = [
    { key: "project", one: "Project", other: "Projects", prefix: "P", shape: "fixed", cadence: nil },
    { key: "work_order", one: "Work order", other: "Work orders", prefix: "WO", shape: "fixed", cadence: nil },
    { key: "service", one: "Service", other: "Services", prefix: "S", shape: "recurring", cadence: "monthly" }
  ].freeze

  def up
    create_table :work_types do |t|
      t.string :key, null: false
      t.string :name_one, null: false
      t.string :name_other, null: false
      t.string :prefix, null: false
      t.text :description
      t.boolean :system, null: false, default: false
      t.string :shape, null: false, default: "fixed"
      t.string :cadence
      t.boolean :check_in, null: false, default: false
      t.json :starting_sections
      t.integer :position, null: false
      t.datetime :archived_at
      t.timestamps
    end
    add_index :work_types, :key, unique: true
    add_index :work_types, :prefix, unique: true
    add_index :work_types, :position

    add_column :works, :cadence, :string
    add_column :tasks, :repeat, :string

    labels = settings_labels
    now = Time.current
    DEFAULTS.each_with_index do |type, index|
      saved = labels.fetch(type[:key], {})
      prefix = saved["prefix"].to_s.upcase.gsub(/[^A-Z0-9]/, "").presence || type[:prefix]
      execute ActiveRecord::Base.sanitize_sql_array([
        "INSERT INTO work_types (key, name_one, name_other, prefix, system, shape, cadence, position, archived_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        type[:key], saved["one"].presence || type[:one], saved["other"].presence || type[:other], prefix, true,
        type[:shape], type[:cadence], index + 1, (saved["enabled"] == false ? now : nil), now, now
      ])
    end

    # A recurring service runs monthly unless someone says otherwise.
    execute "UPDATE works SET cadence = 'monthly' WHERE shape = 'recurring' AND cadence IS NULL"
  end

  def down
    remove_column :tasks, :repeat
    remove_column :works, :cadence
    drop_table :work_types
  end

  private
    def settings_labels
      raw = select_value("SELECT terminology FROM settings ORDER BY id LIMIT 1")
      (raw.present? ? JSON.parse(raw) : {}).fetch("labels", {})
    rescue JSON::ParserError
      {}
    end
end
