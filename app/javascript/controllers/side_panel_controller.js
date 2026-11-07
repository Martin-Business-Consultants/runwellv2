import { Controller } from "@hotwired/stimulus"

// The side panel (layouts/shared/_side_panel): a task opened beside the page you're on instead of
// on a page of its own. Its state is the page's own address plus ?task=42, so a refresh, a save
// that comes back here and Back all keep or close it as you'd expect, and the server renders it
// on a full load. Links that open a task carry data-action="side-panel#open" and the task's id;
// with a modifier key (or a middle click) they open the task's own page as usual.
export default class extends Controller {
  static targets = [ "frame" ]

  open(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button > 0) return
    const id = event.params.task
    if (!id) return

    event.preventDefault()
    this.#show(id, "advance")
    this.openedHere = true
  }

  // j / k with the panel open: it follows the row you move to, without adding to history.
  follow({ target }) {
    if (!this.#isOpen) return
    const id = target.querySelector?.("[data-side-panel-task-param]")?.dataset.sidePanelTaskParam
    if (id && id !== this.#currentId) this.#show(id, "replace")
  }

  close(event) {
    event?.preventDefault()
    if (this.openedHere) {
      this.openedHere = false
      history.back()
    } else {
      const url = new URL(location.href)
      url.searchParams.delete("task")
      this.#visit(url, "replace")
    }
  }

  get #isOpen() {
    return this.hasFrameTarget && this.frameTarget.querySelector(".task-panel")
  }

  get #currentId() {
    return new URL(location.href).searchParams.get("task")
  }

  #show(id, action) {
    const url = new URL(location.href)
    url.searchParams.set("task", id)
    this.#visit(url, action)
  }

  // Into the panel's frame, recording the address as given (advance to open, replace to follow or close).
  #visit(url, action) {
    window.Turbo.visit(url.toString(), { frame: this.frameTarget.id, action })
  }
}
