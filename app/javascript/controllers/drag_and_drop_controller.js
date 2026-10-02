import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"
import { nextFrame } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = [ "item", "container" ]
  static classes = [ "draggedItem", "hoverContainer" ]

  // Actions

  async dragStart(event) {
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.dropEffect = "move"
    event.dataTransfer.setData("37ui/move", event.target)

    await nextFrame()
    this.dragItem = this.#itemContaining(event.target)
    this.sourceContainer = this.#containerContaining(this.dragItem)
    this.originalPlace = { parent: this.dragItem.parentElement, next: this.dragItem.nextElementSibling }
    this.originalDraggedItemCssVariable = this.#containerCssVariableFor(this.sourceContainer)
    this.dragItem.classList.add(this.draggedItemClass)
  }

  dragOver(event) {
    event.preventDefault()
    if (!this.dragItem) { return }

    const container = this.#containerContaining(event.target)
    this.#clearContainerHoverClasses()

    if (!container) { return }

    if (container !== this.sourceContainer) {
      container.classList.add(this.hoverContainerClass)
      this.#applyContainerCssVariableToDraggedItem(container)
    } else {
      this.#restoreOriginalDraggedItemCssVariable()
    }

    this.#placeAtPointer(container, event.clientY)
  }

  async drop(event) {
    const targetContainer = this.#containerContaining(event.target)
    if (!targetContainer) { return }

    if (targetContainer === this.sourceContainer) {
      if (!this.#isSortable(targetContainer) || !this.#moved()) { return }

      this.wasDropped = true
      await this.#submitDropRequest(this.dragItem, targetContainer)
      return
    }

    this.wasDropped = true
    this.#increaseCounter(targetContainer)
    this.#decreaseCounter(this.sourceContainer)

    const sourceContainer = this.sourceContainer
    if (!this.#placedIn(targetContainer)) { this.#insertDraggedItem(targetContainer, this.dragItem) }
    await this.#submitDropRequest(this.dragItem, targetContainer)
    this.#reloadSourceFrame(sourceContainer)
  }

  dragEnd() {
    this.dragItem.classList.remove(this.draggedItemClass)
    this.#clearContainerHoverClasses()

    if (!this.wasDropped) {
      this.#restoreOriginalDraggedItemCssVariable()
      this.#restoreOriginalPlace()
    }

    this.originalPlace = null
    this.sourceContainer = null
    this.dragItem = null
    this.wasDropped = false
    this.originalDraggedItemCssVariable = null
  }

  // Runwell: cards can be ordered within a sortable column (data-drag-and-drop-sortable). While
  // dragging over one, the card moves to where it would land; the drop then sends the card it
  // now sits before, so the server places it there.
  #isSortable(container) {
    return container.hasAttribute("data-drag-and-drop-sortable")
  }

  #placeAtPointer(container, y) {
    if (!this.#isSortable(container)) { return }

    const itemContainer = container.querySelector("[data-drag-drop-item-container]")
    if (!itemContainer || itemContainer.offsetParent === null) { return }

    const items = [ ...itemContainer.querySelectorAll("[data-drag-and-drop-target~=item]") ].filter(item => item !== this.dragItem)
    const next = items.find(item => {
      const box = item.getBoundingClientRect()
      return y < box.top + box.height / 2
    })

    if (next) {
      if (next.previousElementSibling !== this.dragItem) { next.before(this.dragItem) }
    } else if (items.length) {
      if (items.at(-1).nextElementSibling !== this.dragItem) { items.at(-1).after(this.dragItem) }
    } else {
      itemContainer.append(this.dragItem)
    }
  }

  #placedIn(container) {
    return this.#isSortable(container) && container.contains(this.dragItem)
  }

  #moved() {
    const { parent, next } = this.originalPlace || {}
    return this.dragItem.parentElement !== parent || this.dragItem.nextElementSibling !== next
  }

  #restoreOriginalPlace() {
    const { parent, next } = this.originalPlace || {}
    if (!parent || !this.#moved()) { return }

    next?.isConnected ? next.before(this.dragItem) : parent.append(this.dragItem)
  }

  #nextItemId(item) {
    let sibling = item.nextElementSibling
    while (sibling && !sibling.matches("[data-drag-and-drop-target~=item]")) { sibling = sibling.nextElementSibling }
    return sibling?.dataset.id || ""
  }

  #itemContaining(element) {
    return this.itemTargets.find(item => item.contains(element) || item === element)
  }

  #containerContaining(element) {
    return this.containerTargets.find(container => container.contains(element) || container === element)
  }

  #clearContainerHoverClasses() {
    this.containerTargets.forEach(container => container.classList.remove(this.hoverContainerClass))
  }

  #applyContainerCssVariableToDraggedItem(container) {
    const cssVariable = this.#containerCssVariableFor(container)
    if (cssVariable) {
      this.dragItem.style.setProperty(cssVariable.name, cssVariable.value)
    }
  }

  #restoreOriginalDraggedItemCssVariable() {
    if (this.originalDraggedItemCssVariable) {
      const { name, value } = this.originalDraggedItemCssVariable
      this.dragItem.style.setProperty(name, value)
    }
  }

  #containerCssVariableFor(container) {
    const { dragAndDropCssVariableName, dragAndDropCssVariableValue } = container.dataset
    if (dragAndDropCssVariableName && dragAndDropCssVariableValue) {
      return { name: dragAndDropCssVariableName, value: dragAndDropCssVariableValue }
    }
    return null
  }

  #increaseCounter(container) {
    this.#modifyCounter(container, count => count + 1)
  }

  #decreaseCounter(container) {
    this.#modifyCounter(container, count => Math.max(0, count - 1))
  }

  #modifyCounter(container, fn) {
    const counterElement = container.querySelector("[data-drag-and-drop-counter]")
    if (counterElement) {
      const currentValue = counterElement.textContent.trim()

      if (!/^\d+$/.test(currentValue)) return

      counterElement.textContent = fn(parseInt(currentValue))
    }
  }

  #insertDraggedItem(container, item) {
    const itemContainer = container.querySelector("[data-drag-drop-item-container]")
    const topItems = itemContainer.querySelectorAll("[data-drag-and-drop-top]")
    const firstTopItem = topItems[0]
    const lastTopItem = topItems[topItems.length - 1]

    const isTopItem = item.hasAttribute("data-drag-and-drop-top")
    const referenceItem = isTopItem ? firstTopItem : lastTopItem

    if (referenceItem) {
      referenceItem[isTopItem ? "before" : "after"](item)
    } else {
      itemContainer.prepend(item)
    }
  }

  async #submitDropRequest(item, container) {
    const body = new FormData()
    const id = item.dataset.id
    if (this.#isSortable(container)) { body.append("before", this.#nextItemId(item)) }
    const url = container.dataset.dragAndDropUrl.replaceAll("__id__", id)

    return post(url, { body, headers: { Accept: "text/vnd.turbo-stream.html" } })
  }

  #reloadSourceFrame(sourceContainer) {
    const frame = sourceContainer.querySelector("[data-drag-and-drop-refresh]")
    if (frame) frame.reload()
  }
}
