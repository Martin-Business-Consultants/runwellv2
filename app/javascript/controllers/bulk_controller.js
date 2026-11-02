import { Controller } from "@hotwired/stimulus"

// Runwell: picking table rows to act on together (BulkHelper, BulkAction). It sits on <main>, so it
// sees both the table's checkboxes and the index toolbar, where the bar takes the filters' place
// while any row is picked. Each action is a small form in the bar, sent with the picked ids added.
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

  // One of the bar's forms is about to go: carry the picked ids with it.
  include(event) {
    const form = event.target
    if (!this.hasBarTarget || !this.barTargets.some(bar => bar.contains(form))) return

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
    if (event.detail.success && this.barTargets.some(bar => bar.contains(event.target))) this.clear()
  }

  update() {
    const count = this.#picked.length
    const total = this.itemTargets.length
    this.element.toggleAttribute("data-bulk-active", count > 0)
    this.barTargets.forEach(bar => { bar.hidden = count === 0 })
    this.countTargets.forEach(target => { target.textContent = `${count} selected` })
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
