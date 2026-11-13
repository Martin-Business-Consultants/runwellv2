import { Controller } from "@hotwired/stimulus"

// Runwell's side panel, on runeui's (ui :side_panel, params: task and peek, in
// layouts/shared/_side_panel and the portal's): a task opened over the page you're on, or a client,
// piece of work or contact peeked at there. Its state is the page's own address plus ?task=42 (or
// ?peek=Work:12; one at a time), so a refresh shows the same page with the same panel open, and the
// server renders it on a full load. runeui's controller (runeui--side-panel, on the panel) opens and
// closes it, keeps the address (pushed to open, replaced to follow, Back to close when it was opened
// here) and shows a skeleton while it loads; this one, on <body>, adds what Runwell's lists need:
//
// - Links that open one keep their own page as the href (a modifier key or middle click opens it)
//   and carry data-action="side-panel#open" with the task's id (data-side-panel-task-param) or the
//   record's "Type:id" (data-side-panel-peek-param): a plain click loads this page with that param
//   into the panel's frame.
// - j / k with the panel open (keyboard:select): it follows the row you move to.
// - Hovering a link fetches its panel ahead (after a short pause, kept 10 seconds), and the frame's
//   own request then takes that response instead of asking again (Turbo's hand-off,
//   event.detail.fetchRequest in turbo:before-fetch-request, as its link prefetching does). While
//   it's open, the rows just above and below the one showing are fetched the same way, so j / k
//   follows without waiting. Any change on the page (a form sent, a stream arriving) drops
//   everything fetched, so a panel is never stale.
// - A click outside it closes it, unless it's on another panel link (which it then follows), in a
//   dialog, popover, menu, the modal or a toast, or a press that began inside the panel (a selection
//   dragged out). Pressed and released both count, so the click is a real click off.
// - A record's tab (or the List / Board switch, in the same frame) takes you elsewhere on the page:
//   the panel closes.
// - close (✕, Esc through data-keys, the close_side_panel stream action) closes it as runeui does.
const PREFETCH_DELAY = 60
const PREFETCH_TTL = 10_000
const PREFETCH_KEPT = 4
const LINK = "[data-side-panel-task-param], [data-side-panel-peek-param]"
const PARAMS = [ "task", "peek" ]
const KEEPS_OPEN = `${LINK}, dialog, [popover], #modal, #quick_action, #runeui-toaster, #runeui-confirm, ui-alert-dialog-content, ui-dialog-content, ui-menu-content, ui-popover-content, ui-combobox-content, ui-select-content, .ui-popup`

export default class extends Controller {
  connect() {
    this.closeRequested = () => this.close()
    document.addEventListener("side-panel:close-requested", this.closeRequested)
    this.leaving = this.leaving.bind(this)
    document.addEventListener("turbo:before-fetch-request", this.leaving)

    this.hovered = this.hovered.bind(this)
    this.unhovered = this.unhovered.bind(this)
    this.usePrefetched = this.usePrefetched.bind(this)
    this.prefetched = new Map
    this.dropPrefetched = () => { this.prefetched.clear() }
    this.element.addEventListener("mouseover", this.hovered, { passive: true })
    this.element.addEventListener("mouseout", this.unhovered, { passive: true })
    document.addEventListener("turbo:before-fetch-request", this.usePrefetched)
    document.addEventListener("turbo:submit-start", this.dropPrefetched)
    document.addEventListener("turbo:before-stream-render", this.dropPrefetched)

    this.pressed = this.pressed.bind(this)
    this.clicked = this.clicked.bind(this)
    document.addEventListener("pointerdown", this.pressed, true)
    document.addEventListener("click", this.clicked, true)
  }

  disconnect() {
    document.removeEventListener("side-panel:close-requested", this.closeRequested)
    document.removeEventListener("turbo:before-fetch-request", this.leaving)
    this.element.removeEventListener("mouseover", this.hovered)
    this.element.removeEventListener("mouseout", this.unhovered)
    document.removeEventListener("turbo:before-fetch-request", this.usePrefetched)
    document.removeEventListener("turbo:submit-start", this.dropPrefetched)
    document.removeEventListener("turbo:before-stream-render", this.dropPrefetched)
    document.removeEventListener("pointerdown", this.pressed, true)
    document.removeEventListener("click", this.clicked, true)
    clearTimeout(this.hoverTimer)
  }

  open(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button > 0) return
    const param = PARAMS.map(name => [ name, event.params[name] ]).find(([ , value ]) => value)
    if (!param || !this.#frame) return

    event.preventDefault()
    this.#load(param)
    this.#prefetchAround(event.target.closest?.("[data-filter-target~=item]"))
  }

