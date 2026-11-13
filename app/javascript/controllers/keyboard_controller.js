import { Controller } from "@hotwired/stimulus"
import { prefetchLink } from "helpers/page_prefetch"

// Every key the app answers to, vim style, in one place (on <body>). Letters act outside
// inputs and open dialogs; ⌘/Ctrl+Enter saves from anywhere in a form.
//
// - j / k, g g / G walk the page's items (anything marked data-filter-target="item"),
//   Enter or o opens the one you're on, Esc drops it
// - a chord starting with g goes somewhere: any element declaring data-keys="g c". A chord may
//   take a third key (data-keys="g t n"): after g t it waits a moment for one, vim style, and
//   with none (or another) does g w
// - every other key clicks the visible element declaring it (data-keys="e"), or focuses it
//   (data-keys-focus). One inside the current item wins over the page's own, so e and d
//   act on the row you're on
// - on the board, h j k l move between cards and H J K L move the card you're on (runeui's board,
//   handed the arrows), posting to the same drop endpoint a drag would
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
const SELECTED_KEY = "keyboardSelected"

// A Back or Forward visit brings a page back: once it's loaded, its row is picked again (#reselect).
let restoring = false
document.addEventListener("turbo:visit", event => { restoring = event.detail.action === "restore" })
document.addEventListener("turbo:load", () => {
  if (restoring) requestAnimationFrame(() => document.dispatchEvent(new CustomEvent("keyboard:restore")))
  restoring = false
})

const OPENER = ":is(a[href], button):not(.row-action):not([data-keys])"
const CHORD_TIMEOUT = 1500
const EXTEND_TIMEOUT = 600 // how long g w waits for a third key before it goes
const MOD = /Mac|iPhone|iPad/.test(navigator.platform) ? "meta" : "ctrl"
const BOARD_ARROWS = { j: "ArrowDown", k: "ArrowUp", h: "ArrowLeft", l: "ArrowRight" }
const HINTS_KEY = "keyHints"

// What takes the keys for itself while it's open: a <dialog>, and runeui's dialogs, sheets and
// menus (UI SDK's elements, which close on Esc and move through their own items).
const OVERLAY = "dialog[open], [aria-modal='true'][data-open], ui-menu-content, ui-popover-content"
const MODAL = "dialog:modal, [aria-modal='true'][data-open]"

export default class extends Controller {
  connect() {
    this.keydown = this.keydown.bind(this)
    this.focusin = this.focusin.bind(this)
    document.addEventListener("keydown", this.keydown)
    document.addEventListener("focusin", this.focusin)
    this.#showHints(this.#storedHints)
    this.reselect = () => this.#reselect()
    document.addEventListener("keyboard:restore", this.reselect)
  }

  disconnect() {
    document.removeEventListener("keydown", this.keydown)
    document.removeEventListener("focusin", this.focusin)
    document.removeEventListener("keyboard:restore", this.reselect)
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
    if (event.isComposing) return
    const key = describe(event)

    // Before the check below: Lexxy marks every Enter handled, ⌘/Ctrl+Enter too, and that's the
    // one place it's needed.
    if (key === `${MOD}+enter`) return this.#save(event)
    if (event.defaultPrevented) return
    if (key === "esc" && this.#cancel(event)) return
    if (event.target.closest?.(TYPING) || event.target.closest?.(OVERLAY) || document.querySelector(MODAL)) return

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
    // A runeui control that handles its own key says which in aria-keyshortcuts (the nav's
    // toggle, [): hint mode shows that too.
    document.querySelectorAll(":is(button, a)[aria-keyshortcuts]:not([data-keys])").forEach(element => {
      if (element.dataset.keyHint !== element.ariaKeyShortcuts) element.dataset.keyHint = element.ariaKeyShortcuts
    })
  }

  // Chords

  #startChord(event) {
    event.preventDefault()
    this.#prefetchChords()
    this.pending = "g"
    clearTimeout(this.chordTimer)
    this.chordTimer = setTimeout(() => { this.pending = null }, CHORD_TIMEOUT)
  }

  // g was pressed: the pages its second key reaches (the nav's g c, g w…) are fetched ahead, once
  // per page, so the visit that follows is served at once (helpers/page_prefetch).
  #prefetchChords() {
    if (this.chordsPrefetched === location.href) return
    this.chordsPrefetched = location.href

