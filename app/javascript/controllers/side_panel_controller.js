import { Controller } from "@hotwired/stimulus"

// The side panel (layouts/shared/_side_panel): a task opened over the page you're on instead of on
// a page of its own, or a client, piece of work or contact peeked at there. Its state is the page's
// own address plus ?task=42 (or ?peek=Work:12; one at a time), so a refresh shows the same page with
// the same panel open, and the server renders it on a full load.
//
// Opening, following and closing only load the panel's frame (frame.src): no page visit, so no page
// render, view transition or morph runs under it. The address is written through Turbo's history
// (push to open, replace to follow or close), so the entries are ones Turbo understands, and Back
// or Forward between this page with and without ?task is handled here, before Turbo would revisit
// the page. Links that open one carry data-action="side-panel#open" and the task's id
// (data-side-panel-task-param) or the record's "Type:id" (data-side-panel-peek-param); with a
// modifier key (or a middle click) they open its own page as usual.
//
// Hovering a task's link fetches its panel ahead (prefetch, after a short pause, kept 10 seconds),
// and the frame's own request then takes that response instead of asking again (Turbo's hand-off,
// event.detail.fetchRequest in turbo:before-fetch-request, as its link prefetching does). While the
// panel is open, the tasks just above and below the one showing are fetched the same way, so j / k
// follows without waiting. Any change on the page (a form sent, a stream arriving) drops everything
// fetched, so a panel is never stale.
//
// A click outside it closes it, as Esc does, unless it's on another task (which the panel then
// follows), in a dialog, popover, the modal or a toast, or a press that began inside the panel (a
// selection dragged out). Pressed and released both count, so the click is a real click off.
//
// It shows at once when a task is clicked (a placeholder with its title, from the layout's
// template) and eases in; the task's own panel fades in over it when it arrives. Its contents cross-fade when it follows another task (the panel
// itself stays put), and it fades out before it closes: each frame render waits for the panel's
// way out (Turbo's pausable turbo:before-frame-render), then the new one comes in.
const PREFETCH_DELAY = 60
const PREFETCH_TTL = 10_000
const PREFETCH_KEPT = 4
const LINK = "[data-side-panel-task-param], [data-side-panel-peek-param]"
const PARAMS = [ "task", "peek" ]
const KEEPS_OPEN = `${LINK}, dialog, [popover], #modal, #quick_action, #runeui-toaster, #runeui-confirm, ui-alert-dialog-content, ui-dialog-content, ui-menu-content`

export default class extends Controller {
  static targets = [ "frame", "placeholder" ]

