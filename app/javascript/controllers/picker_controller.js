import { Controller } from "@hotwired/stimulus"

// Runwell: an in-place picker (a task's status or owner, a client's status) that shows the choice
// the moment it's made, while its form saves it; the answer then replaces the picker with what was
// saved (or puts it back, with the reason, if it was refused). Choices may live once on the page
// in a <template> (options value) and are copied into the menu when it first opens. With multiple
// (a task's owners, Fizzy's assignments), current lists every choice made, each click turns one on
// or off and the menu stays open; the avatars and names beside it (stack, empty and names targets)
// change at once from each choice's own avatar, and the answer then replaces them.
//
// A task's status (task value) in a list that won't keep it (marked done in an Open list, the rule
// Task::List#shows? keeps on the server) fades its row at once; the answer then removes it. If the
// save fails outright (no answer, or an error), the choice is put back.
export default class extends Controller {
  static targets = [ "display", "list", "form", "stack", "empty", "names" ]
  static values = { current: String, options: String, multiple: Boolean, popup: String, url: String, labelled: Boolean, task: String }

  connect() {
    this.confirmed = this.currentValue
    this.submitted = this.submitted.bind(this)
    this.element.addEventListener("turbo:submit-end", this.submitted)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.submitted)
  }

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
    // says so, and the answer brings that list back as it now stands. From the side panel, which
    // sits in no list, it's the list on the page underneath (one per page), and it says it came
    // from the panel: a task that leaves the list closes the panel too.
    const panel = this.element.closest(".task-panel")
    const list = this.element.closest("[data-task-list]") || (panel && document.querySelector("[data-task-list]"))
    if (panel) this.#hidden(form, "panel", "1")
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
      if (!item) return

      const on = item.getAttribute("aria-checked") !== "true"
      const chosen = this.#chosen.filter(id => id !== item.dataset.pickerValue)
      if (on) chosen.push(item.dataset.pickerValue)
      this.#show(chosen)
      return
    }

    this.#display(option)
    this.#leaving(option.closest("[data-picker-value]")?.dataset.pickerValue)
    setTimeout(() => this.dispatch("chosen"))
  }

  // The save is answered: keep what it said, or, when it failed (no answer, or an error page), put
  // back what was there. A refusal is an answer: its stream redraws the picker as it was.
  submitted({ detail: { success } }) {
    if (success) {
      this.confirmed = this.currentValue
    } else if (this.multipleValue) {
      this.#show(this.confirmed.split(",").filter(Boolean))
    } else {
      const option = this.hasListTarget && this.listTarget.querySelector(`[data-picker-value="${this.currentValue}"] button`)
      if (option) this.#display(option)
      this.#leavingRow?.classList.remove("task-leaving")
    }
  }

  get #chosen() {
    return this.currentValue.split(",").filter(Boolean)
  }

  #display(option) {
    this.displayTargets.forEach(display => {
      const source = option.querySelector(`[data-picker-part="${display.dataset.pickerPart}"]`)
      if (source) display.replaceChildren(...Array.from(source.cloneNode(true).childNodes))
    })
    this.element.querySelectorAll("[role=checkbox]").forEach(item => item.setAttribute("aria-checked", item.contains(option)))
  }

  // Who's on it, in order (the first leads): ticked in the menu, and drawn in the trigger the way
  // task_owners_tag draws them (three avatars, then +N), from each person's avatar template.
  #show(chosen) {
    this.currentValue = chosen.join(",")
    if (!this.hasListTarget) return

    this.listTarget.querySelectorAll("[data-picker-value]").forEach(item => item.setAttribute("aria-checked", chosen.includes(item.dataset.pickerValue)))
    const people = chosen.map(id => this.listTarget.querySelector(`[data-picker-value="${id}"]`)).filter(Boolean)

    if (this.hasStackTarget) {
      const stack = document.createElement("span")
      stack.className = "avatar-stack owner-stack"
      stack.setAttribute("aria-hidden", "true")
      people.slice(0, 3).forEach(person => {
        const avatar = person.querySelector("template[data-picker-avatar]")
        if (avatar) stack.append(avatar.content.cloneNode(true))
      })
      if (people.length > 3) {
        const more = document.createElement("span")
        more.className = "avatar avatar--md avatar--more"
        more.textContent = `+${people.length - 3}`
        stack.append(more)
      }
      this.stackTarget.replaceChildren(...(people.length ? [ stack ] : []))
    }
    if (this.hasEmptyTarget) this.emptyTarget.hidden = people.length > 0
    if (this.hasNamesTarget) {
      const names = people.map(person => person.querySelector(".popup__label")?.textContent.trim()).filter(Boolean)
      this.namesTarget.textContent = names.length ? new Intl.ListFormat("en", { type: "conjunction" }).format(names) : "Unassigned"
    }
  }

  // A task's new status, in a list that won't keep it: its row fades at once, and the answer removes
  // it. From the side panel, that's the row of the list underneath.
  #leaving(status) {
    if (!this.taskValue || !status || status === this.currentValue) return

    const panel = this.element.closest(".task-panel")
    const list = this.element.closest("[data-task-list]") || (panel && document.querySelector("[data-task-list]"))
    if (!list || this.#keeps(list.dataset.taskListState || "open", status)) return

    const row = panel ? (document.getElementById(`row_task_${this.taskValue}`) || document.getElementById(`item_task_${this.taskValue}`))
      : this.element.closest("[data-filter-target~=item]")
    row?.classList.add("task-leaving")
    this.#leavingRow = row
  }

  // Task::List#shows?, for the list's filter.
  #keeps(state, status) {
    if (state === "all") return true
    if (state === "open") return status !== "done"
    if (state === "done") return status === "done"
    return status === state
  }

  #leavingRow = null
}
