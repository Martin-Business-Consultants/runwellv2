fields = @fields.values.flatten
json.summary fields.any? ? "#{fields.count { !it.archived? }} custom #{"field".pluralize(fields.size)}#{", #{fields.count(&:archived?)} archived" if fields.any?(&:archived?)}" : "No custom fields"
json.fields fields do |field|
  json.extract! field, :id, :model_type, :key, :label, :kind, :position, :listed, :client_visible
  json.choices field.choices if field.kind == "choice"
  json.archived field.archived?
end
