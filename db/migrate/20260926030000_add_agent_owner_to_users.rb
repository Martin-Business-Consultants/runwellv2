# Each person may have one agent user: the identity apps they connect (the CLI, Claude, other
# MCP clients) act as, so history says "Ted's agent" rather than Ted.
class AddAgentOwnerToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :agent_owner, foreign_key: { to_table: :users }, index: { unique: true }
  end
end
