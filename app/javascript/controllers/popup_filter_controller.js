import { Controller } from "@hotwired/stimulus"
import { debounce } from "helpers/timing_helpers"
import { fuzzyMatches } from "helpers/text_helpers"

// Fizzy's filter controller, for the choices in one popup (a combobox's): typing hides the items
// that don't match. Named apart from Runwell's filter controller, which is the page's "/" filter.
export default class extends Controller {
  static targets = [ "input", "item" ]

  initialize() {
    this.filter = debounce(this.filter.bind(this), 100)
  }

  filter() {
    this.itemTargets.forEach(item => {
      item.toggleAttribute("hidden", !fuzzyMatches(item.textContent, this.inputTarget.value))
    })

    this.dispatch("changed", { detail: { value: this.inputTarget.value } })
  }

  clearInput() {
    if (!this.hasInputTarget) return
    this.inputTarget.value = ""
    this.itemTargets.forEach(item => item.removeAttribute("hidden"))
  }
}
