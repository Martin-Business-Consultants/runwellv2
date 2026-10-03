# Picking rows in a table and acting on them together (the bulk Stimulus controller, BulkAction):
# a checkbox column, and the bar of actions that shows while any are picked. Each action is its own
# small form; the controller adds the picked ids as it's sent.
module BulkHelper
  # The table's section carries the controller; the bar and the table both sit inside it.
  def bulk_data = { controller: "bulk", action: "submit->bulk#include turbo:submit-end->bulk#done" }

  def bulk_select_all_header
    tag.th(class: "data-table__select") do
      check_box_tag(nil, nil, false, id: nil, class: "data-table__checkbox", aria: { label: "Select every row on this page" },
        data: { bulk_target: "all", action: "bulk#toggleAll" })
    end
  end

  def bulk_select_cell(record, label)
    tag.td(class: "data-table__select") do
      check_box_tag(nil, record.id, false, id: nil, class: "data-table__checkbox", aria: { label: "Select #{label}" },
        data: { bulk_target: "item", action: "bulk#update", keys: "x" })
    end
  end

  # The bar: how many are picked, the actions given in the block, and Clear.
  def bulk_bar(&block)
    tag.div(class: "bulk-bar", hidden: true, data: { bulk_target: "bar" }, role: "region", aria: { label: "Act on the selected rows" }) do
      safe_join([
        tag.strong("", class: "bulk-bar__count", data: { bulk_target: "count" }, aria: { live: "polite" }),
        tag.div(class: "bulk-bar__actions", &block),
        tag.button("Clear", type: "button", class: "btn btn--plain txt-small", data: { action: "bulk#clear" })
      ])
    end
  end

  # A menu of values for one field; choosing one applies it to every picked row.
  def bulk_choice(path, method:, name:, label:, choices:)
    form_tag(path, method: method, class: "bulk-bar__form", data: { controller: "form" }) do
      select_tag(name, options_for_select(choices), prompt: label, class: "input input--select txt-small", aria: { label: label },
        data: { action: "change->form#submit" })
    end
  end

  # One button for one action, with any fixed params (resolution: "done").
  def bulk_button(path, method:, label:, icon: nil, params: {})
    form_tag(path, method: method, class: "bulk-bar__form") do
      safe_join(params.map { |key, value| hidden_field_tag(key, value, id: nil) } +
        [ button_tag(type: "submit", class: "btn txt-small") { safe_join([ (icon_tag(icon) if icon), tag.span(label) ].compact) } ])
    end
  end

  # A date for one field, with Set; blank clears it.
  def bulk_date(path, method:, name:, label:)
    form_tag(path, method: method, class: "bulk-bar__form") do
      safe_join([ date_input_tag(name, nil, class: "input txt-small", aria: { label: label }),
        button_tag(label, type: "submit", class: "btn txt-small") ])
    end
  end

  # Delete, behind Fizzy's modal dialog: it says what goes, and asks once.
  def bulk_delete(path, noun:, message: nil)
    tag.div(class: "display-contents", data: { controller: "dialog", dialog_modal_value: true, action: "keydown.esc->dialog#close:stop" }) do
      safe_join([
        button_tag(type: "button", class: "btn txt-small txt-negative", data: { action: "dialog#open" }) { safe_join([ icon_tag("trash"), tag.span("Delete") ]) },
        tag.dialog(class: "dialog dialog--action panel fill-white shadow gap flex-column txt-align-start", data: { dialog_target: "dialog" }) do
          safe_join([
            tag.h3("Delete the selected #{noun}?", class: "dialog__title"),
            tag.p(message || "This can’t be undone. Any that can’t be deleted are skipped and named.", class: "dialog__message"),
            tag.div(class: "dialog__actions") do
              safe_join([
                button_tag("Cancel", type: "button", class: "btn", data: { action: "dialog#close" }),
                form_tag(path, method: :delete, class: "display-contents") { button_tag(type: "submit", class: "btn txt-negative") { safe_join([ icon_tag("trash"), tag.span("Delete") ]) } }
              ])
            end
          ])
        end
      ])
    end
  end
end
