import { Controller } from "@hotwired/stimulus"
import { onNextEventLoopTick } from "helpers/timing_helpers"

// The unread count outside the page: the installed app's badge, and the tab's title, "(3) Tasks |
// Lumin" (ApplicationHelper#page_title_tag draws it; this keeps it current as the tray reloads).
// The tray lists only the newest few, so the total comes from its frame (total target) when given.
const PREFIX = /^\(\d+\) /

export default class extends Controller {
  static targets = [ "unread", "total" ]
  static classes = [ "unread" ]

  connect() {
    onNextEventLoopTick(() => this.update())
    this.retitle = () => this.#title(this.lastCount)
    document.addEventListener("turbo:load", this.retitle)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.retitle)
  }

  update() {
    onNextEventLoopTick(() => {
      if (!this.hasTotalTarget && !this.hasUnreadTarget) return

      const unreadCount = this.#unreadCount
      this.lastCount = unreadCount
      this.#title(unreadCount)
      if (this.#available) {
        if (unreadCount > 0) {
          navigator.setAppBadge(unreadCount)
        } else {
          navigator.clearAppBadge()
        }
      }
    })
  }

  clear() {
    onNextEventLoopTick(() => {
      this.lastCount = 0
      this.#title(0)
      if (this.#available) {
        navigator.clearAppBadge()
      }
    })
  }

  #title(count) {
    if (count === undefined) return

    const title = document.title.replace(PREFIX, "")
    document.title = count > 0 ? `(${count}) ${title}` : title
  }

  get #unreadCount() {
    if (this.hasTotalTarget) return Number(this.totalTarget.value) || 0
    return this.unreadTargets.filter(unreadTarget => unreadTarget.classList.contains(this.unreadClass)).length
  }

  get #available() {
    return "setAppBadge" in navigator
  }
}
