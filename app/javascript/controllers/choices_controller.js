import { Controller } from "@hotwired/stimulus"
import Choices from "choices.js"

// A select drawn as a combobox (Choices.js, every form select through ComboboxFormBuilder): its
// choices in a menu styled like the app's, with a filter box once there are more than a few. The
// <select> stays the field the form sends, and Choices fires change on it, so forms that save on
// change keep working. Turbo morphs pages and streamed sections against the server's plain
// <select>, which would fight Choices' markup, so the combobox comes down before Turbo renders,
// caches or applies a stream, and goes back up after.
const FILTER_FROM = 8

export default class extends Controller {
  connect() {
    this.teardown = this.teardown.bind(this)
    this.setupSoon = this.setupSoon.bind(this)
    for (const name of [ "turbo:before-render", "turbo:before-cache", "turbo:before-stream-render" ]) document.addEventListener(name, this.teardown)
    for (const name of [ "turbo:render", "turbo:load" ]) document.addEventListener(name, this.setupSoon)
    this.setup()
  }

  disconnect() {
    for (const name of [ "turbo:before-render", "turbo:before-cache", "turbo:before-stream-render" ]) document.removeEventListener(name, this.teardown)
    for (const name of [ "turbo:render", "turbo:load" ]) document.removeEventListener(name, this.setupSoon)
    this.teardown()
  }

  setup() {
    if (this.choices || !this.element.isConnected || this.element.closest("template")) return

    this.choices = new Choices(this.element, {
      searchEnabled: this.element.options.length >= FILTER_FROM,
      searchPlaceholderValue: "Type to filter…",
      shouldSort: false,
      itemSelectText: "",
      allowHTML: false,
      position: "auto",
      noResultsText: "Nothing matches",
      noChoicesText: "Nothing to choose"
    })
  }

  // After a render or a stream lands (a stream has no "rendered" event: the next frame).
  setupSoon() {
    requestAnimationFrame(() => this.setup())
  }

  teardown(event) {
    if (!this.choices) return
    // A stream that doesn't touch this select leaves it be.
    if (event?.type === "turbo:before-stream-render" && !this.#streamReaches(event.target)) return

    this.choices.destroy()
    this.choices = null
    if (event?.type === "turbo:before-stream-render") this.setupSoon()
  }

  #streamReaches(stream) {
    const targets = stream.targetElements || []
    return targets.some(target => target === this.element || target.contains(this.element))
  }
}
