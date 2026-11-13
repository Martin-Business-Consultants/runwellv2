import { Controller } from "@hotwired/stimulus"

// Runwell: acting on the rows picked in a table (BulkHelper, BulkAction). Picking is runeui's
// (ui :table, selectable: true: its selection controller keeps the checkboxes, the header's mixed
// state, shift-ranges and the bar's count). This sits on <main> and does the sending: each action
// is a small form in the bar, sent with the picked ids added; the picked rows dim while it runs,
// and the selection clears once it worked.
//
// Plugins' pages pick rows as the plugin contract describes (to 7.0): native checkboxes marked
// data-bulk-target="item" (and "all"), with the bar in the index toolbar. For those this keeps the
// selection itself too: the legacy half below.
export default class extends Controller {
  static targets = [ "item", "all", "bar" ]

  connect() {
    this.update()
  }

  itemTargetConnected() {
    this.update()
  }

  itemTargetDisconnected() {
    this.update()
  }

  // A bulk menu's choice (ui :menu fires action with the item's value): into the form's field,
  // and the form goes.
  choose(event) {
    const form = event.currentTarget.closest("form")
    const field = form?.querySelector("[data-bulk-value]")
    if (!field) return

    field.value = event.detail.value
    form.requestSubmit()
  }

  // One of the bar's forms is about to go: carry the picked ids with it.
  include(event) {
    const form = event.target
    if (!this.#inBar(form)) return

    form.querySelectorAll("input[data-bulk-id]").forEach(input => input.remove())
    this.#picked.forEach(box => this.#carry(form, "ids[]", box.getAttribute("value")))

    // The table's list (data-task-list: which, and its filter), so the answer drops the rows the
    // change takes out of it (a task marked done leaves an Open list) rather than reloading.
    const list = document.querySelector("[data-task-list]")
    if (list) {
      this.#carry(form, "list[kind]", list.dataset.taskList)
      if (list.dataset.taskListState) this.#carry(form, "list[state]", list.dataset.taskListState)
    }
  }

  // It's on its way (turbo:submit-start: after the confirm dialog's yes, where a button asks
  // first): the picked rows dim while it runs; the answer redraws or removes them. A popover the
  // form sat in (a date, a reason) closes.
  pending(event) {
    if (!this.#inBar(event.target)) return

    this.#picked.forEach(box => box.closest("tr")?.classList.add("is-pending"))
    const popover = event.target.closest("ui-popover")
    if (popover) popover.open = false
  }

  // After an action, the page comes back with the same rows: start with none picked.
  // If it failed outright, the rows come back as they were, still picked.
  done(event) {
    if (!this.#inBar(event.target)) return

    this.element.querySelectorAll("tr.is-pending").forEach(row => row.classList.remove("is-pending"))
    if (event.detail.success) this.clear()
  }

  clear() {
    this.#selections.forEach(selection => selection.clear())
    this.itemTargets.forEach(item => { item.checked = false })
    this.update()
  }

  // ---- The legacy half: native checkboxes and a bar outside any runeui table (plugins).

  toggleAll() {
    const on = this.allTarget.checked
    this.itemTargets.forEach(item => { item.checked = on })
    this.update()
  }

  barTargetConnected(bar) {
    if (this.#legacy(bar)) bar.addEventListener("click", this.#clearFromBar)
  }

  barTargetDisconnected(bar) {
    bar.removeEventListener("click", this.#clearFromBar)
  }

  update() {
    const picked = this.itemTargets.filter(item => item.checked)
    this.element.toggleAttribute("data-bulk-active", picked.length > 0)
    this.barTargets.filter(bar => this.#legacy(bar)).forEach(bar => {
      bar.hidden = picked.length === 0
      const count = bar.querySelector("[data-slot='bulk-count']")
      if (count) count.textContent = `${picked.length} selected`
    })
    if (this.hasAllTarget) {
      this.allTarget.checked = picked.length > 0 && picked.length === this.itemTargets.length
      this.allTarget.indeterminate = picked.length > 0 && picked.length < this.itemTargets.length
    }
    this.itemTargets.forEach(item => item.closest("tr")?.setAttribute("aria-selected", String(item.checked)))
  }

  // ui :bulk_bar's Clear is wired to runeui's selection controller, which a legacy bar isn't in.
  #clearFromBar = (event) => {
    if (event.target.closest("[data-action~='runeui--selection#clear']")) this.clear()
  }

  #legacy(bar) {
    return !bar.closest("[data-controller~='runeui--selection']")
  }

  #inBar(form) {
    return Boolean(form.closest?.("[data-slot='bulk-bar']"))
  }

  #carry(form, name, value) {
    const input = document.createElement("input")
    Object.assign(input, { type: "hidden", name, value })
    input.dataset.bulkId = ""
    form.append(input)
  }

  // runeui's selection controllers on this page (one per selectable table).
  get #selections() {
    return [ ...this.element.querySelectorAll("[data-controller~='runeui--selection']") ]
      .map(element => this.application.getControllerForElementAndIdentifier(element, "runeui--selection")).filter(Boolean)
  }

  // Every picked row's checkbox: runeui's (ui :select_cell) and the legacy native ones.
  get #picked() {
    const rows = [ ...this.element.querySelectorAll("[data-runeui--selection-target~='row']") ].filter(box => box.checked)
    return [ ...rows, ...this.itemTargets.filter(item => item.checked) ]
  }
}
