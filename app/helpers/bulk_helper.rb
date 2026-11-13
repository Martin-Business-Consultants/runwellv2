# Picking rows in a table and acting on them together (the bulk Stimulus controller on <main>,
# BulkAction): a checkbox column, and the bar that takes the index toolbar's place while any row is
# picked, in the toolbar's own language: a "3 selected" pill that clears, then each action as a pill
# opening a menu like a quick filter's, and Delete where the New button sits. Each action is its own
# small form; the controller adds the picked ids as it's sent.
module BulkHelper
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

  # The bar (for the index toolbar, via content_for :index_bulk): the count, the actions in the
  # block, and the destructive one (delete:) at the far end.
  def bulk_bar(delete: nil, &block)
    tag.div(class: "bulk-bar", hidden: true, data: { bulk_target: "bar" }, role: "region", aria: { label: "Act on the selected rows" }) do
      safe_join([
        tag.div(class: "bulk-bar__actions filters") do
          safe_join([
            tag.button(type: "button", class: "btn btn--secondary btn--sm bulk-bar__count", title: "Clear the selection", data: { action: "bulk#clear" }) do
              safe_join([ tag.span("", data: { bulk_target: "count" }, aria: { live: "polite" }), icon_tag("close") ])
            end,
            capture(&block)
          ])
        end,
        (tag.div(delete, class: "bulk-bar__end") if delete)
      ].compact)
    end
  end

  # A pill opening a menu of values for one field, like a quick filter; choosing one applies it to
  # every picked row. params: fixed ones sent with it (the list's filter, so the answer knows which
  # rows leave it).
  def bulk_menu(path, method:, name:, label:, choices:, params: {})
    bulk_popup(label) do
      form_tag(path, method: method, class: "popup__form") do
        safe_join(params.map { |key, value| hidden_field_tag(key, value, id: nil) }) +
        tag.ul(class: "popup__list", role: "listbox") do
          safe_join(choices.map do |text, value|
            tag.li(class: "popup__item") do
              button_tag(type: "submit", name: name, value: value, class: "popup__btn", data: { action: "dialog#close" }) do
                tag.span(text, class: "popup__label")
              end
            end
          end)
        end
      end
    end
  end

  # A pill that does one thing (Close, Dismiss), with any fixed params.
  def bulk_button(path, method:, label:, params: {})
    form_tag(path, method: method, class: "button_to") do
      safe_join(params.map { |key, value| hidden_field_tag(key, value, id: nil) } +
        [ button_tag(label, type: "submit", class: "pill bulk-bar__pill") ])
    end
  end

  # A pill opening a date to set on every picked row; blank clears it.
  def bulk_date(path, method:, name:, label:)
    bulk_popup(label) do
      form_tag(path, method: method, class: "popup__form") do
        tag.div(class: "popup__item popup__item--form") do
          safe_join([ date_input_tag(name, nil, class: "input--sm", aria: { label: label }),
            button_tag("Set", type: "submit", class: "btn btn--primary btn--sm", data: { action: "dialog#close" }) ])
        end
      end
    end
  end

  # A pill opening a line of text to send with the action (a reason, optional unless required:),
  # then its button: Decline with why, say.
  def bulk_text(path, method:, name:, label:, placeholder:, submit:, required: nil)
    bulk_popup(label) do
      form_tag(path, method: method, class: "popup__form") do
        tag.div(class: "popup__item popup__item--form") do
          safe_join([ text_field_tag(name, nil, class: "input--sm", placeholder: placeholder, required: required, autocomplete: "off", aria: { label: placeholder }),
            button_tag(submit, type: "submit", class: "btn btn--primary btn--sm", data: { action: "dialog#close" }) ])
        end
      end
    end
  end

  # Delete, once the page's confirm dialog says yes (ConfirmHelper): it says what goes, and asks once.
  def bulk_delete(path, noun:, message: nil)
    form_tag(path, method: :delete, class: "button_to") do
      button_tag(type: "submit", class: "btn btn--danger btn--sm bulk-bar__delete",
        data: confirm_data("Delete the selected #{noun}?", description: message || "This can’t be undone. Any that can’t be deleted are skipped and named.")) do
        safe_join([ icon_tag("trash"), tag.span("Delete") ])
      end
    end
  end

  private
    # A quick filter's pill and popup, around whatever the popup holds.
    def bulk_popup(label, &block)
      tag.div(class: "quick-filter", data: { filter_show: true, controller: "dialog", action: "keydown.esc->dialog#close click@document->dialog#closeOnClickOutside" }) do
        safe_join([
          tag.button(type: "button", class: "pill", aria: { haspopup: "menu" }, data: { action: "click->dialog#toggle:stop" }) do
            safe_join([ tag.span(label), icon_tag("caret-down") ])
          end,
          popup_menu(label: label, title: label, &block)
        ])
      end
    end
end
