# Bot checks on the sign-in, sign-up and password reset forms (Settings > Email > Bot checks):
# Google reCAPTCHA or Cloudflare Turnstile, with the provider's keys.
class AddBotCheckToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :bot_check_provider, :string
    add_column :settings, :bot_check_site_key, :string
    add_column :settings, :bot_check_secret_key, :string
  end
end
