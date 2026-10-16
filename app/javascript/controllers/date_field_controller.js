import { Controller } from "@hotwired/stimulus"
import { Datepicker } from "vanillajs-datepicker"

// Every date field (date_input in ApplicationHelper): a calendar on a read-only field showing the
// date ("Oct 20, 2026"), writing YYYY-MM-DD into the hidden field beside it, which is what the
// form sends. A click opens it (the calendar's own); in it, the arrows move, Enter picks, Esc closes; and on the field
// t picks today, + and - move a day, Backspace or Delete clears it. A change is announced as
// input and change on the field people see, so forms that save on change keep working. Both
// fields come from the server, so a morph puts them back as they should be; the calendar follows.
const FORMAT = "M d, yyyy"

export default class extends Controller {
  static targets = [ "value", "display" ]

  connect() {
    this.#build()
    this.changed = this.changed.bind(this)
    this.sync = this.#sync.bind(this)
    this.displayTarget.addEventListener("changeDate", this.changed)
    document.addEventListener("turbo:morph", this.sync)
  }

  disconnect() {
    this.displayTarget.removeEventListener("changeDate", this.changed)
    document.removeEventListener("turbo:morph", this.sync)
    this.picker?.destroy()
    this.picker = null
  }

  shortcut(event) {
    if (event.metaKey || event.ctrlKey || event.altKey) return

    switch (event.key) {
      case "t": case "T": this.picker.setDate(new Date()); break
      case "+": case "=": this.#shift(1); break
      case "-": case "_": this.#shift(-1); break
      case "Backspace": case "Delete":
        if (this.displayTarget.required) return
        this.picker.setDate({ clear: true })
        break
      default: return
    }
    event.preventDefault()
  }

  // The calendar picked (or cleared) a date: into the hidden field, then tell the form. A date
  // that's already the field's (setting it back after a morph) changes nothing.
  changed() {
    const date = this.picker.getDate()
    const value = date ? iso(date) : ""
    if (value === this.valueTarget.value) return

    this.valueTarget.value = value
    this.picker.hide() // before a form that saves on change redraws the page under it
    this.displayTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.displayTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  #shift(days) {
    const date = this.picker.getDate() || new Date()
    date.setDate(date.getDate() + days)
    this.picker.setDate(date)
  }

  #build() {
    // Started on an empty field and given the date from the hidden one: reading "Oct 20, 2026"
    // itself put the calendar's month years off.
    this.displayTarget.value = ""
    this.picker = new Datepicker(this.displayTarget, {
      format: FORMAT,
      autohide: true,
      todayHighlight: true,
      todayBtn: true,
      todayBtnMode: 1,
      clearBtn: !this.displayTarget.required,
      buttonClass: "btn txt-small",
      prevArrow: "‹",
      nextArrow: "›",
      updateOnBlur: false,
      showOnFocus: false,
      container: this.displayTarget.closest("dialog") || undefined
    })
    this.#sync()
  }

  // The calendar from the hidden field (on connect, and after a morph changed it). A morph also
  // drops the calendar's own element (it lives at the end of the page, which the server didn't
  // send), so it's built again.
  #sync() {
    if (!this.picker) return
    if (!this.picker.picker.element.isConnected) {
      this.picker.destroy()
      return this.#build()
    }
    const value = this.valueTarget.value
    value ? this.picker.setDate(local(value)) : this.picker.setDate({ clear: true })
  }
}

// YYYY-MM-DD as a local date (and back), so daylight saving can never slip a day.
function local(value) {
  const [ year, month, day ] = value.split("-").map(Number)
  return new Date(year, month - 1, day)
}

function iso(date) {
  const pad = (n) => String(n).padStart(2, "0")
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}
