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
        ui(:input, value: (cents.to_i.zero? ? nil : Money.format(cents).delete_prefix("$")), inputmode: "decimal", autocomplete: "off", **options,
          data: { money_target: "display", action: "input->money#update blur->money#format" }),
        hidden_field_tag(name, cents.nil? ? "" : cents.to_i, id: nil, form: options[:form], data: { money_target: "cents" })
      ])
    end
  end

  # A key, token or secret: the saved value (stored encrypted), masked until the eye is clicked.
  # Submitting it unchanged keeps it. A helper, not a partial, so it works inside form_with.
  def secret_field(form, method, placeholder: nil, **options)
    form.ui :password_input, method, value: form.object.try(method), autocomplete: "off", placeholder: placeholder, class: "secret-field",
      spellcheck: "false", data: { "1p-ignore": true }, **options
  end

  # An on/off switch for a boolean (ui :switch), in one of two shapes: with a hint, a
  # setting row (label and hint on the left, the switch on the right); without, the switch beside
  # its label. submit_on_change saves it as it's flipped (the form controller on the form). A helper,
  # not a partial, so it works inside form_with.
  #
  #   switch_field form, :require_two_factor, label: "Require it for everyone", hint: "…", submit_on_change: true
  # A form that keeps unsent typing in the browser (the draft controller): the data for its <form>,
  # by a key naming the form and its record, and the quiet line saying a draft came back, with
  # Discard. A helper, so it can sit inside form_with.
  def draft_data(key) = { controller: "draft", draft_key_value: key }

  def draft_notice
    tag.p(class: "draft-notice", hidden: true, data: { draft_target: "notice" }) do
      safe_join([ tag.span("Draft restored."), tag.button("Discard", type: "button", class: "draft-notice__discard", data: { action: "draft#discard" }) ], " ")
    end
  end

  def switch_field(form, method, label:, hint: nil, submit_on_change: false, **options)
    # Saving as it flips: the switch shows the change at once, and flips back if the save fails.
    data = (options.delete(:data) || {}).merge(submit_on_change ? { action: "change->form#submit", revert_on_failure: true } : {})
    switch = form.ui(:switch, method, data: data.presence, **options)

    if hint
      tag.div(class: "setting-row setting-row--field") do
        safe_join([ tag.div(class: "setting-row__text") { safe_join([ form.label(method, label, class: "setting-row__label"), tag.span(hint, class: "setting-row__hint") ]) }, switch ])
      end
    else
      tag.div(class: "field--inline") { safe_join([ switch, form.label(method, label) ]) }
    end
  end

  # For plugins: the old switch around a native checkbox (check_box_tag, form.check_box … native:
  # true), drawn by the compatibility styles. The core's own are ui :switch.
  def switch_tag(title: nil, screen_reader_label: nil, &block)
    tag.label(class: "switch", title: title) do
      safe_join([ capture(&block), tag.span(class: "switch__track", aria: { hidden: true }), (tag.span(screen_reader_label, class: "visually-hidden") if screen_reader_label) ])
    end
  end

  # Every date field: ui :date_picker, a field to type a date into ("10/20/2026", "Oct 20",
  # "2026-10-20") with a calendar in its popup, sending YYYY-MM-DD under the form's name. Its value
  # comes from the server, so a morph keeps a date someone picked unless the server's changed.
  # Options: form: (the id of a form it sits outside of), placeholder:, required: (else it has a
  # button that clears it), min:, max:, disabled:, and data: / aria: / class: for the control;
  # value: overrides the record's. t picks today, in the field or the calendar (date-keys).
  def date_input(form, method, **options)
    value = options.key?(:value) ? options.delete(:value) : form.object.try(method)
    date_picker(form.field_name(method), value, id: options.delete(:id) || form.field_id(method), **options)
  end

  def date_input_tag(name, value = nil, **options)
    date_picker(name, value, id: options.delete(:id) || sanitize_to_id(name), **options)
  end

  def date_picker(name, value, id:, **options)
    date = value.is_a?(Date) ? value : (Date.iso8601(value.to_s) rescue nil)
    data = options.delete(:data) || {}
    data = data.merge(controller: [ "date-keys", data[:controller] ].compact.join(" "), date_keys_today_value: Date.current.iso8601)
    required = options.delete(:required)
    ui :date_picker, name: name, value: date, id: id, required: required, clearable: !required, data: data,
      **options.slice(:form, :placeholder, :min, :max, :disabled, :aria, :class, :size)
  end
end
