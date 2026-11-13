import { Controller } from "@hotwired/stimulus"

// Search (layouts/shared/_search, runeui's palette, which stays on the page from visit to visit):
// it opens empty each time, as the old bar did, so closing it clears what was typed and its
// results. (runeui's dialog fires openchange on itself; it doesn't bubble.)
export default class extends Controller {
  closed({ detail }) {
    if (detail?.value !== false) return
    const command = this.element.querySelector("ui-command")
    if (command?.query) command.api?.setQuery?.("")
  }
}
