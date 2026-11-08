# Template mode (RecordLayout): a record page's fields laid out as the install arranged them. A
# page renders its zones (record_fields/zone) and, for owners, the arranging bar
# (record_fields/arrange). Fields sit outside the page's <form> and join it by id (form_id), so a
# field can live in either column and still save with it; every field widget respects that.
module RecordLayoutHelper
  def record_layout(kind) = (@record_layouts ||= {})[kind.to_s] ||= Setting.current.layout(kind)

  # A form builder with no <form> of its own, for fields that join a form by id.
  def record_fields_builder(record, scope: nil)
    ComboboxFormBuilder.new(scope || record.model_name.param_key, record, self, {})
  end

  # What a field is called, for its chip while arranging.
  def layout_field_label(layout, key)
    return layout.custom_field(key)&.label || key if layout.custom?(key)

    labels = {
      "name" => "Name", "status" => "Status", "time_zone" => "Time zone", "internal" => "Internal",
      "title" => "Title", "description" => "Description", "client" => term(:client), "label" => "Label", "shape" => "Shape",
      "due" => "Due", "lead" => "Lead", "others" => "Also on it", "home" => "#{term(:scope_item)} or #{term(:client).downcase}",
      "requested_by" => "Requested by", "source" => "Came in by", "client_visible" => "Visible to the client",
      "email_address" => "Email address", "role" => "Role", "email" => "Email", "phone" => "Phone",
      "portal_access" => "Portal access", "can_approve" => "Can approve"
    }
    labels.fetch(key, key.humanize)
  end

  # The partial that draws a field (an input with a form, its value without).
  def record_field_partial(layout, key)
    layout.custom?(key) ? "record_fields/custom" : "record_fields/#{layout.kind}/#{key}"
  end
end
