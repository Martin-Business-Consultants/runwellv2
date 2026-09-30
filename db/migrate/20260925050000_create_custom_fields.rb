# Custom fields: what an install adds to clients, engagements and work without code (a
# plumber's property address, a firm's matter number). A field is defined once per model; a
# value is text, read through the field's kind. The client's website stops being a column every
# install had and becomes the first such field, keeping every value already typed.
class CreateCustomFields < ActiveRecord::Migration[8.1]
  class Field < ActiveRecord::Base
    self.table_name = "custom_fields"
  end

  class Value < ActiveRecord::Base
    self.table_name = "custom_values"
  end

  def up
    create_table :custom_fields do |t|
      t.string :model_type, null: false
      t.string :label, null: false
      t.string :key, null: false
      t.string :kind, null: false, default: "text"
      t.json :choices
      t.integer :position, null: false
      t.boolean :listed, null: false, default: false
      t.boolean :client_visible, null: false, default: false
      t.datetime :archived_at
      t.timestamps
    end
    add_index :custom_fields, %i[model_type key], unique: true
    add_index :custom_fields, %i[model_type position]

    create_table :custom_values do |t|
      t.references :custom_field, null: false, foreign_key: true
      t.references :subject, polymorphic: true, null: false
      t.text :value, null: false
      t.timestamps
    end
    add_index :custom_values, %i[custom_field_id subject_type subject_id], unique: true, name: "index_custom_values_uniqueness"

    websites = select_rows("SELECT id, website FROM clients WHERE website IS NOT NULL AND website <> ''")
    if websites.any?
      field = Field.create!(model_type: "Client", label: "Website", key: "website", kind: "link", position: 1, listed: true)
      websites.each { |id, url| Value.create!(custom_field_id: field.id, subject_type: "Client", subject_id: id, value: url) }
    end
    remove_column :clients, :website
  end

  def down
    add_column :clients, :website, :string
    if (field = Field.find_by(model_type: "Client", key: "website"))
      Value.where(custom_field_id: field.id).each { execute("UPDATE clients SET website = #{quote(it.value)} WHERE id = #{it.subject_id.to_i}") }
    end
    drop_table :custom_values
    drop_table :custom_fields
  end
end
