import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  morphRender({ detail }) {
    detail.render = function (currentElement, newElement) {
      Turbo.morphChildren(currentElement, newElement)
    }
  }

  // A page morph (a refresh, or a filter that swaps a query param on the same page) reloads a
  // frame that loads from an address instead of morphing it. A frame rendered with its page (a
  // board column's first cards, which carry no src) is left to the morph, which brings in the
  // page's new cards; preventing it there left the old ones showing.
  morphReload(event) {
    const newElement = event.detail.newElement
    if (!this.element.src) return

    if (newElement && newElement.tagName === "TURBO-FRAME" && newElement.matches('[data-controller~="frame"]')) {
      event.preventDefault()
      this.element.reload()
    }
  }

  reload() {
    this.element.reload()
  }
}
