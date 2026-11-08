import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Template mode (RecordLayout, record_fields/arrange): an owner arranges a record page's fields for
// everyone. While arranging, every field (.layout-field) is a block that moves and its inputs go
// inert: drag it to another place or column (main, aside, or the bar's Hidden tray), or focus it
// and use the arrow keys (← → a column, ↑ ↓ its place, Delete hides it, Enter brings a hidden one
// back). Done sends each column's keys in order; Cancel and Esc put the page back as it was.
// A required field (data-layout-required) can't be hidden.
export default class extends Controller {
  static targets = [ "zone", "bar" ]
  static values = { url: String }

  toggle() {
    this.arranging ? this.cancel() : this.start()
  }

  start() {
    if (!this.hasBarTarget) return

    this.arranging = true
    this.element.classList.add("record-page--arranging")
    this.barTarget.hidden = false
    this.#fields.forEach(field => this.#arrangeable(field))
    this.#fields[0]?.focus()
  }

  cancel() {
    Turbo.visit(location.href, { action: "replace" })
  }

  async done() {
    const body = new FormData()
    this.zoneTargets.forEach(zone => {
      body.append(`layout[${zone.dataset.zone}][]`, "")
      this.#keys(zone).forEach(key => body.append(`layout[${zone.dataset.zone}][]`, key))
    })
    await this.#send("PATCH", body)
  }

  async reset() {
    await this.#send("DELETE")
  }

  // A custom field's "who sees it" (record_fields/visibility): saved to the field at once, and its
  // pill renamed, without leaving the arrangement.
  async saveVisibility(event) {
    const popover = event.target.closest("[popover]")
    const body = new FormData()
    body.append("inline", "1")
    popover.querySelectorAll("input[name]").forEach(input => {
      if (input.type === "hidden" || input.checked) body.append(input.name, input.value)
    })
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const response = await fetch(popover.dataset.url, { method: "PATCH", body, headers: { "X-CSRF-Token": token, Accept: "application/json" } })
    if (!response.ok) return alert("Who sees it couldn’t be saved. Try again.")

    const roles = Array.from(popover.querySelectorAll("input[type=checkbox][name]:checked")).map(input => input.value)
    const all = popover.querySelectorAll("input[type=checkbox][name]").length
    const label = roles.length === all ? "Everyone" : roles.length === 0 ? "Owners only" : `Owners and ${roles.map(role => `${role}s`).join(" and ")}`
    popover.closest("[data-layout-control]").querySelector("[data-visibility-label]").textContent = label
    popover.hidePopover()
  }

  // Dragging: the field follows the pointer into whichever column it's over, before the field
  // whose middle is below the pointer.
  dragstart(event) {
    this.dragged = event.target.closest(".layout-field")
    if (!this.arranging || !this.dragged) return

    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.dragged.dataset.layoutKey)
    requestAnimationFrame(() => this.dragged?.classList.add("layout-field--dragging"))
  }

  dragover(event) {
    const zone = event.target.closest("[data-record-layout-target~='zone']")
    if (!this.dragged || !zone || !this.#accepts(zone, this.dragged)) return

    event.preventDefault()
    const next = this.#fieldsIn(zone).find(field => field !== this.dragged && event.clientY < field.getBoundingClientRect().top + field.offsetHeight / 2)
    next ? zone.insertBefore(this.dragged, next) : zone.append(this.dragged)
  }

  drop(event) {
    if (this.dragged) event.preventDefault()
  }

  dragend() {
    this.dragged?.classList.remove("layout-field--dragging")
    this.dragged = null
  }

  keydown(event) {
    const field = event.target.closest(".layout-field")
    if (!this.arranging || !field || event.target !== field) return

    const zone = field.parentElement
    const zones = Object.fromEntries(this.zoneTargets.map(target => [ target.dataset.zone, target ]))
    switch (event.key) {
      case "ArrowUp": field.previousElementSibling?.before(field); break
      case "ArrowDown": field.nextElementSibling?.after(field); break
      case "ArrowLeft": if (zones.main && zone !== zones.main) zones.main.append(field); break
      case "ArrowRight": if (zones.aside && zone !== zones.aside) zones.aside.append(field); break
      case "Delete": case "Backspace": if (zones.hidden && this.#accepts(zones.hidden, field)) zones.hidden.append(field); break
      case "Enter": if (zone === zones.hidden && zones.main) zones.main.append(field); break
      default: return
    }
    event.preventDefault()
    event.stopPropagation()
    field.focus()
  }

  get #fields() {
    return this.zoneTargets.flatMap(zone => this.#fieldsIn(zone))
  }

  #fieldsIn(zone) {
    return Array.from(zone.querySelectorAll(".layout-field")).filter(field => field.parentElement === zone)
  }

  #keys(zone) {
    return this.#fieldsIn(zone).map(field => field.dataset.layoutKey)
  }

  #accepts(zone, field) {
    return !(zone.dataset.zone === "hidden" && field.dataset.layoutRequired)
  }

  #arrangeable(field) {
    field.draggable = true
    field.tabIndex = 0
    field.setAttribute("aria-roledescription", "movable field")
    field.setAttribute("aria-label", field.dataset.layoutLabel)
    this.#inert(field)
  }

  // Everything in a field goes inert while it's being moved, but its controls (who sees it).
  #inert(element) {
    Array.from(element.children).forEach(child => {
      if (child.matches("[data-layout-control]")) return
      child.querySelector("[data-layout-control]") ? this.#inert(child) : (child.inert = true)
    })
  }

  async #send(method, body) {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const response = await fetch(this.urlValue, { method, body, redirect: "manual", headers: { "X-CSRF-Token": token, Accept: "text/html" } })
    if (response.type === "opaqueredirect" || response.ok) {
      Turbo.visit(location.href, { action: "replace" })
    } else {
      alert("That arrangement couldn’t be saved. Try again.")
    }
  }
}
