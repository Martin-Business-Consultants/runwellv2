# A token (or the OAuth approval that makes one) may be read-only: it can read everything its
# person can, and change nothing.
class AddReadOnlyToTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :access_tokens, :read_only, :boolean, null: false, default: false
    add_column :oauth_grants, :read_only, :boolean, null: false, default: false
  end
end
