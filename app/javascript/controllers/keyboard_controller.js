import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"
import { nextFrame } from "helpers/timing_helpers"

// Every key the app answers to, vim style, in one place (on <body>). Letters act outside
// inputs and open dialogs; ⌘/Ctrl+Enter saves from anywhere in a form.
//
// - j / k, g g / G walk the page's items (anything marked data-filter-target="item"),
//   Enter or o opens the one you're on, Esc drops it
// - a chord starting with g goes somewhere: any element declaring data-keys="g c". A chord may
//   take a third key (data-keys="g w n"): after g w it waits a moment for one, vim style, and
//   with none (or another) does g w
// - every other key clicks the visible element declaring it (data-keys="e"), or focuses it
//   (data-keys-focus). One inside the current item wins over the page's own, so e and d
//   act on the row you're on
// - on the Work board, h / l and j / k drive Fizzy's column navigation and H / L move the
//   card a column, posting to the same drop endpoint a drag would
//
// The ? sheet (layouts/shared/_shortcuts) lists them all. Esc in a form opened in place closes it
// (its data-keys="esc" Cancel, or its <details>); with nothing selected it goes up a level
// (<link rel="up">) or back.
//
// Hint mode (. or the switch in the ? sheet) puts each key on the control it presses: every
// element declaring data-keys gets data-key-hint, which hints.css shows as a keycap, and a
// strip at the foot of the page lists the keys with no control (layouts/shared/_hint_legend).
// It's remembered per browser, and off until someone turns it on.

const ITEM = "[data-filter-target~='item'], [data-keyboard-item]"
const TYPING = "input, textarea, select, [contenteditable], lexxy-editor"
const OPENER = ":is(a[href], button):not(.row-action):not([data-keys])"
const CHORD_TIMEOUT = 1500
const EXTEND_TIMEOUT = 600 // how long g w waits for a third key before it goes
const MOD = /Mac|iPhone|iPad/.test(navigator.platform) ? "meta" : "ctrl"
const BOARD_ARROWS = { j: "ArrowDown", k: "ArrowUp", h: "ArrowLeft", l: "ArrowRight" }
const HINTS_KEY = "keyHints"

export default class extends Controller {
  connect() {
    this.keydown = this.keydown.bind(this)
    this.focusin = this.focusin.bind(this)
    document.addEventListener("keydown", this.keydown)
    document.addEventListener("focusin", this.focusin)
    this.#showHints(this.#storedHints)
  }

  disconnect() {
    document.removeEventListener("keydown", this.keydown)
    document.removeEventListener("focusin", this.focusin)
    this.hintObserver?.disconnect()
  }

  // Hint mode, from . or a button (data-action="keyboard#toggleHints").
  toggleHints(event) {
    event?.preventDefault()
    const on = !document.documentElement.hasAttribute("data-hints")
    try { localStorage.setItem(HINTS_KEY, on ? "on" : "off") } catch {}
    this.#showHints(on)
  }

  focusin({ target }) {
    if (this.current && !this.current.contains(target)) this.#clear()
  }

  // The item j / k landed on. A Turbo visit swaps the body out from under it (a morph keeps it).
  get current() {
    return this.selected?.isConnected ? this.selected : null
  }

  set current(item) {
    this.selected = item
  }

  keydown(event) {
    if (event.defaultPrevented || event.isComposing) return
    const key = describe(event)

    if (key === `${MOD}+enter`) return this.#save(event)
    if (key === "esc" && this.#cancel(event)) return
    if (event.target.closest?.(TYPING) || event.target.closest?.("dialog[open]") || document.querySelector("dialog:modal")) return

    if (this.pending) {
      const previous = this.pending
      const chord = `${previous} ${key}`
      this.pending = null
      clearTimeout(this.chordTimer)
      if (chord === "g g") return this.#select(this.#items()[0], event)
      if (this.#extended(chord)) return this.#awaitThird(chord, event)
      if (previous.includes(" ")) return this.#trigger(chord, event) || this.#trigger(previous, event)
      return this.#trigger(chord, event)
    }
    if (key === "g") return this.#startChord(event)

    if (this.#board && this.#boardKey(key, event)) return

    switch (key) {
      case ".": return this.toggleHints(event)
      case "j": return this.#step(1, event)
      case "k": return this.#step(-1, event)
      case "G": return this.#select(this.#items().at(-1), event)
      case "enter":
      case "o":
        if (this.#open(event)) return
        break
      case "esc":
        if (this.current) return this.#clear(event)
        if (this.#trigger(key, event)) return
        return this.#up(event)
    }
    this.#trigger(key, event)
  }

  // Esc with nothing selected: the page one level up (<link rel="up">, from parent_page), or
  // back in history.
  #up(event) {
    const up = document.querySelector("link[rel=up]")?.href
    if (up) {
      event.preventDefault()
      window.Turbo ? window.Turbo.visit(up) : (location.href = up)
    } else if (history.length > 1 && location.pathname !== "/") {
      event.preventDefault()
      history.back()
    }
  }

  // Hints

  get #storedHints() {
    try { return localStorage.getItem(HINTS_KEY) === "on" } catch { return false }
  }

  #showHints(on) {
    document.documentElement.toggleAttribute("data-hints", on)
    this.hintObserver?.disconnect()
    this.hintObserver = null
    if (!on) return

    this.#labelHints()
    // Frames, morphs and pagination bring in new controls; label those too.
    this.hintObserver = new MutationObserver(() => {
      cancelAnimationFrame(this.hintFrame)
      this.hintFrame = requestAnimationFrame(() => this.#labelHints())
    })
    this.hintObserver.observe(document.body, { childList: true, subtree: true })
  }

  #labelHints() {
    document.querySelectorAll("[data-keys]").forEach(element => {
      const keys = element.dataset.keys.trim()
      if (!keys || keys === "null") return delete element.dataset.keyHint

      const hint = hintFor(keys)
      if (element.dataset.keyHint !== hint) element.dataset.keyHint = hint
    })
  }

  // Chords

  #startChord(event) {
    event.preventDefault()
    this.pending = "g"
    clearTimeout(this.chordTimer)
    this.chordTimer = setTimeout(() => { this.pending = null }, CHORD_TIMEOUT)
  }

  // A longer chord starts with this one (g w, with g w n declared somewhere).
  #extended(chord) {
    return Array.from(document.querySelectorAll("[data-keys]")).some(element =>
      usable(element) && element.dataset.keys.split(",").some(name => name.trim().startsWith(`${chord} `)))
  }

