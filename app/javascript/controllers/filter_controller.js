import { Controller } from "@hotwired/stimulus"
import { debounce } from "helpers/timing_helpers"
import { filterMatches, fuzzyMatches } from "helpers/text_helpers"

export default class extends Controller {
  static targets = [ "input", "item" ]
  static values = { fuzzy: Boolean }

  initialize() {
    this.filter = debounce(this.filter.bind(this), 100)
    this.searchRemotely = debounce(this.searchRemotely.bind(this), 250)
  }

  // Runwell: a page that came back filtered (?q=) shows its words in the field.
  connect() {
    if (!this.#remoteList || !this.hasInputTarget || this.inputTarget.value) return
    const query = new URL(window.location.href).searchParams.get("q")
    if (query) this.inputTarget.value = query
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
    if (this.#remoteList) this.searchRemotely()
  }

  // Runwell: on a paginated list (#main[data-filter-remote], set by ApplicationController#paginate)
  // the rows on screen are only its first pages, so the words also go to the server (?q=), whose
  // matches from every page replace the page's content, the address following along (Back and
  // refresh keep the filter). The field is in the nav, outside what's replaced, so typing goes on.
  async searchRemotely() {
    const main = this.#remoteList
    if (!main || !this.hasInputTarget) return

    const url = new URL(window.location.href)
    const query = this.inputTarget.value.trim()
    if ((url.searchParams.get("q") || "") === query) return

    query ? url.searchParams.set("q", query) : url.searchParams.delete("q")
    url.searchParams.delete("page")
    this.request?.abort()
    this.request = new AbortController()

    try {
      const response = await fetch(url, { headers: { Accept: "text/html" }, credentials: "same-origin", signal: this.request.signal })
      if (!response.ok) return

      const fresh = new DOMParser().parseFromString(await response.text(), "text/html").getElementById("main")
      if (!fresh) return

      main.replaceChildren(...fresh.childNodes)
      window.history.replaceState(window.history.state, "", url)
      this.dispatch("changed")
    } catch (error) {
      if (error.name !== "AbortError") throw error
    }
  }

  get #remoteList() {
    return this.element.id === "global-container" ? this.element.querySelector("#main[data-filter-remote]") : null
  }

  clearInput() {
    if (!this.hasInputTarget) return
    this.inputTarget.value = ""
    this.itemTargets.forEach(item => item.removeAttribute("hidden"))
    if (this.#remoteList) this.searchRemotely()
  }

  // Runwell: Enter in a combobox's search picks the first match still showing.
  chooseFirst(event) {
    event.preventDefault()
    const matches = this.fuzzyValue ? fuzzyMatches : filterMatches
    this.itemTargets.find(item => matches(item.textContent, this.inputTarget.value))?.querySelector("button, a")?.click()
  }
}
