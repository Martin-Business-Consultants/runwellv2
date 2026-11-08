# Form fields beyond Rails' own, as helpers rather than partials so they work inside form_with:
# money, secrets, switches and dates.
module FieldsHelper
  # A money input. The column is integer cents (method, e.g. :price_cents); people see and type
  # dollars, and the money controller keeps the submitted cents in step. value: cents, for a
  # form with no model.
  def money_field(form, method, value: nil, **options)
    money_field_tag(form.field_name(method), value.nil? ? form.object.try(method) : value, id: form.field_id(method), **options)
  end

  # The same, by name, for a field with no form method (custom fields).
  def money_field_tag(name, cents, **options)
    tag.span(class: "money-field", data: { controller: "money" }) do
      safe_join([
        text_field_tag(nil, cents.to_i.zero? ? nil : Money.format(cents).delete_prefix("$"), **options,
          inputmode: "decimal", autocomplete: "off", data: { money_target: "display", action: "input->money#update blur->money#format" }),
        hidden_field_tag(name, cents.nil? ? "" : cents.to_i, id: nil, data: { money_target: "cents" })
      ])
    end
  end

  # A key, token or secret: the saved value (stored encrypted), masked until the eye is clicked.
  # Submitting it unchanged keeps it. A helper, not a partial, so it works inside form_with.
  def secret_field(form, method, placeholder: nil, **options)
    tag.span class: "secret-field", data: { controller: "reveal" } do
      safe_join([
        form.password_field(method, value: form.object.try(method), autocomplete: "off",
          spellcheck: false, placeholder: placeholder, data: { reveal_target: "input", "1p-ignore": true }, **options),
        tag.button(type: "button", class: "icon-button secret-field__eye", title: "Show", aria: { pressed: false, label: nil },
          data: { reveal_target: "button", action: "reveal#toggle" }) do
          safe_join([ icon_tag("eye", class: "secret-field__show"), icon_tag("eye-off", class: "secret-field__hide"),
            tag.span("Show or hide", class: "visually-hidden") ])
        end
      ])
    end
  end

  # An on/off switch for a boolean (rune_ui's switch), in one of two shapes: with a hint, a
  # setting row (label and hint on the left, the switch on the right); without, the switch beside
  # its label. submit_on_change saves it as it's flipped (the form controller on the form). A helper,
  # not a partial, so it works inside form_with.
  #
  #   switch_field form, :require_two_factor, label: "Require it for everyone", hint: "…", submit_on_change: true
  def switch_field(form, method, label:, hint: nil, submit_on_change: false, **options)
    data = submit_on_change ? { action: "change->form#submit" } : {}
    switch = switch_tag { form.check_box(method, role: "switch", data: data, **options) }

    if hint
      tag.div(class: "setting-row setting-row--field") do
        safe_join([ tag.div(class: "setting-row__text") { safe_join([ form.label(method, label, class: "setting-row__label"), tag.span(hint, class: "setting-row__hint") ]) }, switch ])
      end
    else
      tag.div(class: "field--inline") { safe_join([ switch, form.label(method, label) ]) }
    end
  end

  # The switch itself around any checkbox (check_box_tag, a plain input): its track, and a label
  # for screen readers when nothing beside it says what it does.
  def switch_tag(title: nil, screen_reader_label: nil, &block)
    tag.label(class: "switch", title: title) do
      safe_join([ capture(&block), tag.span(class: "switch__track", aria: { hidden: true }), (tag.span(screen_reader_label, class: "visually-hidden") if screen_reader_label) ])
    end
  end

  # Every date field: a calendar (vanillajs-datepicker, through the date-field controller). The
  # server renders both halves, so a morph never undoes it: a hidden field with the form's name and
  # the date as YYYY-MM-DD (what's submitted), and a read-only field showing it ("Oct 20, 2026")
  # that opens the calendar. Options (class, aria, data, required, autofocus, placeholder) go on the
  # field people see; value: overrides the record's. t, +, - and Delete work from the keyboard.
  DATE_FIELD_DATA = { date_field_target: "display", action: "keydown->date-field#shortcut" }.freeze
  DATE_FIELD_FORMAT = "%b %-d, %Y" # the calendar's "M d, yyyy"

  def date_input(form, method, **options)
    value = options.key?(:value) ? options.delete(:value) : form.object.try(method)
    date_picker(form.field_name(method), value, id: options.delete(:id) || form.field_id(method), **options)
  end

  def date_input_tag(name, value = nil, **options)
    date_picker(name, value, id: options.delete(:id) || sanitize_to_id(name), **options)
  end

  def date_picker(name, value, id:, **options)
    date = value.is_a?(Date) ? value : (Date.iso8601(value.to_s) rescue nil)
    data = DATE_FIELD_DATA.merge(options.delete(:data) || {}) { |key, ours, theirs| key == :action ? "#{ours} #{theirs}" : theirs }
    tag.span(class: "date-picker", data: { controller: "date-field" }) do
      hidden_field_tag(name, date&.iso8601, id: nil, data: { date_field_target: "value" }) +
        text_field_tag(nil, date&.strftime(DATE_FIELD_FORMAT), id: id, readonly: true, autocomplete: "off",
          placeholder: options.delete(:placeholder) || "Pick a date", data: data, **options)
    end
  end
end
