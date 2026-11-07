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
  # every picked row.
  def bulk_menu(path, method:, name:, label:, choices:)
    bulk_popup(label) do
      form_tag(path, method: method, class: "popup__form") do
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

  # Delete, behind a dialog (rune_ui's): it says what goes, and asks once.
  def bulk_delete(path, noun:, message: nil)
    title = "Delete the selected #{noun}?"
    tag.div(class: "dialog-wrap", data: { controller: "rune-dialog", action: "keydown.esc->rune-dialog#close:stop" }) do
      safe_join([
        button_tag(type: "button", class: "btn btn--danger btn--sm bulk-bar__delete", aria: { haspopup: "dialog" }, data: { action: "rune-dialog#open" }) { safe_join([ icon_tag("trash"), tag.span("Delete") ]) },
        tag.dialog(class: "dialog", aria: { label: title }, data: { rune_dialog_target: "dialog", action: "click->rune-dialog#backdrop" }) do
          tag.div(class: "dialog__box") do
            safe_join([
              tag.header(tag.h2(title, class: "dialog__title"), class: "dialog__header"),
              tag.div(class: "dialog__body") do
                safe_join([
                  tag.p(message || "This can’t be undone. Any that can’t be deleted are skipped and named.", class: "dialog__hint"),
                  tag.div(class: "dialog__actions") do
                    safe_join([
                      button_tag("Cancel", type: "button", class: "btn btn--ghost", data: { action: "rune-dialog#close" }),
                      form_tag(path, method: :delete, class: "button_to") { button_tag(type: "submit", class: "btn btn--danger") { safe_join([ icon_tag("trash"), tag.span("Delete") ]) } }
                    ])
                  end
                ])
              end
            ])
          end
        end
      ])
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