  connect() {
    this.popped = this.popped.bind(this)
    this.rendering = this.rendering.bind(this)
    window.addEventListener("popstate", this.popped, true) // capture: before Turbo's own listener
    this.leaving = this.leaving.bind(this)
    this.closeRequested = () => { if (this.#isOpen) this.close() }
    document.addEventListener("side-panel:close-requested", this.closeRequested)
    if (this.hasFrameTarget) this.frameTarget.addEventListener("turbo:before-frame-render", this.rendering)
    document.addEventListener("turbo:before-fetch-request", this.leaving)

    this.hovered = this.hovered.bind(this)
    this.unhovered = this.unhovered.bind(this)
    this.usePrefetched = this.usePrefetched.bind(this)
    this.prefetched = new Map
    this.dropPrefetched = () => { this.prefetched.clear() }
    this.element.addEventListener("mouseover", this.hovered, { passive: true })
    this.element.addEventListener("mouseout", this.unhovered, { passive: true })
    if (this.hasFrameTarget) this.frameTarget.addEventListener("turbo:before-fetch-request", this.usePrefetched)
    document.addEventListener("turbo:submit-start", this.dropPrefetched)
    document.addEventListener("turbo:before-stream-render", this.dropPrefetched)

    this.pressed = this.pressed.bind(this)
    this.clicked = this.clicked.bind(this)
    document.addEventListener("pointerdown", this.pressed, true)
    document.addEventListener("click", this.clicked, true)
  }

  disconnect() {
    window.removeEventListener("popstate", this.popped, true)
    if (this.hasFrameTarget) this.frameTarget.removeEventListener("turbo:before-frame-render", this.rendering)
    document.removeEventListener("turbo:before-fetch-request", this.leaving)
    document.removeEventListener("side-panel:close-requested", this.closeRequested)
    this.element.removeEventListener("mouseover", this.hovered)
    this.element.removeEventListener("mouseout", this.unhovered)
    if (this.hasFrameTarget) this.frameTarget.removeEventListener("turbo:before-fetch-request", this.usePrefetched)
    document.removeEventListener("turbo:submit-start", this.dropPrefetched)
    document.removeEventListener("turbo:before-stream-render", this.dropPrefetched)
    document.removeEventListener("pointerdown", this.pressed, true)
    document.removeEventListener("click", this.clicked, true)
    clearTimeout(this.hoverTimer)
  }

  // A click off the panel (capture: before anything under it stops the click going further).
  pressed(event) {
    this.pressedOff = this.#isOpen && this.#off(event)
  }

  clicked(event) {
    const pressedOff = this.pressedOff
    this.pressedOff = false
    if (!pressedOff || !this.#isOpen || !this.#off(event) || !this.#current) return
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
    if (event.target !== this.frameTarget) return

    const url = event.detail.url.toString()
    const prefetched = this.prefetched.get(url)
    this.prefetched.delete(url)
    if (!prefetched || Date.now() - prefetched.at > PREFETCH_TTL) return

    event.detail.fetchRequest = { response: prefetched.response }
  }

  // A record's tab (or the List / Board switch, in the same frame) takes you somewhere else on the
  // page: the panel fades away. Those links leave ?task out, so history is already right; the frame
  // is just emptied. Other frames loading (a board column's next cards) leave it open.
  leaving({ target }) {
    if (!this.#isOpen || target.id !== "record_tab") return

    const panel = this.frameTarget.querySelector(".task-panel")
    this.openedHere = false
    this.pageUrl = null
    const empty = () => { this.frameTarget.removeAttribute("src"); this.frameTarget.replaceChildren() }
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return empty()

    panel.classList.add("task-panel--leaving")
    setTimeout(empty, 250)
    panel.addEventListener("animationend", ({ target }) => { if (target === panel) empty() })
  }

  // A panel already showing: the same task again (a refresh) just renders, still; another task
  // swaps only its contents (no entrance again); closing lets it fade out first.
  rendering(event) {
    const current = this.frameTarget.querySelector(".task-panel")
    const next = event.detail.newFrame?.querySelector(".task-panel")
    if (!current) return

    if (next) {
      next.classList.add(next.id === current.id ? "task-panel--still" : "task-panel--following")
      return
    }
    if (matchMedia("(prefers-reduced-motion: reduce)").matches) return

    event.preventDefault()
    current.classList.add("task-panel--leaving")
    let resumed = false
    const done = () => { if (resumed) return; resumed = true; clearTimeout(timer); event.detail.resume() }
    const timer = setTimeout(done, 250)
    current.addEventListener("animationend", ({ target }) => { if (target === current) done() })
  }

  open(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button > 0) return
    const param = PARAMS.map(name => [ name, event.params[name] ]).find(([ , value ]) => value)
    if (!param) return

    event.preventDefault()
    const url = this.#urlFor(param)
    if (!this.#isOpen) this.#showPlaceholder(event.params.title)
    this.#load(url)
    this.#record("push", url)
    this.openedHere = true
    this.#prefetchAround(event.target.closest?.("[data-filter-target~=item]"))
  }

  // j / k with the panel open: it follows the row you move to, without adding to history.
  follow({ target }) {
    if (!this.#isOpen) return
    const param = this.#paramOf(target.querySelector?.(LINK))
    if (!param || this.#isCurrent(param)) return

    const url = this.#urlFor(param)
    this.#load(url)
    this.#record("replace", url)
    this.#prefetchAround(target)
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

  #off({ target }) {
    if (!(target instanceof Element) || !target.isConnected) return false
    return !this.frameTarget.contains(target) && !target.closest(KEEPS_OPEN)
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

  // This page with that panel (one at a time), or none.
  #urlFor(param) {
    const url = new URL(location.href)
    PARAMS.forEach(name => url.searchParams.delete(name))
    if (param) url.searchParams.set(param[0], param[1])
    return url
  }

  // The page the panel last saw, apart from ?task and ?peek: the same path and every other param.
  #samePageAs(url) {
    if (!this.pageUrl) return false
    const strip = u => { const copy = new URL(u); PARAMS.forEach(name => copy.searchParams.delete(name)); return copy.pathname + "?" + copy.searchParams.toString() }
    return strip(url) === strip(this.pageUrl)
  }

  // The panel at once, with the task's title, while its frame loads: the click answers now, not
  // after the round trip. The frame's answer then fades in over it (rendering, "following").
  #showPlaceholder(title) {
    if (!this.hasPlaceholderTarget) return

    const placeholder = this.placeholderTarget.content.cloneNode(true)
    const heading = placeholder.querySelector("[data-side-panel-title]")
    if (heading) heading.textContent = title || ""
    this.frameTarget.replaceChildren(placeholder)
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
    if (!param || this.#isCurrent(param)) return
    const url = this.#urlFor(param).toString()
    const kept = this.prefetched.get(url)
    if (kept && Date.now() - kept.at < PREFETCH_TTL) return

    const response = fetch(url, {
      credentials: "same-origin", priority: "low",
      headers: { Accept: "text/html, application/xhtml+xml", "Turbo-Frame": this.frameTarget.id, "X-Sec-Purpose": "prefetch" }
    })
    response.catch(() => { if (this.prefetched.get(url)?.response === response) this.prefetched.delete(url) })
    this.prefetched.delete(url)
    this.prefetched.set(url, { url, response, at: Date.now() })
    while (this.prefetched.size > PREFETCH_KEPT) this.prefetched.delete(this.prefetched.keys().next().value)
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
