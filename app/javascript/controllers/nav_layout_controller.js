import { Controller } from "@hotwired/stimulus"

// Settings > Sidebar (NavLayout, settings/sidebars/show): arranging the nav for everyone, as
// template mode arranges a record's fields. Each page (.nav-editor__item, data-nav-key) drags to
// any section or the Hidden tray, or moves with the keys while focused: ↑ ↓ a place (into the
// section above or below at either end), Delete hides it, Enter brings a hidden one back. Sections
// are added from a template and removed with their pages moving up a section. Save sends every
// section's name and pages in order, and the hidden ones, as one PATCH the page answers.
export default class extends Controller {
  static targets = [ "sections", "section", "zone", "label", "template" ]
  static values = { url: String }

  // Dragging: the page follows the pointer into whichever list it's over, before the page whose
  // middle is below the pointer.
  dragstart(event) {
    this.dragged = event.target.closest?.(".nav-editor__item")
    if (!this.dragged) return

    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.dragged.dataset.navKey)
    requestAnimationFrame(() => this.dragged?.classList.add("nav-editor__item--dragging"))
  }

  dragover(event) {
    const zone = event.target.closest?.("[data-nav-layout-target~='zone']")
    if (!this.dragged || !zone) return

    event.preventDefault()
    const next = this.#itemsIn(zone).find(item => item !== this.dragged && event.clientY < item.getBoundingClientRect().top + item.offsetHeight / 2)
    next ? zone.insertBefore(this.dragged, next) : zone.append(this.dragged)
  }

  drop(event) {
    if (this.dragged) event.preventDefault()
  }

  dragend() {
    this.dragged?.classList.remove("nav-editor__item--dragging")
    this.dragged = null
  }

  keydown(event) {
    const item = event.target.closest?.(".nav-editor__item")
    if (!item || event.target !== item) return

    const zone = item.closest("[data-nav-layout-target~='zone']")
    const sections = this.#sectionZones
    const hidden = this.#hiddenZone
    const at = sections.indexOf(zone)
    const items = this.#itemsIn(zone)
    const place = items.indexOf(item)
    switch (event.key) {
      case "ArrowUp":
        if (place > 0) items[place - 1].before(item)
        else if (at > 0) sections[at - 1].append(item)
        break
      case "ArrowDown":
        if (place < items.length - 1) items[place + 1].after(item)
        else if (at >= 0 && at < sections.length - 1) sections[at + 1].prepend(item)
        break
      case "Delete": case "Backspace":
        if (zone !== hidden) hidden?.append(item)
        break
      case "Enter":
        if (zone === hidden) sections[0]?.append(item)
        break
      default: return
    }
    event.preventDefault()
    event.stopPropagation()
    item.focus()
  }

  addSection() {
    const section = this.templateTarget.content.firstElementChild.cloneNode(true)
    this.sectionsTarget.append(section)
    section.querySelector("[data-nav-layout-target~='label']")?.focus()
  }

  // A section goes, its pages moving to the one above (or below, for the first). The last one stays.
  removeSection(event) {
    const section = event.target.closest("[data-nav-layout-target~='section']")
    const sections = this.sectionTargets
    if (!section || sections.length < 2) return

    const index = sections.indexOf(section)
    const into = sections[index === 0 ? 1 : index - 1].querySelector("[data-nav-layout-target~='zone']")
    this.#itemsIn(section.querySelector("[data-nav-layout-target~='zone']")).forEach(item => into.append(item))
    section.remove()
  }

  // Sent as a form Turbo submits, so the answer's redirect and notice work as any form's.
  save() {
    const form = document.createElement("form")
    form.method = "post"
    form.action = this.urlValue
    form.hidden = true
    const add = (name, value) => {
      const input = document.createElement("input")
      Object.assign(input, { type: "hidden", name, value })
      form.append(input)
    }
    add("_method", "patch")
    add("authenticity_token", document.querySelector("meta[name='csrf-token']")?.content || "")
    this.sectionTargets.forEach((section, index) => {
      add(`sidebar[sections][${index}][label]`, section.querySelector("[data-nav-layout-target~='label']")?.value || "")
      add(`sidebar[sections][${index}][items][]`, "")
      this.#itemsIn(section.querySelector("[data-nav-layout-target~='zone']")).forEach(item => add(`sidebar[sections][${index}][items][]`, item.dataset.navKey))
    })
    add("sidebar[hidden][]", "")
    if (this.#hiddenZone) this.#itemsIn(this.#hiddenZone).forEach(item => add("sidebar[hidden][]", item.dataset.navKey))
    this.element.append(form)
    form.requestSubmit()
  }

  get #sectionZones() {
    return this.sectionTargets.map(section => section.querySelector("[data-nav-layout-target~='zone']"))
  }

  get #hiddenZone() {
    return this.zoneTargets.find(zone => zone.dataset.zone === "hidden")
  }

  // A list's pages, however deep (in development every rendered partial sits in a display: contents
  // span, so a page's parent isn't always its list).
  #itemsIn(zone) {
    return Array.from(zone?.querySelectorAll(".nav-editor__item") || [])
  }
}
