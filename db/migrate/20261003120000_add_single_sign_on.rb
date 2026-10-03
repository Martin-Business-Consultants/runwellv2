class AddSingleSignOn < ActiveRecord::Migration[8.1]
  def change
    add_column :sign_in_providers, :issuer, :string
    add_column :sign_in_providers, :label, :string
    add_column :settings, :providers_only, :boolean, null: false, default: false
  end
end
