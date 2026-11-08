# Who on staff sees a custom field: the roles besides owners (who see every field), or nil for
# everyone. Enforced wherever values are read (CustomField.for, the viewer's role).
class AddVisibleToToCustomFields < ActiveRecord::Migration[8.1]
  def change
    add_column :custom_fields, :visible_to, :json
  end
end
