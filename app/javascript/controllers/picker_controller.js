import { Controller } from "@hotwired/stimulus"

// Runwell: an in-place picker (a todo's status or owner, a client's status) that shows the choice
// the moment it's made, while its form saves it; the answer then replaces the picker with what was
// saved (or puts it back, with the reason, if it was refused). Choices may live once on the page
// in a <template> (options value) and are copied into the menu when it first opens.
export default class extends Controller {
  static targets = [ "display", "list" ]
  static values = { current: String, options: String }

  // dialog:show: bring in the page's shared choices, marking the current one.
  fill() {
    if (!this.hasListTarget || !this.optionsValue || this.listTarget.children.length) return

    const template = document.getElementById(this.optionsValue)
    if (!template) return

    this.listTarget.append(template.content.cloneNode(true))
    this.listTarget.querySelectorAll("[data-picker-value]").forEach(item => {
      item.setAttribute("aria-checked", item.dataset.pickerValue === this.currentValue)
    })
  }

  // A choice was clicked: show it now; the form goes on to save it.
  choose(event) {
    const option = event.currentTarget
    this.displayTargets.forEach(display => {
      const source = option.querySelector(`[data-picker-part="${display.dataset.pickerPart}"]`)
      if (source) display.replaceChildren(...Array.from(source.cloneNode(true).childNodes))
    })
    this.element.querySelectorAll("[role=checkbox]").forEach(item => item.setAttribute("aria-checked", item.contains(option)))
    setTimeout(() => this.application.getControllerForElementAndIdentifier(this.element, "dialog")?.close())
  }
}
