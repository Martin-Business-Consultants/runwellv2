import { Controller } from "@hotwired/stimulus"
import { orient } from "helpers/orientation_helpers"
import { isTouchDevice } from "helpers/platform_helpers"

export default class extends Controller {
  static targets = [ "dialog", "focusMouse", "focusTouch" ]
  static values = {
    modal: { type: Boolean, default: false },
    sizing: { type: Boolean, default: true },
    autoOpen: { type: Boolean, default: false },
    orient: { type: Boolean, default: true }
  }

  connect() {
    this.dialogTarget.setAttribute("aria-hidden", "true")
    this.closeForOther = this.closeForOther.bind(this)
    document.addEventListener("dialog:opening", this.closeForOther)
    if (this.autoOpenValue) this.open()
  }

  disconnect() {
    document.removeEventListener("dialog:opening", this.closeForOther)
  }

  // Another menu opening closes this one, unless it opens inside it (a picker in a modal or a
  // tray). Clicking from one filter to the next leaves only the new one open: their triggers stop
  // the click, so the outside click that would close the first never reaches it.
  closeForOther({ target }) {
    if (target === this.element || this.element.contains(target)) return
    if (this.dialogTarget.open) this.close()
  }

  focusTouchTargetConnected() {
    this.#setupFocus()
  }

  open() {
    const modal = this.modalValue
    this.element.dispatchEvent(new CustomEvent("dialog:opening", { bubbles: true }))

    if (modal) {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.show()
      if (this.orientValue) {
        orient({ target: this.dialogTarget, anchor: this.element })
      }
    }

    this.loadLazyFrames()
    this.dialogTarget.setAttribute("aria-hidden", "false")
    this.dispatch("show")
  }

  toggle() {
    if (this.dialogTarget.open) {
      this.close()
    } else {
      this.open()
    }
  }

  close() {
    this.dialogTarget.close()
    this.dialogTarget.setAttribute("aria-hidden", "true")
    this.dialogTarget.blur()
    orient({ target: this.dialogTarget, reset: true })
    this.dispatch("close")
  }

  closeOnClickOutside({ target }) {
    if (!this.element.contains(target)) this.close()
  }

  preventCloseOnMorphing(event) {
    if (event.detail?.attributeName === "open") {
      event.preventDefault()
      event.stopPropagation()
    }
  }

  loadLazyFrames() {
    Array.from(this.dialogTarget.querySelectorAll("turbo-frame")).forEach(frame => { frame.loading = "eager" })
  }

  captureKey(event) {
    if (event.key !== "Escape") { event.stopPropagation() }
  }

  #setupFocus() {
    const touch = isTouchDevice()
    if (this.hasFocusMouseTarget) this.focusMouseTarget.autofocus = !touch
    if (this.hasFocusTouchTarget) this.focusTouchTarget.autofocus = touch
  }
}
