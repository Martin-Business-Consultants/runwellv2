# How an AI harness, a script or the CLI signs in: a bearer token acting as one person, with
# that person's role. Personal tokens are made in Settings > Connected apps; OAuth tokens are
# issued to connectors (Claude, ChatGPT). Only digests are stored.
class CreateAccessTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :access_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :kind, null: false, default: "personal"
      t.string :token_digest, null: false, index: { unique: true }
      t.string :refresh_token_digest, index: { unique: true }
      t.references :oauth_client
      t.datetime :expires_at
      t.datetime :refresh_expires_at
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
  end
end