  #awaitThird(chord, event) {
    event.preventDefault()
    this.pending = chord
    this.chordTimer = setTimeout(() => {
      this.pending = null
      this.#trigger(chord, { preventDefault() {} })
    }, EXTEND_TIMEOUT)
  }

  // Declared keys

  #trigger(key, event) {
    const declared = Array.from(document.querySelectorAll("[data-keys]")).filter(element => declares(element, key) && usable(element))
    const element = declared.find(candidate => this.current?.contains(candidate)) || declared.find(candidate => !candidate.closest(ITEM))
    if (!element) return false

    event.preventDefault()
    if (element.hasAttribute("data-keys-focus")) {
      element.focus()
      element.select?.()
    } else {
      element.click()
    }
    return true
  }

  // Esc in a form opened in place, even from a field (where keys are otherwise the field's):
  // ReActionView state's Cancel, marked data-keys="esc", or else the <details> it opened in.
  #cancel(event) {
    if (event.target.closest?.("dialog[open]")) return false

    const cancel = Array.from(event.target.closest?.("form")?.querySelectorAll("[data-keys]") || []).find(element => declares(element, "esc"))
    const details = event.target.closest?.("details[open]")
    if (!cancel && !details) return false

    event.preventDefault()
    if (cancel) {
      cancel.click()
    } else {
      details.open = false
      details.querySelector("summary")?.focus()
    }
    return true
  }

  #save(event) {
    const form = event.target.closest?.("form") || document.activeElement?.closest("form")
    if (!form) return

    event.preventDefault()
    form.requestSubmit()
  }

  // Items

  #items() {
    return Array.from(document.querySelectorAll(ITEM)).filter(usable)
  }

  #step(delta, event) {
    const items = this.#items()
    if (!items.length) return

    let index = items.indexOf(this.current)
    if (index < 0) index = items.findIndex(item => item.contains(document.activeElement))
    index = index < 0 ? (delta > 0 ? 0 : items.length - 1) : Math.min(Math.max(index + delta, 0), items.length - 1)
    this.#select(items[index], event)
  }

  #select(item, event) {
    if (!item) return

    event?.preventDefault()
    this.#clear()
    this.current = item
    item.setAttribute("data-keyboard-current", "")
    if (!item.hasAttribute("tabindex")) item.tabIndex = -1
    item.focus({ preventScroll: true })
    item.scrollIntoView({ block: "nearest" })
  }

  #clear(event) {
    event?.preventDefault()
    if (this.current) {
      this.current.removeAttribute("data-keyboard-current")
      if (this.current === document.activeElement) this.current.blur()
    }
    this.current = null
  }

  #open(event) {
    const item = this.current
    if (!item?.isConnected) return false
    if (document.activeElement !== item && item.contains(document.activeElement)) return false

    const opener = item.matches(OPENER) ? item : item.querySelector(OPENER)
    if (!opener) return false

    event.preventDefault()
    opener.click()
    return true
  }

  // Board

  get #board() {
    return document.querySelector(".card-columns")
  }

  #boardKey(key, event) {
    if (BOARD_ARROWS[key]) {
      this.#relay(BOARD_ARROWS[key], event)
      return true
    }
    if (key === "H" || key === "L") {
      this.#moveCard(key === "L" ? 1 : -1, event)
      return true
    }
    if (key === "J" || key === "K") {
      this.#reorderCard(key === "J" ? 1 : -1, event)
      return true
    }
    return false
  }

  // Fizzy's navigable lists listen for arrow keys on the board, so hand them one.
  async #relay(arrow, event) {
    event.preventDefault()
    const board = this.#board
    if (!board.contains(document.activeElement)) {
      (board.querySelector("section.cards[aria-selected]") || board.querySelector("section.cards"))?.focus()
      await nextFrame()
      await nextFrame()
    }
    const target = board.contains(document.activeElement) ? document.activeElement : board
    target.dispatchEvent(new KeyboardEvent("keydown", { key: arrow, bubbles: true, cancelable: true }))
  }

  // The selected card, the focused one, or the one just moved (redrawn cards lose selection).
  #boardCard(board) {
    return board.querySelector("section.cards[aria-selected] .card[aria-selected]") || document.activeElement?.closest(".card") ||
      (this.movedId && board.querySelector(`.card[data-id="${this.movedId}"]`))
  }

  async #moveCard(delta, event) {
    event.preventDefault()
    const board = this.#board
    const card = this.#boardCard(board)
    if (!card) return

    const columns = Array.from(board.querySelectorAll("section.cards"))
    const from = card.closest("section.cards")
    const to = columns[columns.indexOf(from) + delta]
    if (!to) return

    const id = card.dataset.id
    const list = to.querySelector("[data-drag-drop-item-container]")
    const body = new FormData()
    // A sortable column takes the card at its top, where it shows up.
    if (to.hasAttribute("data-drag-and-drop-sortable")) body.append("before", list?.querySelector(".card[data-id]")?.dataset.id || "")
    adjustCount(from, -1)
    adjustCount(to, 1)
    list?.prepend(card)
    this.movedId = id
    await post(to.dataset.dragAndDropUrl.replaceAll("__id__", id), { body, headers: { Accept: "text/vnd.turbo-stream.html" } })
    from.querySelector("[data-drag-and-drop-refresh]")?.reload()
    await this.#pickUpAgain(board, card, id)
  }

  // J / K: a card one place down or up its column, kept there (the column's drop endpoint with
  // the card it now sits before).
  async #reorderCard(delta, event) {
    event.preventDefault()
    const board = this.#board
    const card = this.#boardCard(board)
    const column = card?.closest("section.cards")
    if (!column?.hasAttribute("data-drag-and-drop-sortable")) return

    const cards = Array.from(column.querySelectorAll(".card[data-id]"))
    const neighbour = cards[cards.indexOf(card) + delta]
    if (!neighbour) return

    delta > 0 ? neighbour.after(card) : neighbour.before(card)
    const next = cards.filter(other => other !== card)[cards.indexOf(card) + delta]
    const body = new FormData()
    body.append("before", delta > 0 ? (next?.dataset.id || "") : neighbour.dataset.id)

    const id = card.dataset.id
    this.movedId = id
    await post(column.dataset.dragAndDropUrl.replaceAll("__id__", id), { body, headers: { Accept: "text/vnd.turbo-stream.html" } })
    await this.#pickUpAgain(board, card, id)
  }

  async #pickUpAgain(board, card, id) {
    // The target column is redrawn from the server; wait for the card's new node, then pick it
    // up again so the next H or L keeps moving it.
    for (let i = 0; i < 20; i++) {
      await new Promise(resolve => setTimeout(resolve, 50))
      const moved = board.querySelector(`.card[data-id="${id}"]`)
      if (moved && moved !== card && moved.isConnected) {
        moved.dispatchEvent(new Event("mouseenter"))
        moved.focus()
        return
      }
    }
    const moved = board.querySelector(`.card[data-id="${id}"]`)
    moved?.dispatchEvent(new Event("mouseenter"))
    moved?.focus()
  }
}

