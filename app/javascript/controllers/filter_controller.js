import { Controller } from "@hotwired/stimulus"
import { debounce } from "helpers/timing_helpers"
import { filterMatches, fuzzyMatches } from "helpers/text_helpers"

export default class extends Controller {
  static targets = [ "input", "item" ]
  static values = { fuzzy: Boolean }

  initialize() {
    this.filter = debounce(this.filter.bind(this), 100)
  }

  filter() {
    this.itemTargets.forEach(item => {
      if ((this.fuzzyValue ? fuzzyMatches : filterMatches)(item.textContent, this.inputTarget.value)) {
        item.removeAttribute("hidden")
      } else {
        item.toggleAttribute("hidden", true)
      }
    })

    this.dispatch("changed")
  }

  clearInput() {
    if (!this.hasInputTarget) return
    this.inputTarget.value = ""
    this.itemTargets.forEach(item => item.removeAttribute("hidden"))
  }

  // Runwell: Enter in a combobox's search picks the first match still showing.
  chooseFirst(event) {
    event.preventDefault()
    const matches = this.fuzzyValue ? fuzzyMatches : filterMatches
    this.itemTargets.find(item => matches(item.textContent, this.inputTarget.value))?.querySelector("button, a")?.click()
  }
}
