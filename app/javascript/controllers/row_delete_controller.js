import { Controller } from "@hotwired/stimulus"

// One delete dialog per table (layouts/shared/_row_delete_dialog) rather than one in every row:
// a row's trash button (row_delete_button) names what goes, and this fills the dialog in, points
// its form at the record and opens it. Esc and the backdrop close it, as rune's dialogs do.
export default class extends Controller {
  static targets = [ "dialog", "title", "hint", "form" ]

  open({ params: { name, path, message } }) {
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

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