// "j", "G", "?", "esc", "enter", "ctrl+enter", "meta+k": letters keep their case, so a
// shifted letter is its own key.
function describe(event) {
  let key = event.key
  if (key === "Escape") key = "esc"
  else if (key === " ") key = "space"
  else if (key.length > 1) key = key.toLowerCase()

  const modifiers = []
  if (event.ctrlKey) modifiers.push("ctrl")
  if (event.metaKey) modifiers.push("meta")
  if (event.altKey) modifiers.push("alt")
  return [ ...modifiers, key ].join("+")
}

// data-keys="s, mod+k": alternatives separated by commas; mod is ⌘ on a Mac, Ctrl elsewhere.
function declares(element, key) {
  return element.dataset.keys.split(",").map(name => name.trim().replace("mod", MOD)).includes(key)
}

// The first of a control's keys as people press it: "g c" stays a sequence, mod becomes ⌘ or
// Ctrl, and named keys get their names.
function hintFor(keys) {
  const NAMES = { esc: "Esc", enter: "Enter", space: "Space" }
  return keys.split(",")[0].trim().split(" ").map(stroke =>
    stroke.split("+").map(part => part === "mod" ? (MOD === "meta" ? "⌘" : "Ctrl") : (NAMES[part] || part)).join(MOD === "meta" ? "" : "+")
  ).join(" ")
}

function usable(element) {
  return !element.closest("[hidden], dialog:not([open])") && element.checkVisibility()
}

function adjustCount(column, delta) {
  const counter = column.querySelector("[data-drag-and-drop-counter]")
  if (counter && /^\d+$/.test(counter.textContent)) counter.textContent = Number(counter.textContent) + delta
}
