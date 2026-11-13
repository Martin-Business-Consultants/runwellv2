module RowActionsHelper
  # A table row's trash button, for a record removed at once with Undo in the toast (a task:
  # PendingRemoval), not behind a question. d presses it on the row you're on. The row fades as it
  # goes (row-delete#leave) and comes back if the removal is refused. The form carries no token of
  # its own (Turbo sends the page's), so a long table's rows stay light.
  def row_remove_button(name:, path:)
    title = "Remove #{name}"
    button_to path, method: :delete, params: { inline: "row" }, authenticity_token: false,
      class: "ui-button danger-button row-action", title: title, aria: { label: title }, data: { variant: "ghost", size: "icon-sm", keys: "d" },
      form: { class: "row-action-form", data: { turbo_frame: "_top", action: "turbo:submit-start->row-delete#leave turbo:submit-end->row-delete#settle" } } do
      icon_tag("trash")
    end
  end

  # The same for a record whose delete asks first: the question is the button's
  # (data-turbo-confirm, ConfirmHelper), asked in the page's one dialog, so the table carries no
  # dialog of its own. Yes sends inline=row, and the answer removes the row in place.
  def row_delete_button(name:, path:, message: nil)
    title = "Delete #{name}?"
    button_to path, method: :delete, params: { inline: "row" }, authenticity_token: false,
      class: "ui-button danger-button row-action", title: title, aria: { label: title },
      data: { variant: "ghost", size: "icon-sm", keys: "d", **confirm_data(title, description: message || "This can’t be undone.") },
      form: { class: "row-action-form", data: { turbo_frame: "_top", action: "turbo:submit-start->row-delete#leave turbo:submit-end->row-delete#settle" } } do
      icon_tag("trash")
    end
  end
end
