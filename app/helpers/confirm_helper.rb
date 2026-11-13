# Asking before something that can't be taken back. Every question is asked in one dialog, runeui's
# (ui :confirm, in layouts/shared/_feedback): the button or form that does the thing carries
# data-turbo-confirm, and Turbo waits for the answer before sending it. So nothing here draws a
# dialog: a delete is a form with a button, and the question rides on the button. Esc or Cancel
# puts focus back where it was.
module ConfirmHelper
  # The data attributes that make a button ask first: the question, a line under it, the word on
  # the button that goes ahead, and (danger) that button in red.
  def confirm_data(title, description: nil, button: "Delete", danger: true)
    { turbo_confirm: title, turbo_confirm_description: description, turbo_confirm_button: button,
      turbo_confirm_variant: ("destructive" if danger) }.compact
  end

  # A trash button that deletes what it names, once the dialog says yes
  # (layouts/shared/_delete_dialog). keys: the key that presses it ("d").
  def delete_button(name:, path:, message: nil, trigger_class: nil, keys: nil)
    title = "Delete #{name}?"
    button_to path, method: :delete, class: class_names("icon-button icon-button--danger", trigger_class), title: title,
      aria: { label: title }, form: { data: { turbo_frame: "_top" } },
      data: { keys: keys, **confirm_data(title, description: message || "This can’t be undone.") }.compact do
      icon_tag("trash")
    end
  end

  # A quiet button for something destructive on a record's own page (delete, archive, deactivate),
  # asking first (layouts/shared/_confirm). d presses it (keys: nil for none). css: its classes,
  # when it isn't the quiet red one.
  def confirm_button(trigger:, title:, body:, button:, path:, method: nil, icon: nil, keys: "d", css: nil)
    button_to path, method: method || :delete, class: css || "btn btn--ghost btn--sm confirm-button", form: { data: { turbo_frame: "_top" } },
      data: { keys: keys, **confirm_data(title, description: body, button: button) }.compact do
      safe_join([ icon_tag(icon || "trash"), tag.span(trigger) ])
    end
  end
end
