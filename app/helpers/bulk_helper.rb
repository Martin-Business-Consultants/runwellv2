# Acting on the rows picked in a table (BulkAction): the bar and what goes in it, drawn with runeui
# (ui :bulk_bar, ui :menu, ui :popover, ui :date_picker, ui :button). An index hands its bar to its
# table (layouts/shared/_list_table, bulk:), where runeui's selection controller shows it with the
# count while rows are picked. Each action is a small form of its own; the bulk Stimulus controller
# on <main> adds the picked ids as it's sent (ids[]), dims the rows while it runs and clears the
# selection after.
#
# Plugins' pages still pick rows the way the plugin contract describes (to 7.0): a native checkbox
# per row (bulk_select_all_header, bulk_select_cell, or their own with data-bulk-target="item") and
# the bar in the index toolbar (content_for :index_bulk), both kept by the bulk controller itself.
module BulkHelper
  # For plugins' tables (the core's are ui :select_cell): the header's and a row's checkbox.
  def bulk_select_all_header
    tag.th(data: { slot: "table-select" }) do
      check_box_tag(nil, nil, false, id: nil, aria: { label: "Select every row on this page" },
        data: { bulk_target: "all", action: "bulk#toggleAll" })
    end
  end

  def bulk_select_cell(record, label)
    tag.td(data: { slot: "table-select" }) do
      check_box_tag(nil, record.id, false, id: nil, aria: { label: "Select #{label}" },
        data: { bulk_target: "item", action: "bulk#update", keys: "x" })
    end
  end

  # The bar: how many are picked and Clear (ui :bulk_bar's), the actions in the block, and the
  # destructive one (delete:) last.
  def bulk_bar(delete: nil, &block)
    actions = safe_join([ capture(&block), delete ].compact)
    ui :bulk_bar, content: actions, data: { bulk_target: "bar" }
  end

  # A button opening a menu of values for one field; choosing one applies it to every picked row
  # (the menu's action fills the form's field and sends it: bulk#choose). params: fixed ones sent
  # with it (the list's filter, so the answer knows which rows leave it).
  def bulk_menu(path, method:, name:, label:, choices:, params: {})
    form_tag(path, method: method, class: "bulk-form") do
      safe_join(params.map { |key, value| hidden_field_tag(key, value, id: nil) } + [
        hidden_field_tag(name, "", id: nil, data: { bulk_value: true }),
        ui(:menu, trigger: bulk_trigger(label), label: label, align: :start,
          items: choices.map { |text, value| { label: text, value: value.to_s } }, data: { action: "action->bulk#choose" })
      ])
    end
  end

  # A button that does one thing (Close, Dismiss), with any fixed params.
  def bulk_button(path, method:, label:, params: {})
    form_tag(path, method: method, class: "bulk-form") do
      safe_join(params.map { |key, value| hidden_field_tag(key, value, id: nil) } +
        [ ui(:button, variant: :outline, size: :sm, content: label, type: :submit) ])
    end
  end

  # A button opening a date to set on every picked row; blank clears it.
  def bulk_date(path, method:, name:, label:)
    bulk_popover(label) do
      form_tag(path, method: method, class: "bulk-form bulk-form--row") do
        safe_join([ hidden_field_tag(name, "", id: nil),
          ui(:date_picker, name: name, id: "bulk-#{name.parameterize}", size: :sm, clearable: true, aria: { label: label }),
          ui(:button, size: :sm, content: "Set", type: :submit) ])
      end
    end
  end

  # A button opening a line of text to send with the action (a reason, optional unless required:),
  # then its button: Decline with why, say.
  def bulk_text(path, method:, name:, label:, placeholder:, submit:, required: nil)
    bulk_popover(label) do
      form_tag(path, method: method, class: "bulk-form bulk-form--row") do
        safe_join([ ui(:input, name: name, id: "bulk-#{name.parameterize}", size: :sm, placeholder: placeholder, required: required, autocomplete: "off", aria: { label: placeholder }),
          ui(:button, size: :sm, content: submit, type: :submit) ])
      end
    end
  end

  # Delete, once the page's confirm dialog says yes (ConfirmHelper): it says what goes, and asks once.
  def bulk_delete(path, noun:, message: nil)
    form_tag(path, method: :delete, class: "bulk-form") do
      ui :button, variant: :destructive, size: :sm, type: :submit, content: safe_join([ icon_tag("trash"), "Delete" ]),
        data: confirm_data("Delete the selected #{noun}?", description: message || "This can’t be undone. Any that can’t be deleted are skipped and named.")
    end
  end

  private
    # What opens a bulk menu or popover: a small outline button, its caret after its name.
    def bulk_trigger(label)
      ui :button, variant: :outline, size: :sm, content: label, icon_end: "chevron-down", type: :button
    end

    def bulk_popover(label, &block)
      ui :popover, trigger: bulk_trigger(label), align: :start, content: capture(&block), data: { bulk_popover: true }
    end
end
