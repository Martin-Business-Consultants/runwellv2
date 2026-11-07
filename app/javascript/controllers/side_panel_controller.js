import { Controller } from "@hotwired/stimulus"

// The side panel (layouts/shared/_side_panel): a task opened over the page you're on instead of on
// a page of its own. Its state is the page's own address plus ?task=42, so a refresh shows the same
// page with the same task open, and the server renders it on a full load.
//
// Opening, following and closing only load the panel's frame (frame.src): no page visit, so no page
// render, view transition or morph runs under it. The address is written through Turbo's history
// (push to open, replace to follow or close), so the entries are ones Turbo understands, and Back
// or Forward between this page with and without ?task is handled here, before Turbo would revisit
// the page. Links that open a task carry data-action="side-panel#open" and the task's id; with a
// modifier key (or a middle click) they open the task's own page as usual.
export default class extends Controller {
  static targets = [ "frame" ]

  connect() {
    this.popped = this.popped.bind(this)
    window.addEventListener("popstate", this.popped, true) // capture: before Turbo's own listener
  }

  disconnect() {
    window.removeEventListener("popstate", this.popped, true)
  }

  open(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button > 0) return
    const id = event.params.task
    if (!id) return

    event.preventDefault()
    const url = this.#urlFor(id)
    this.#load(url)
    this.#record("push", url)
    this.openedHere = true
  }

  // j / k with the panel open: it follows the row you move to, without adding to history.
  follow({ target }) {
    if (!this.#isOpen) return
    const id = target.querySelector?.("[data-side-panel-task-param]")?.dataset.sidePanelTaskParam
    if (!id || id === this.#currentId) return

    const url = this.#urlFor(id)
    this.#load(url)
    this.#record("replace", url)
  }

  close(event) {
    event?.preventDefault()
    if (this.openedHere) {
      this.openedHere = false
      history.back()
    } else {
      const url = this.#urlFor(null)
      this.#load(url)
      this.#record("replace", url)
    }
  }

  // Back or Forward to this same page with another ?task (or none): just the panel changes.
  popped(event) {
    const now = new URL(location.href)
    if (!this.#samePageAs(now)) return

    event.stopImmediatePropagation()
    this.openedHere = false
    const turbo = event.state?.turbo
    const history = window.Turbo?.session?.history
    if (history && turbo) {
      history.location = now
      history.restorationIdentifier = turbo.restorationIdentifier
      history.currentIndex = turbo.restorationIndex
    }
    this.#load(now)
  }

  get #isOpen() {
    return this.hasFrameTarget && this.frameTarget.querySelector(".task-panel")
  }

  get #currentId() {
    return new URL(location.href).searchParams.get("task")
  }

  #urlFor(id) {
    const url = new URL(location.href)
    id ? url.searchParams.set("task", id) : url.searchParams.delete("task")
    return url
  }

  // The page the panel last saw, apart from ?task: the same path and every other param.
  #samePageAs(url) {
    if (!this.pageUrl) return false
    const strip = u => { const copy = new URL(u); copy.searchParams.delete("task"); return copy.pathname + "?" + copy.searchParams.toString() }
    return strip(url) === strip(this.pageUrl)
  }

  #load(url) {
    this.pageUrl = new URL(url)
    this.frameTarget.src = url.toString()
  }

  #record(method, url) {
    const history = window.Turbo?.session?.history
    if (history) {
      method === "push" ? history.push(url) : history.replace(url, history.restorationIdentifier)
    } else {
      window.history[method === "push" ? "pushState" : "replaceState"](window.history.state, "", url)
    }
  }
}
