# The install's custom fields (Settings > Fields) in forms and on pages.
module CustomFieldsHelper
  # An input per active field, inside a record's form: a helper, not a partial, because a
  # partial can't render inside form_with (ReActionView). Blank means "no value".
  def custom_field_inputs(form, record)
    safe_join(record.custom_fields.map do |field|
      name = "#{form.object_name}[custom_fields][#{field.key}]"
      id = "#{form.object_name}_custom_#{field.key}".parameterize(separator: "_")
      tag.label(class: "field") do
        safe_join([ tag.span(field.label, class: "field__label"), custom_field_input(field, name, id, record.custom_value(field)) ])
      end
    end)
  end

  # One custom field's input, as template mode lays them out one at a time (record_fields/_custom),
  # joined to the form by its id (form_id) wherever it sits.
  def custom_field_input_for(record, field, form_id: nil)
    name = "#{record.model_name.param_key}[custom_fields][#{field.key}]"
    id = "#{record.model_name.param_key}_custom_#{field.key}".parameterize(separator: "_")
    custom_field_input(field, name, id, record.custom_value(field), form: form_id)
  end

  # Who on staff sees a field (CustomField#visible_to): owners always, then a box per other role.
  # Settings > Fields and template mode's control both use it.
  def field_visibility_inputs(name, field, namespace: nil)
    prefix = [ namespace, dom_id(field.new_record? ? CustomField.new : field, :visible) ].compact.join("_")
    tag.fieldset(class: "field-visibility") do
      safe_join([
        tag.legend("Who on the team sees it", class: "field__label"),
        hidden_field_tag(name, "", id: nil),
        tag.label(class: "checkbox") { check_box_tag(nil, "owner", true, id: nil, disabled: true) + tag.span("Owners") },
        *CustomField::RESTRICTABLE_ROLES.map do |role|
          tag.label(class: "checkbox") { check_box_tag(name, role, field.seen_by_role?(role), id: "#{prefix}_#{role}") + tag.span(role.capitalize.pluralize) }
        end,
        tag.p("A field only some see is left out for everyone else wherever it shows, and never shown to #{term(:client, count: 2).downcase}.", class: "field__hint")
      ])
    end
  end

  # What this install calls the model a field belongs to (Settings > Names).
  def custom_field_model_name(model_type, count: 1)
    term({ "Client" => :client, "Work" => :work, "Task" => :task }.fetch(model_type), count: count)
  end

  # A value as a person reads it.
  def custom_field_display(field, value)
    case field.kind
    when "money" then money(value)
    when "date" then l(value, format: :long)
    when "boolean" then value ? "Yes" : "No"
    when "long_text" then rich_text(value)
    when "link" then link_to(value.delete_prefix("https://").delete_prefix("http://").delete_suffix("/"), value, target: "_blank", rel: "noopener")
    when "number" then number_with_delimiter(value)
    else value
    end
  end

  # An index table's columns for the custom fields a list shows (ui_column), numbers and money
  # at the end of theirs.
  def custom_field_columns(fields)
    fields.map { ui_column("field_#{it.id}", it.label, align: (:end if it.kind.in?(%w[number money]))) }
  end

  # A custom field's cell in a table row: one line, cut short (data-truncate) with the whole
  # value on hover.
  def custom_field_cell(field, value)
    text = custom_field_text(field, value)
    tag.td(text, class: "muted", title: text, data: { column: "field_#{field.id}", truncate: true, align: ("end" if field.kind.in?(%w[number money])) })
  end

  # Plain text for a table cell or a card's context line.
  def custom_field_text(field, value)
    return if value.nil?

    field.kind.in?(%w[link long_text]) ? strip_tags(value.to_s).delete_prefix("https://").delete_prefix("http://").delete_suffix("/").truncate(60) : strip_tags(custom_field_display(field, value).to_s)
  end

  private
    # Bare inputs: rune_ui styles them with no class.
    def custom_field_input(field, name, id, value, form: nil)
      input = { id: id, autocomplete: "off", form: form }
      case field.kind
      when "long_text" then rich_text_field_tag(name, value, id: id, staff: true, form_id: form)
      when "number" then number_field_tag(name, value, step: "any", **input)
      when "money" then money_field_tag(name, value, **input)
      when "date" then date_input_tag(name, value, **input.except(:autocomplete))
      when "boolean"
        # A span, not switch_tag's label: the field around it is already the label.
        tag.span(class: "switch") do
          safe_join([ hidden_field_tag(name, "", id: nil, form: form), check_box_tag(name, "true", value == true, id: id, role: "switch", form: form), tag.span(class: "switch__track", aria: { hidden: true }) ])
        end
      when "choice" then combobox_tag { select_tag(name, options_for_select(field.choices, value), include_blank: true, id: id, form: form) }
      when "link" then url_field_tag(name, value, placeholder: "https://…", **input)
      else text_field_tag(name, value, **input)
      end
    end
end
