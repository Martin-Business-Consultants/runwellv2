import { Controller } from "@hotwired/stimulus"

// Runwell: something added that shows the moment it's sent, before the server answers (a task typed
// into a section's quick add, a note from the composer). On submit it copies a <template> the
// server rendered (template value: its id; tasks/_pending, notes/_pending), puts what was typed in
// its [data-pending-text], and adds it to the list (list value, inside the closest scope value),
// dimmed. The answer replaces the list, the pending one with it; if the save fails or is refused,
// it's taken away again (the answer's toast says why).
export default class extends Controller {
  static values = { template: String, scope: String, list: String, field: String, prepend: Boolean }

  show() {
    const template = document.getElementById(this.templateValue)
    const list = this.element.closest(this.scopeValue)?.querySelector(this.listValue)
    const text = this.#text()
    if (!template || !list || !text) return

    this.pending = template.content.firstElementChild.cloneNode(true)
    this.pending.querySelector("[data-pending-text]").textContent = text
    this.prependValue ? list.prepend(this.pending) : list.append(this.pending)
  }

  settle(event) {
    if (!event.detail.success) this.pending?.remove()
    this.pending = null
  }

  // What was typed, as plain text: a field's value, or rich text's words (parsed in a document of
  // its own, so nothing in it runs).
  #text() {
    const field = this.element.querySelector(this.fieldValue)
    if (!field) return ""
    if (field.localName !== "lexxy-editor") return field.value.trim()

    return new DOMParser().parseFromString(field.value || "", "text/html").body.textContent.trim()
  }
}
