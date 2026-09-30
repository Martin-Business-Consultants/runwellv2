# The install's custom fields (Settings > Fields) in forms and on pages.
module CustomFieldsHelper
  # An input per active field, inside a record's form: a helper, not a partial, because a
  # partial can't render inside form_with (ReActionView). Blank means "no value".
  def custom_field_inputs(form, record)
    safe_join(record.custom_fields.map do |field|
      name = "#{form.object_name}[custom_fields][#{field.key}]"
      id = "#{form.object_name}_custom_#{field.key}".parameterize(separator: "_")
      tag.label(class: "flex flex-column gap-half txt-align-start") do
        safe_join([ tag.span(field.label, class: "txt-small font-weight-bold"), custom_field_input(field, name, id, record.custom_value(field)) ])
      end
    end)
  end

  # What this install calls the model a field belongs to (Settings > Names).
  def custom_field_model_name(model_type, count: 1)
    term({ "Client" => :client, "Engagement" => :engagement, "Todo" => :work }.fetch(model_type), count: count)
  end

  # A value as a person reads it.
  def custom_field_display(field, value)
    case field.kind
    when "money" then money(value)
    when "date" then l(value, format: :long)
    when "boolean" then value ? "Yes" : "No"
    when "long_text" then rich_text(value)
    when "link" then link_to(value.delete_prefix("https://").delete_prefix("http://").delete_suffix("/"), value, class: "txt-link", target: "_blank", rel: "noopener")
    when "number" then number_with_delimiter(value)
    else value
    end
  end

  # Plain text for a table cell or a card's context line.
  def custom_field_text(field, value)
    return if value.nil?

    field.kind.in?(%w[link long_text]) ? strip_tags(value.to_s).delete_prefix("https://").delete_prefix("http://").delete_suffix("/").truncate(60) : strip_tags(custom_field_display(field, value).to_s)
  end

  private
    def custom_field_input(field, name, id, value)
      input = { id: id, class: "input full-width", autocomplete: "off" }
      case field.kind
      when "long_text" then rich_text_field_tag(name, value, id: id, staff: true)
      when "number" then number_field_tag(name, value, step: "any", **input)
      when "money" then money_field_tag(name, value, **input)
      when "date" then date_input_tag(name, value, **input.except(:autocomplete))
      when "boolean"
        tag.span(class: "switch") do
          safe_join([ hidden_field_tag(name, "", id: nil), check_box_tag(name, "true", value == true, id: id, class: "switch__input"), tag.span(class: "switch__btn") ])
        end
      when "choice" then select_tag(name, options_for_select(field.choices, value), include_blank: true, id: id, class: "input input--select full-width")
      when "link" then url_field_tag(name, value, placeholder: "https://…", **input)
      else text_field_tag(name, value, **input)
      end
    end
end
