import { Controller } from "@hotwired/stimulus"
import { post, destroy } from "@rails/request.js"

// Runwell: the switch for notifications on this device (Settings > Your account). On asks the
// browser's permission, subscribes this browser through the service worker with the install's key
// (key value) and hands the subscription to the server (url value); off unsubscribes and tells it.
// The switch shows whether this browser is subscribed, which only it knows. A browser that can't
// (no service worker or push, or permission refused) says so (the note target) and the switch stays off.
export default class extends Controller {
  static targets = [ "switch", "note" ]
  static values = { key: String, url: String }

  async connect() {
    if (!this.#supported) return this.#say(this.noteTarget?.dataset.unsupported, true)

    const subscription = await (await this.#registration)?.pushManager.getSubscription()
    this.switchTarget.checked = !!subscription
    if (Notification.permission === "denied") this.#say(this.noteTarget?.dataset.denied, true)
  }

  async toggle() {
    this.switchTarget.disabled = true
    try {
      this.switchTarget.checked ? await this.#subscribe() : await this.#unsubscribe()
    } catch {
      this.switchTarget.checked = !this.switchTarget.checked
      this.#say(this.noteTarget?.dataset.failed)
    } finally {
      this.switchTarget.disabled = !this.#supported
    }
  }

  async #subscribe() {
    if (await Notification.requestPermission() !== "granted") {
      this.switchTarget.checked = false
      return this.#say(this.noteTarget?.dataset.denied)
    }
    const registration = await this.#registration
    const subscription = await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: decode(this.keyValue) })
    const { endpoint, keys } = subscription.toJSON()
    const response = await post(this.urlValue, { body: { endpoint, keys }, responseKind: "json" })
    if (!response.ok) throw new Error("not saved")
    this.#say("")
  }

  async #unsubscribe() {
    const subscription = await (await this.#registration)?.pushManager.getSubscription()
    if (!subscription) return

    await destroy(this.urlValue, { query: { endpoint: subscription.endpoint } })
    await subscription.unsubscribe()
  }

  get #supported() {
    return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window
  }

  get #registration() {
    return navigator.serviceWorker.getRegistration("/").then(found => found || navigator.serviceWorker.register("/service-worker.js").then(() => navigator.serviceWorker.ready))
  }

  #say(text, disable = false) {
    if (this.hasNoteTarget) {
      this.noteTarget.textContent = text || ""
      this.noteTarget.hidden = !text
    }
    if (disable) this.switchTarget.disabled = true
  }
}

// The key as the bytes PushManager wants (it's base64url).
function decode(key) {
  const base64 = (key + "=".repeat((4 - key.length % 4) % 4)).replace(/-/g, "+").replace(/_/g, "/")
  return Uint8Array.from(atob(base64), character => character.charCodeAt(0))
}
