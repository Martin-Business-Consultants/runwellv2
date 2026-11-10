# Who hears what comes into Intake, and when (IntakeShift). Tasks already in Intake count as told,
# so a first schedule doesn't send the backlog.
class CreateIntakeShifts < ActiveRecord::Migration[8.1]
  def change
    create_table :intake_shifts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :mode, null: false, default: "instant"
      t.json :days, null: false, default: [ 1, 2, 3, 4, 5 ]
      t.integer :from_minute, null: false, default: 480
      t.integer :to_minute, null: false, default: 1020
      t.json :digest_minutes, null: false, default: [ 540 ]
      t.json :sources, null: false, default: [ "clients" ]
      t.datetime :last_digest_at
      t.timestamps
    end

    add_column :tasks, :intake_notified_at, :datetime

    reversible do |dir|
      dir.up { execute "UPDATE tasks SET intake_notified_at = CURRENT_TIMESTAMP WHERE intake_at IS NOT NULL" }
    end
  end
end