    document.querySelectorAll("a[data-keys]").forEach(link => {
      if (link.dataset.keys.split(",").some(name => /^g \S+$/.test(name.trim()))) prefetchLink(link)
    })
  }

  // A longer chord starts with this one (g t, with g t n declared somewhere).
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
    if (event.target.closest?.(OVERLAY)) return false

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

  // The form a field belongs to: its own (a field outside it names it with form="…"), the one
  // around it, or the one a group of fields outside it names (data-form-for, a record page's
  // sidebar of properties).
  #save(event) {
    const element = event.target.closest ? event.target : document.activeElement
    const form = element?.form || element?.closest("form") ||
      document.getElementById(element?.closest("[data-form-for]")?.dataset.formFor || "")
    if (!form) return

    event.preventDefault()
    form.requestSubmit()
  }

  // Items

  // The page's items, not the side panel's (its notes), so j / k keep moving down the list.
  #items() {
    return Array.from(document.querySelectorAll(ITEM)).filter(item => usable(item) && !item.closest(".task-panel"))
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
    item.dispatchEvent(new CustomEvent("keyboard:select", { bubbles: true }))
    this.#prefetchOpener(item)
    this.#remember(item)
  }

  // Back to a list puts you on the row you were on: the item's id, kept per address for the tab
  // (sessionStorage), picked again when a restoration visit (Back, Forward) brings the page back.
  #remember(item) {
    if (!item.id) return
    try { sessionStorage.setItem(`${SELECTED_KEY}:${location.pathname}${location.search}`, item.id) } catch {}
  }

  #reselect() {
    let id
    try { id = sessionStorage.getItem(`${SELECTED_KEY}:${location.pathname}${location.search}`) } catch {}
    const item = id && document.getElementById(id)
    if (item && this.#items().includes(item)) this.#select(item)
  }

  // The page Enter would open from the item you're on, fetched ahead (a task's link opens the side
  // panel instead, which fetches its own).
  #prefetchOpener(item) {
    const opener = this.#opener(item)
    if (opener?.matches("a[href]") && !opener.matches("[data-action*='side-panel#open']")) prefetchLink(opener)
  }

  #clear(event) {
    event?.preventDefault()
    if (this.current) {
      this.current.removeAttribute("data-keyboard-current")
      if (this.current === document.activeElement) this.current.blur()
    }
    this.current = null
  }

  // What Enter opens on an item: the item itself, else the link in the cell that names a table's
  // row (data-grow: a picker may come before it, as a task's owner does), else its first link or
  // button.
  #opener(item) {
    if (item.matches(OPENER)) return item
    return item.querySelector(`[data-grow] ${OPENER}`) || item.querySelector(OPENER)
  }

  #open(event) {
    const item = this.current
    if (!item?.isConnected) return false
    if (document.activeElement !== item && item.contains(document.activeElement)) return false

    const opener = this.#opener(item)
    if (!opener) return false

    event.preventDefault()
    opener.click()
    return true
  }

  // Board

  get #board() {
    return document.querySelector("[data-slot=board].task-board")
  }

  // runeui's board moves between its cards with the arrows and moves a card with Shift and an
  // arrow (posting to its column's drop endpoint), so h j k l are handed to the card you're on as
  // arrows, and H J K L as Shift with them. The card it lands on becomes the current item, so the
  // side panel follows as it does down a list.
  #boardKey(key, event) {
    const arrow = BOARD_ARROWS[key.toLowerCase()]
    if (!arrow) return false

    event.preventDefault()
    const card = this.#boardCard()
    if (!card) return true

    card.dispatchEvent(new KeyboardEvent("keydown", { key: arrow, shiftKey: key !== key.toLowerCase(), bubbles: true, cancelable: true }))
    requestAnimationFrame(() => {
      const now = document.activeElement?.closest?.("[data-slot=board-card]")
      if (now && now !== this.current) this.#select(now)
    })
    return true
  }

  // The card in focus, else the current one (focused now), else the first: then nothing more
  // happens this time, the first key only puts you on the board.
  #boardCard() {
    const board = this.#board
    const focused = document.activeElement?.closest?.("[data-slot=board-card]")
    if (focused && board.contains(focused)) return focused

    const current = this.current?.matches?.("[data-slot=board-card]") && board.contains(this.current) ? this.current : null
    if (current) { current.focus(); return current }

    const first = Array.from(board.querySelectorAll("[data-slot=board-card]")).find(card => card.checkVisibility())
    if (first) { first.focus(); this.#select(first) }
    return null
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

// A key on something out of sight (a closed menu, a hidden dialog) does nothing, unless the element
// says it works from anywhere (data-keys-anywhere: Settings, in the account menu, is g s).
function usable(element) {
  if (element.hasAttribute("data-keys-anywhere")) return true
  return !element.closest("[hidden], dialog:not([open])") && element.checkVisibility()
}
