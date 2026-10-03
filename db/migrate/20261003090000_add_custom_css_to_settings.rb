class AddCustomCssToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :custom_css, :text
    add_column :settings, :custom_css_everywhere, :boolean, null: false, default: false
  end
end
