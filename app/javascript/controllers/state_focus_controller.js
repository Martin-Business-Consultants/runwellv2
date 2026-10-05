import { Controller } from "@hotwired/stimulus"
import { useState } from "reactionview"

// A form that ReActionView state shows in place (Mark complete, Discard draft, Triage) focuses its
// autofocus field once it shows, which browsers do only on page load. The guide's useState
// pattern: the state is named by data-state-focus-state-value.
export default class extends Controller {
  static values = { state: String }

  connect() {
    useState(this)
    this.stopListening = this.state.on(this.stateValue, () => requestAnimationFrame(() => this.#focus()))
  }

  disconnect() {
    this.stopListening?.()
  }

  #focus() {
    Array.from(this.element.querySelectorAll("[autofocus]")).find(field => !field.closest("[hidden]"))?.focus()
  }
}
