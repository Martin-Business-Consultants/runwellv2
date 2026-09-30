import { Controller } from "@hotwired/stimulus"

// Money is integer cents. People type dollars ("1,500", "$1500.5"); the hidden field the form
// submits always holds whole cents, and the visible one tidies itself to "1,500.50" on blur.
// Text that isn't an amount leaves the hidden field empty, so the server refuses it rather
// than guessing.
export default class extends Controller {
  static targets = [ "display", "cents" ]

  update() {
    const cents = this.#toCents(this.displayTarget.value)
    this.centsTarget.value = cents === null ? "" : cents
  }

  format() {
    const cents = this.#toCents(this.displayTarget.value)
    if (cents !== null) this.displayTarget.value = cents === 0 ? "" : this.#toDollars(cents)
  }

  // Whole-number arithmetic on the digits, never floats: 0.1 + 0.2 is not a price.
  #toCents(text) {
    const clean = text.replace(/[$,\s]/g, "")
    if (clean === "") return 0

    const match = clean.match(/^(-?)(\d*)(?:\.(\d{0,2}))?$/)
    if (!match || (match[2] === "" && !match[3])) return null

    const [ , sign, dollars, fraction = "" ] = match
    const cents = Number(dollars || "0") * 100 + Number(fraction.padEnd(2, "0"))
    return sign ? -cents : cents
  }

  #toDollars(cents) {
    const sign = cents < 0 ? "-" : ""
    const absolute = Math.abs(cents)
    const dollars = Math.floor(absolute / 100).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    return `${sign}${dollars}.${String(absolute % 100).padStart(2, "0")}`
  }
}
