class DropBillableItems < ActiveRecord::Migration[8.1]
  def up
    drop_table :billable_items
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
