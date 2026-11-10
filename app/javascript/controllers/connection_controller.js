import { Controller } from "@hotwired/stimulus"

// Runwell: the page carries on when its connection doesn't (on <body>, staff and portal layouts).
//
// - Offline, or the live connection (each turbo-cable-stream-source's connected attribute) down
//   for more than a moment: a quiet line says so (the status target), and goes when it's back.
// - The live connection back after a real gap: what others changed meanwhile was broadcast to
//   nobody, so the page refreshes in place once (a morph, keeping scroll and what's typed).
// - A form that couldn't be sent for the network (turbo:fetch-request-error: no answer at all) keeps
//   what's on screen, marked unsaved (form[data-unsaved], styled with the fields that join it), and
//   is sent again once the browser is back online. A save the server refused still reverts: that
//   has an answer.
// - A session that ran out mid-work: a frame or form answered with the sign-in page (marked by
//   X-Runwell-Sign-In) would land it inside a frame. Instead the page itself is visited, which the
//   server sends to sign in and back here afterwards.
const SHOW_AFTER = 2_000 // ms the live connection may blink (a visit reconnects it) before it's said
const REFRESH_AFTER = 5_000 // ms down before the page refreshes on its return

export default class extends Controller {
  static targets = [ "status" ]

  connect() {
    this.unsaved = new Set
    this.update = this.update.bind(this)
    this.failed = this.failed.bind(this)
    this.sent = this.sent.bind(this)
    this.answered = this.answered.bind(this)
    this.online = this.online.bind(this)

    window.addEventListener("offline", this.update)
    window.addEventListener("online", this.online)
    document.addEventListener("turbo:fetch-request-error", this.failed)
    document.addEventListener("turbo:submit-end", this.sent)
    document.addEventListener("turbo:before-fetch-response", this.answered)
    this.observer = new MutationObserver(() => this.#cableChanged())
    this.observer.observe(document.documentElement, { subtree: true, attributes: true, attributeFilter: [ "connected" ] })
    this.update()
  }

  disconnect() {
    window.removeEventListener("offline", this.update)
    window.removeEventListener("online", this.online)
    document.removeEventListener("turbo:fetch-request-error", this.failed)
    document.removeEventListener("turbo:submit-end", this.sent)
    document.removeEventListener("turbo:before-fetch-response", this.answered)
    this.observer?.disconnect()
    clearTimeout(this.showTimer)
  }

  // What the quiet line says, if anything.
  update() {
    if (!this.hasStatusTarget) return

    const message = !navigator.onLine ? this.statusTarget.dataset.offline
      : this.cableDownSince && Date.now() - this.cableDownSince >= SHOW_AFTER ? this.statusTarget.dataset.reconnecting : null
    this.statusTarget.hidden = !message
    if (message) this.statusTarget.querySelector("[data-connection-text]").textContent = message
  }

  // A form sent with no answer at all: kept as it is, marked unsaved, sent again when back online.
  failed(event) {
    const form = event.target
    if (!(form instanceof HTMLFormElement)) return

    form.dataset.unsaved = ""
    this.unsaved.add(form)
    this.update()
  }

  sent(event) {
    const form = event.target
    if (!event.detail.success && !event.detail.fetchResponse) return

    delete form.dataset.unsaved
    this.unsaved.delete(form)
  }

  online() {
    this.update()
    this.#resend()
  }

  answered(event) {
    const response = event.detail.fetchResponse?.response
    if (!response?.headers?.get("X-Runwell-Sign-In") || !(event.target instanceof Element) || event.target === document.documentElement) return

    event.preventDefault()
    window.Turbo ? window.Turbo.visit(location.href, { action: "replace" }) : location.reload()
  }

  // Forms that waited for the connection, still on the page: sent again.
  #resend() {
    for (const form of this.unsaved) {
      this.unsaved.delete(form)
      if (!form.isConnected) continue
      delete form.dataset.unsaved
      form.requestSubmit()
    }
  }

  // The page's live sources: all connected, or since when one hasn't been.
  #cableChanged() {
    const sources = Array.from(document.querySelectorAll("turbo-cable-stream-source"))
    const down = sources.length > 0 && sources.some(source => !source.hasAttribute("connected"))

    if (down && !this.cableDownSince) {
      this.cableDownSince = Date.now()
      clearTimeout(this.showTimer)
      this.showTimer = setTimeout(this.update, SHOW_AFTER)
    } else if (!down && this.cableDownSince) {
      const gap = Date.now() - this.cableDownSince
      this.cableDownSince = null
      clearTimeout(this.showTimer)
      this.update()
      this.#resend()
      if (gap >= REFRESH_AFTER) this.#refresh()
    }
  }

  // Once, in place: a morph keeps scroll, open panels and what's typed.
  #refresh() {
    const session = window.Turbo?.session
    if (session?.refresh) session.refresh(location.href)
    else window.Turbo?.visit(location.href, { action: "replace" })
  }
}
