import { Controller } from "@hotwired/stimulus"

// Runwell: an in-place picker (a task's status or owner, a client's status) that shows the choice
// the moment it's made, while its form saves it; the answer then replaces the picker with what was
// saved (or puts it back, with the reason, if it was refused). Choices may live once on the page
// in a <template> (options value) and are copied into the menu when it first opens. With multiple
// (a task's owners, Fizzy's assignments), current lists every choice made, each click turns one on
// or off and the menu stays open; the answer replaces what shows beside it.
export default class extends Controller {
  static targets = [ "display", "list", "form" ]
  static values = { current: String, options: String, multiple: Boolean, popup: String, url: String, labelled: Boolean }

  // dialog:show: bring in the menu (if it isn't here yet) and the page's shared choices, marking
  // the current one.
  fill() {
    this.#materialize()
    if (!this.hasListTarget || !this.optionsValue || this.listTarget.children.length) return

    const template = document.getElementById(this.optionsValue)
    if (!template) return

    const current = this.multipleValue ? this.currentValue.split(",") : [ this.currentValue ]
    this.listTarget.append(template.content.cloneNode(true))
    this.listTarget.querySelectorAll("[data-picker-value]").forEach(item => {
      item.setAttribute("aria-checked", current.includes(item.dataset.pickerValue))
    })
  }

  // A row carries only an empty <dialog>: its insides are on the page once (popup value), copied
  // in the first time it opens, with the form pointed at this record (url value).
  #materialize() {
    if (!this.popupValue || this.hasFormTarget) return

    const template = document.getElementById(this.popupValue)
    const dialog = this.element.querySelector("dialog")
    if (!template || !dialog) return

    dialog.append(template.content.cloneNode(true))
    const form = dialog.querySelector("form")
    form.action = this.urlValue
    if (this.labelledValue) this.#hidden(form, "labelled", "1")

    // In a Tasks list (data-task-list: which list, its filter, the section in focus), the change
    // says so, and the answer brings that list back as it now stands.
    const list = this.element.closest("[data-task-list]")
    if (list) {
      this.#hidden(form, "list[kind]", list.dataset.taskList)
      if (list.dataset.taskListState) this.#hidden(form, "list[state]", list.dataset.taskListState)
      if (list.dataset.taskListItem) this.#hidden(form, "list[item]", list.dataset.taskListItem)
    }
  }

  #hidden(form, name, value) {
    const input = document.createElement("input")
    Object.assign(input, { type: "hidden", name, value })
    form.append(input)
  }

  // A choice was clicked: show it now; the form goes on to save it. The menu closes on
  // picker:chosen (data-action="picker:chosen->dialog#close").
  choose(event) {
    const option = event.currentTarget
    if (this.multipleValue) {
      const item = option.closest("[role=checkbox]")
      item?.setAttribute("aria-checked", item.getAttribute("aria-checked") !== "true")
      return
    }

    this.displayTargets.forEach(display => {
      const source = option.querySelector(`[data-picker-part="${display.dataset.pickerPart}"]`)
      if (source) display.replaceChildren(...Array.from(source.cloneNode(true).childNodes))
    })
    this.element.querySelectorAll("[role=checkbox]").forEach(item => item.setAttribute("aria-checked", item.contains(option)))
    setTimeout(() => this.dispatch("chosen"))
  }
}
