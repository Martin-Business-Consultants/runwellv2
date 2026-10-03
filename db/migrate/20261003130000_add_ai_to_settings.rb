class AddAiToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :ai_enabled, :boolean, null: false, default: false
    add_column :settings, :ai_provider, :string
    add_column :settings, :ai_api_key, :string
    add_column :settings, :ai_api_base, :string
    add_column :settings, :ai_model, :string
    add_column :settings, :ai_fast_model, :string
    add_column :settings, :ai_monthly_budget_cents, :integer
    add_column :settings, :ai_portal, :boolean, null: false, default: false
    add_column :settings, :ai_test, :json
    add_column :clients, :ai_excluded, :boolean, null: false, default: false
  end
end
