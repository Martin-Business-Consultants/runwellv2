import { Controller } from "@hotwired/stimulus"

// Settings > Appearance: applies a choice to the page at once, then saves it.
export default class extends Controller {
  preview({ target }) {
    const root = document.documentElement
    const key = target.name.match(/\[(\w+)\]/)?.[1]

    if (key === "theme") {
      // Picking the default here also drops your own sun/moon choice, so you see what you picked.
      try { localStorage.removeItem("theme") } catch {}
      root.dataset.defaultTheme = target.value
      if (target.value === "system") {
        root.removeAttribute("data-theme")
      } else {
        root.dataset.theme = target.value
      }
    } else if (key) {
      root.dataset[key] = target.value
    }

    this.element.requestSubmit()
  }
}
