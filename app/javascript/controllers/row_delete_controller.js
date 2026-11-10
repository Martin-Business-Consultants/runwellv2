import { Controller } from "@hotwired/stimulus"

// One delete dialog per table (layouts/shared/_row_delete_dialog) rather than one in every row:
// a row's trash button (row_delete_button) names what goes, and this fills the dialog in, points
// its form at the record and opens it. Esc and the backdrop close it, as rune's dialogs do. Once
// Delete is pressed the row fades at once; the answer removes it, or a refusal brings it back.
export default class extends Controller {
  static targets = [ "dialog", "title", "hint", "form" ]

  open({ target, params: { name, path, message } }) {
    this.row = target.closest("tr")
    const title = `Delete ${name}?`
    this.titleTarget.textContent = title
    this.dialogTarget.setAttribute("aria-label", title)
    this.hintTarget.textContent = message || "This can’t be undone."
    this.formTarget.action = path
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  // turbo:submit-start on the dialog's form
  leave() {
    this.close()
    this.row?.classList.add("is-leaving")
  }

  // A row removed at once (row_remove_button, Undo in the toast): it fades as it goes, and comes back
  // if the removal is refused.
  leaveRow({ target }) {
    target.closest("tr")?.classList.add("is-leaving")
  }

  settleRow({ target, detail }) {
    if (!detail.success) target.closest("tr")?.classList.remove("is-leaving")
  }

  // turbo:submit-end: refused or failed, the row comes back
  settle(event) {
    if (!event.detail.success) this.row?.classList.remove("is-leaving")
    this.row = null
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
