class AddTwoFactor < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :otp_secret, :string
    add_column :users, :otp_enabled_at, :datetime
    add_column :users, :otp_last_used_at, :datetime
    add_column :users, :otp_recovery_codes, :json
    add_column :settings, :require_two_factor, :boolean, null: false, default: false
  end
end
