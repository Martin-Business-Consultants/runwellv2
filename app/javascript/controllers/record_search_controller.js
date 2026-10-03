import { Controller } from "@hotwired/stimulus"
import { debounce } from "helpers/timing_helpers"

// Runwell: a record picker (quick_actions/picker) that asks the server as you type instead of
// carrying every record: the list's frame is pointed at the search with what was typed, and goes
// back to its starting few when the picker closes.
export default class extends Controller {
  static targets = [ "input", "frame" ]
  static values = { url: String }

  initialize() {
    this.search = debounce(this.search.bind(this), 150)
  }

  search() {
    const url = new URL(this.urlValue, window.location.href)
    url.searchParams.set("q", this.inputTarget.value.trim())
    this.frameTarget.src = url.toString()
  }

  // Enter picks the first match.
  chooseFirst() {
    this.frameTarget.querySelector("[role=checkbox] button")?.click()
  }

  reset() {
    if (!this.inputTarget.value) return

    this.inputTarget.value = ""
    this.search()
  }
}
