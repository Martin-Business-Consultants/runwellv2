# Google Ads, as a plugin. The connection is the agency's own Google API app and the login it
# reads through (one row). A link points an engagement at an ad account. Spends (monthly) and
# days (daily) are the nightly copy of what Google reports, keyed by ad account so two
# engagements on one account sync once; accounts hold its name and whether it still serves.
class CreateGoogleAds < ActiveRecord::Migration[8.1]
  def change
    create_table :google_ads_connections do |t|
      t.string :client_id
      t.text :client_secret
      t.text :developer_token
      t.string :login_customer_id
      t.text :access_token
      t.text :refresh_token
      t.datetime :access_expires_at
      t.datetime :connected_at
      t.string :oauth_state
      t.text :alert_recipients
      t.text :last_error
      t.datetime :last_synced_at
      t.json :last_sync_summary
      t.timestamps
    end

    create_table :google_ads_links do |t|
      t.references :engagement, null: false, index: { unique: true }
      t.string :customer_id, null: false, index: true
      t.references :linked_by
      t.timestamps
    end

    create_table :google_ads_accounts do |t|
      t.string :customer_id, null: false, index: { unique: true }
      t.string :descriptive_name
      t.string :currency_code
      t.string :status
      t.datetime :status_changed_at
      t.datetime :alerted_at
      t.datetime :synced_at
      t.timestamps
    end

    create_table :google_ads_spends do |t|
      t.string :customer_id, null: false
      t.date :month, null: false
      t.integer :cost_cents, default: 0, null: false
      t.integer :impressions, default: 0, null: false
      t.integer :clicks, default: 0, null: false
      t.float :conversions, default: 0.0, null: false
      t.string :currency_code
      t.date :through
      t.datetime :synced_at
      t.timestamps
      t.index %i[customer_id month], unique: true
    end

    create_table :google_ads_days do |t|
      t.string :customer_id, null: false
      t.date :date, null: false
      t.integer :cost_cents, default: 0, null: false
      t.integer :clicks, default: 0, null: false
      t.integer :impressions, default: 0, null: false
      t.float :conversions, default: 0.0, null: false
      t.integer :conversions_value_cents, default: 0, null: false
      t.float :search_impression_share
      t.timestamps
      t.index %i[customer_id date], unique: true
    end
  end
end
