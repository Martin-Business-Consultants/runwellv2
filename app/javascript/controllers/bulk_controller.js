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

  // A pill that copies text made from the picked rows (bulk_copy): its URL with each picked id
  // as ids[], fetched inside a ClipboardItem so Safari keeps the click's permission while it loads.
  // The same id picked twice (a row shown in two lists) goes once, in the order they're on the page.
  async copy(event) {
    const button = event.currentTarget
    const url = new URL(button.dataset.bulkCopyUrl, window.location.href)
    ;[ ...new Set(this.#picked.map(item => item.value)) ].forEach(id => url.searchParams.append("ids[]", id))
    button.classList.remove("bulk-bar__copied")

    const text = fetch(url, { headers: { Accept: "text/plain" }, credentials: "same-origin" })
      .then(response => { if (!response.ok) throw new Error(response.statusText); return response.text() })
    try {
      if (window.ClipboardItem && navigator.clipboard.write) {
        await navigator.clipboard.write([ new ClipboardItem({ "text/plain": text.then(t => new Blob([ t ], { type: "text/plain" })) }) ])
      } else {
        await navigator.clipboard.writeText(await text)
      }
      button.classList.add("bulk-bar__copied")
    } catch {}
  }

  get #picked() {
    return this.itemTargets.filter(item => item.checked)
  }
}
