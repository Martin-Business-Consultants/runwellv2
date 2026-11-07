module RowActionsHelper
  # A table row's trash button: it opens the table's one delete dialog (row-delete controller,
  # layouts/shared/_row_delete_dialog) with what goes and where, and d clicks it on the row you're on.
  def row_delete_button(name:, path:, message: nil)
    title = "Delete #{name}?"
    tag.button(type: "button", class: "icon-button icon-button--danger row-action", title: title, aria: { label: title, haspopup: "dialog" },
      data: { keys: "d", action: "row-delete#open", row_delete_name_param: name, row_delete_path_param: path, row_delete_message_param: message }) do
      icon_tag("trash")
    end
  end
end
