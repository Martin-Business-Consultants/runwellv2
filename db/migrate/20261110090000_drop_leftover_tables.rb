# Tables nothing has read since their rows moved: questions, requests and commitments became tasks
# in 3.0, and identities and sign_in_providers held sign-in through other services, removed before
# that. Nothing points at them, so dropping them touches no other table.
class DropLeftoverTables < ActiveRecord::Migration[8.1]
  def up
    %i[questions requests commitments identities sign_in_providers].each { drop_table it, if_exists: true }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
