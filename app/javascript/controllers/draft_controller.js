import { Controller } from "@hotwired/stimulus"

// Runwell: what someone typed and hasn't sent is kept in this browser (localStorage, key value), so
// leaving the page, pressing Esc or losing the tab loses nothing: coming back puts it back, with a
// quiet "Draft restored" and Discard (the notice target, drawn by the server, draft_notice). A save
// that works clears it. Kept: what was typed, in text fields, text areas and rich text, whether
// they sit in the form or join it by its id (a record page's fields); never passwords, hidden
// fields or choices from a list. A field already holding something other than what the server
// drew is left as it is.
const TYPED = "input[name]:not([type=hidden], [type=password], [type=checkbox], [type=radio], [type=file], [type=submit], [type=button]), textarea[name], lexxy-editor[name]"

// An editor with no words and nothing attached is empty, however its markup reads (<p><br></p>).
function blankIfEmpty(html) {
  html ||= ""
  if (/<(img|action-text-attachment|figure)/.test(html)) return html
  return new DOMParser().parseFromString(html, "text/html").body.textContent.trim() ? html : ""
}

export default class extends Controller {
  static targets = [ "notice" ]
  static values = { key: String }

  connect() {
    this.save = this.save.bind(this)
    document.addEventListener("input", this.save)
    document.addEventListener("lexxy:change", this.save)
    this.element.addEventListener("turbo:submit-end", this.cleared = event => { if (event.detail.success) this.#forget() })
    this.#restore()
  }

  disconnect() {
    document.removeEventListener("input", this.save)
    document.removeEventListener("lexxy:change", this.save)
    this.element.removeEventListener("turbo:submit-end", this.cleared)
  }

  save(event) {
    if (event && !this.#fields().some(field => field === event.target || field.contains(event.target))) return

    const typed = {}
    for (const field of this.#fields()) {
      const value = this.#value(field)
      if (value !== this.#default(field)) typed[field.getAttribute("name")] = value
    }
    Object.keys(typed).length ? this.#write(typed) : this.#forget()
  }

  discard() {
    this.#fields().forEach(field => this.#set(field, this.#default(field)))
    this.#forget()
    delete this.element.dataset.dirty
  }

  #restore() {
    const typed = this.#read()
    if (!typed) return

    let restored = false
    this.#fields().forEach(field => {
      const value = typed[field.getAttribute("name")]
      if (value == null || this.#value(field) !== this.#default(field)) return
      this.#set(field, value)
      restored = true
    })
    if (!restored) return

    this.element.dataset.dirty = ""
    this.noticeTargets.forEach(notice => { notice.hidden = false })
  }

  // The form's own fields and those joining it by id (form="…"), the typed kind only.
  #fields() {
    const id = this.element.id
    const outside = id ? Array.from(document.querySelectorAll(`[form="${CSS.escape(id)}"]`)).filter(field => field.matches(TYPED)) : []
    return [ ...this.element.querySelectorAll(TYPED), ...outside ]
  }

  #value(field) {
    return field.localName === "lexxy-editor" ? blankIfEmpty(field.value) : field.value
  }

  // What the server drew: an editor's value attribute, a field's default value.
  #default(field) {
    return field.localName === "lexxy-editor" ? blankIfEmpty(field.getAttribute("value")) : field.defaultValue
  }

  #set(field, value) {
    if (field.localName === "lexxy-editor") {
      customElements.whenDefined("lexxy-editor").then(() => { field.value = value })
    } else {
      field.value = value
    }
  }

  get #storageKey() {
    return `draft:${this.keyValue}`
  }

  #read() {
    try { return JSON.parse(localStorage.getItem(this.#storageKey) || "null") } catch { return null }
  }

  #write(typed) {
    try { localStorage.setItem(this.#storageKey, JSON.stringify(typed)) } catch {}
  }

  #forget() {
    try { localStorage.removeItem(this.#storageKey) } catch {}
    this.noticeTargets.forEach(notice => { notice.hidden = true })
  }
}