  // j / k with the panel open: it follows the row you move to.
  follow({ target }) {
    if (!this.#isOpen) return
    const param = this.#paramOf(target.querySelector?.(LINK))
    if (!param || this.#isCurrent(param)) return

    this.#load(param)
    this.#prefetchAround(target)
  }

  close(event) {
    event?.preventDefault?.()
    if (!this.#isOpen) return
    const panel = this.#runeuiPanel
    panel ? panel.close() : this.#panel?.api?.close()
  }

  // A click off the panel (capture: before anything under it stops the click going further).
  pressed(event) {
    this.pressedOff = this.#isOpen && this.#off(event)
  }

  clicked(event) {
    const pressedOff = this.pressedOff
    this.pressedOff = false
    if (!pressedOff || !this.#isOpen || !this.#off(event)) return
    if (event.button > 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    this.close()
  }

  // A pointer resting on a panel's link: fetch its panel, unless it's the one showing or already fetched.
  hovered({ target }) {
    const link = target.closest?.(LINK)
    if (!link || link === this.hoveredLink) return

    this.hoveredLink = link
    clearTimeout(this.hoverTimer)
    this.hoverTimer = setTimeout(() => this.#prefetch(this.#paramOf(link)), PREFETCH_DELAY)
  }

  unhovered({ target, relatedTarget }) {
    const link = target.closest?.(LINK)
    if (!link || link !== this.hoveredLink || link.contains(relatedTarget)) return

    this.hoveredLink = null
    clearTimeout(this.hoverTimer)
  }

  // The frame asking for a panel fetched ahead: hand it that response (once: a body reads once).
  usePrefetched(event) {
    if (event.target !== this.#frame) return

    const url = event.detail.url.toString()
    const prefetched = this.prefetched.get(url)
    this.prefetched.delete(url)
    if (!prefetched || Date.now() - prefetched.at > PREFETCH_TTL) return

    event.detail.fetchRequest = { response: prefetched.response }
  }

  // A record's tab (or the List / Board switch, in the same frame) takes you somewhere else on the
  // page: the panel closes. Other frames loading (a board column's next cards) leave it open.
  // Its address is already the tab's (without ?task), so closing mustn't step Back.
  leaving({ target }) {
    if (target.id !== "record_tab" || !this.#isOpen) return
    const panel = this.#runeuiPanel
    if (panel) panel.pushed = false
    this.close()
  }

  get #panel() {
    return document.getElementById("runeui-side-panel")
  }

  get #runeuiPanel() {
    const panel = this.#panel
    return panel && this.application.getControllerForElementAndIdentifier(panel, "runeui--side-panel")
  }

  get #frame() {
    return document.getElementById("side_panel")
  }

  get #isOpen() {
    const panel = this.#panel
    if (!panel) return false
    return panel.api ? panel.api.isOpen() : panel.hasAttribute("default-open")
  }

  #off({ target }) {
    if (!(target instanceof Element) || !target.isConnected) return false
    const content = this.#panel?.querySelector("[data-side-panel-content]")
    return !content?.contains(target) && !target.closest(KEEPS_OPEN)
  }

  // What the panel shows, from the address: [ "task", "42" ], [ "peek", "Work:12" ] or nothing.
  get #current() {
    const params = new URL(location.href).searchParams
    return PARAMS.map(name => [ name, params.get(name) ]).find(([ , value ]) => value)
  }

  #isCurrent([ name, value ]) {
    const current = this.#current
    return !!current && current[0] === name && current[1] === String(value)
  }

  // What a link opens: [ "task", id ] or [ "peek", "Type:id" ].
  #paramOf(link) {
    if (!link) return null
    if (link.dataset.sidePanelTaskParam) return [ "task", link.dataset.sidePanelTaskParam ]
    if (link.dataset.sidePanelPeekParam) return [ "peek", link.dataset.sidePanelPeekParam ]
    return null
  }

  // This page with that panel (one at a time).
  #urlFor(param) {
    const url = new URL(location.href)
    PARAMS.forEach(name => url.searchParams.delete(name))
    url.searchParams.set(param[0], param[1])
    return url
  }

  // The rows just before and after this item in the page's list (the items j / k move through),
  // fetched once the panel's own request is on its way.
  #prefetchAround(item) {
    if (!item) return

    const items = Array.from(document.querySelectorAll("[data-filter-target~=item]")).filter(each => each.checkVisibility?.() ?? each.offsetParent)
    const at = items.indexOf(item)
    if (at < 0) return

    for (const neighbour of [ items[at + 1], items[at - 1] ]) {
      this.#prefetch(this.#paramOf(neighbour?.querySelector(LINK)))
    }
  }

  #prefetch(param) {
    if (!param || this.#isCurrent(param) || !this.#frame) return
    const url = this.#urlFor(param).toString()
    const kept = this.prefetched.get(url)
    if (kept && Date.now() - kept.at < PREFETCH_TTL) return

    const response = fetch(url, {
      credentials: "same-origin", priority: "low",
      headers: { Accept: "text/html, application/xhtml+xml", "Turbo-Frame": this.#frame.id, "X-Sec-Purpose": "prefetch" }
    })
    response.catch(() => { if (this.prefetched.get(url)?.response === response) this.prefetched.delete(url) })
    this.prefetched.delete(url)
    this.prefetched.set(url, { url, response, at: Date.now() })
    while (this.prefetched.size > PREFETCH_KEPT) this.prefetched.delete(this.prefetched.keys().next().value)
  }

  // runeui's controller sees the frame fetch (and opens), then writes the address once it's loaded.
  #load(param) {
    this.#frame.src = this.#urlFor(param).toString()
  }
}
