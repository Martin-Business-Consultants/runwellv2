import { Controller } from "@hotwired/stimulus"

// Runwell: picking rows in a table to act on together (layouts/shared/bulk_bar, BulkAction).
// Each row's checkbox is an item; the header's selects every row on the page. While any are
// picked, the bar shows how many and its actions; each action's form is sent with the picked
// ids added. Rows that arrive later (the next page) join in.
export default class extends Controller {
  static targets = [ "item", "all", "bar", "count" ]

  connect() {
    this.update()
  }

  itemTargetConnected() {
    this.update()
  }

  itemTargetDisconnected() {
    this.update()
  }

  toggleAll() {
    const on = this.allTarget.checked
    this.itemTargets.forEach(item => { item.checked = on })
    this.update()
  }

  clear() {
    this.itemTargets.forEach(item => { item.checked = false })
    this.update()
  }

  // A form in the bar is about to go: carry the picked ids with it.
  include(event) {
    const form = event.target
    form.querySelectorAll("input[data-bulk-id]").forEach(input => input.remove())
    this.#picked.forEach(item => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "ids[]"
      input.value = item.value
      input.dataset.bulkId = ""
      form.append(input)
    })
  }

  // After an action, the page comes back with the same rows: start with none picked.
  done(event) {
    if (event.detail.success) this.clear()
  }

  update() {
    if (!this.hasBarTarget) return

    const count = this.#picked.length
    const total = this.itemTargets.length
    this.barTarget.hidden = count === 0
    if (this.hasCountTarget) this.countTarget.textContent = `${count} selected`
    if (this.hasAllTarget) {
      this.allTarget.checked = count > 0 && count === total
      this.allTarget.indeterminate = count > 0 && count < total
    }
    this.itemTargets.forEach(item => item.closest("tr")?.toggleAttribute("data-picked", item.checked))
  }

  get #picked() {
    return this.itemTargets.filter(item => item.checked)
  }
}
