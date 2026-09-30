# OAuth 2.1 for connectors (Claude, ChatGPT): clients register themselves (dynamic client
# registration), a person approves one in the browser, and it trades a single-use code (with
# PKCE) for an AccessToken.
class CreateOauthClientsAndGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_clients do |t|
      t.string :uid, null: false, index: { unique: true }
      t.string :name, null: false
      t.json :redirect_uris, null: false
      t.timestamps
    end

    create_table :oauth_grants do |t|
      t.references :oauth_client, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :code_digest, null: false, index: { unique: true }
      t.string :redirect_uri, null: false
      t.string :code_challenge, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end
  end
end
