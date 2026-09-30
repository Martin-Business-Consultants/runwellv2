import { Controller } from "@hotwired/stimulus"

// Collapses the left nav ([) and a record page's details sidebar (]) for more room. The choice
// is this browser's, kept in localStorage, and set on <html> before the first paint
// (layouts/_theme_preference), so it holds across pages without a flicker.
export default class extends Controller {
  connect() {
    this.#sync("sidenav")
    this.#sync("sidebar")
  }

  toggleNav() {
    this.#toggle("sidenav")
  }

  toggleSidebar() {
    this.#toggle("sidebar")
  }

  #toggle(pane) {
    const root = document.documentElement
    const collapse = root.dataset[pane] !== "collapsed"

    if (collapse) {
      root.dataset[pane] = "collapsed"
    } else {
      delete root.dataset[pane]
    }

    try {
      collapse ? localStorage.setItem(pane, "collapsed") : localStorage.removeItem(pane)
    } catch {}

    this.#sync(pane)
  }

  #sync(pane) {
    const expanded = document.documentElement.dataset[pane] !== "collapsed"
    document.querySelectorAll(`[data-pane="${pane}"]`).forEach(button => button.setAttribute("aria-expanded", expanded))
  }
}
