import { Controller } from "@hotwired/stimulus"

// Reloads the turbo-frame it sits in every few seconds while something runs elsewhere (an
// update). While the server restarts, a reload that comes back without the frame keeps what's
// shown instead of replacing it with an error. Gone from the page, it stops.
export default class extends Controller {
  static values = { interval: { type: Number, default: 5 } }

  connect() {
    this.frame = this.element.closest("turbo-frame")
    this.timer = setInterval(() => this.#reload(), this.intervalValue * 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  // A frame reloads from its src, which the page's frame doesn't carry until the first tick.
  #reload() {
    if (!this.frame) return
    if (this.frame.src) this.frame.reload()
    else this.frame.src = window.location.href
  }

  keep(event) {
    if (event.target === this.frame) event.preventDefault()
  }
}
