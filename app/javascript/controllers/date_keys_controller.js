import { Controller } from "@hotwired/stimulus"

// Runwell's key on every date (date_input, a ui :date_picker): t picks today (the install's
// today, from the server), in the calendar, or in the field while it's empty or all of it is
// selected (so typing "Oct" still types a t). The picker fires change as it would for a person,
// so a form that saves on change saves.
export default class extends Controller {
  static values = { today: String }

  connect() {
    this.key = this.key.bind(this)
    this.element.addEventListener("keydown", this.key)
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.key)
  }

  key(event) {
    if (event.key !== "t" && event.key !== "T") return
    if (event.metaKey || event.ctrlKey || event.altKey) return

    const field = event.target.closest("input")
    if (field && field.value !== "" && !(field.selectionStart === 0 && field.selectionEnd === field.value.length)) return

    event.preventDefault()
    this.element.api?.setValue(this.todayValue)
  }
}
