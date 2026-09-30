class AddAppearanceToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :theme, :string, null: false, default: "system"
    add_column :settings, :radius, :string, null: false, default: "fizzy"
    add_column :settings, :scheme, :string, null: false, default: "fizzy"
    add_column :settings, :font, :string, null: false, default: "system"
  end
end
