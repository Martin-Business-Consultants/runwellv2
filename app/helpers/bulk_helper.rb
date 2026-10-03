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
            tag.button(type: "button", class: "btn txt-x-small bulk-bar__count", title: "Clear the selection", data: { action: "bulk#clear" }) do
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
      form_tag(path, method: method, class: "full-width") do
        tag.ul(class: "popup__list", role: "listbox") do
          safe_join(choices.map do |text, value|
            tag.li(class: "popup__item") do
              button_tag(type: "submit", name: name, value: value, class: "btn popup__btn", data: { action: "dialog#close" }) do
                tag.span(text, class: "overflow-ellipsis flex-item-grow")
              end
            end
          end)
        end
      end
    end
  end

  # A pill that does one thing (Close, Dismiss), with any fixed params.
  def bulk_button(path, method:, label:, params: {})
    form_tag(path, method: method, class: "display-contents") do
      safe_join(params.map { |key, value| hidden_field_tag(key, value, id: nil) } +
        [ button_tag(label, type: "submit", class: "btn input txt-x-small bulk-bar__pill") ])
    end
  end

  # A pill opening a date to set on every picked row; blank clears it.
  def bulk_date(path, method:, name:, label:)
    bulk_popup(label) do
      form_tag(path, method: method, class: "full-width") do
        tag.div(class: "popup__item flex align-center gap-half pad-inline-half") do
          safe_join([ date_input_tag(name, nil, class: "input txt-small", aria: { label: label }),
            button_tag("Set", type: "submit", class: "btn btn--link txt-small", data: { action: "dialog#close" }) ])
        end
      end
    end
  end

  # Delete, behind Fizzy's modal dialog: it says what goes, and asks once.
  def bulk_delete(path, noun:, message: nil)
    tag.div(class: "display-contents", data: { controller: "dialog", dialog_modal_value: true, action: "keydown.esc->dialog#close:stop" }) do
      safe_join([
        button_tag(type: "button", class: "btn txt-x-small txt-negative bulk-bar__delete", data: { action: "dialog#open" }) { safe_join([ icon_tag("trash"), tag.span("Delete") ]) },
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

  private
    # A quick filter's pill and popup, around whatever the popup holds.
    def bulk_popup(label, &block)
      tag.div(class: "quick-filter", data: { filter_show: true, controller: "dialog", action: "keydown.esc->dialog#close click@document->dialog#closeOnClickOutside" }) do
        safe_join([
          tag.button(type: "button", class: "btn input input--select flex-inline txt-x-small", data: { action: "click->dialog#toggle:stop" }) { tag.span(label, class: "overflow-ellipsis") },
          tag.dialog(class: "margin-block-start-half popup panel flex-column align-start gap-half fill-white shadow txt-small", aria: { label: label }, data: { dialog_target: "dialog" }) do
            safe_join([ tag.strong(label, class: "popup__title pad-inline-half"), capture(&block) ])
          end
        ])
      end
    end
end
