import { Controller } from "@hotwired/stimulus"

// A list of rows a person adds to and takes from inside a form (nested attributes, key/value
// pairs). Add copies the template, its placeholder swapped for a fresh index; Remove takes a new
// row away, and hides a saved one and sets its _destroy so the save deletes it. Repeaters nest:
// give each its own placeholder.
//
// Deprecated in 2.29, gone in 3.0: the core doesn't use it. A plugin ships its own controller
// (docs/plugin-contract.md, Plugin JavaScript); this says so once in the console.
let warned = false

export default class extends Controller {
  static targets = [ "list", "template" ]

  connect() {
    if (warned) return
    warned = true
    console.warn("Runwell: the core's repeater controller is deprecated since 2.29 and goes in 3.0. Ship your own in app/javascript/<key>/controllers.")
  }
  static values = { placeholder: { type: String, default: "NEW_ROW" } }

  #added = 0

  add(event) {
    event.preventDefault()
    const index = `${Date.now()}${this.#added++}`
    this.listTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML.replaceAll(this.placeholderValue, index))
    this.listTarget.lastElementChild?.querySelector("input:not([type=hidden]), textarea, select")?.focus()
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-repeater-row]")
    const destroy = row?.querySelector(":scope input[name$='[_destroy]']")

    if (destroy) {
      destroy.value = "1"
      row.hidden = true
    } else {
      row?.remove()
    }
  }
}
