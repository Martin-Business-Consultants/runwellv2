import { Controller } from "@hotwired/stimulus"

// Settings > Appearance (and Your account's text size): applies a choice to the page at once, then
// saves it. Each choice is a runeui radio group (settings/appearances/_choices), whose change
// arrives here from the form; its name is an attribute, its value the element's.
export default class extends Controller {
  preview({ target }) {
    if (!target.matches?.("ui-radio-group")) return
    const root = document.documentElement
    const key = target.getAttribute("name")?.match(/\[(\w+)\]/)?.[1]

    if (key === "theme") {
      // Picking the default here also drops your own sun/moon choice, so you see what you picked.
      try { localStorage.removeItem("theme") } catch {}
      root.dataset.defaultTheme = target.value
      if (target.value === "system") {
        root.removeAttribute("data-theme")
      } else {
        root.dataset.theme = target.value
      }
    } else if (key === "text_size" && !target.value) {
      // Your account: blank follows the install's default.
      root.dataset.textSize = this.element.dataset.installTextSize
    } else if (key) {
      root.dataset[key.replace(/_(\w)/g, (_, letter) => letter.toUpperCase())] = target.value
    }

    this.element.requestSubmit()
  }
}
