import { Controller } from "@hotwired/stimulus"

// Runwell: a row's in-place picker (a task's status, who's on it, its due date; a client's status).
// The row carries only a button; the choices are one runeui popup on the page (menu value: a
// ui :menu, a ui :combobox with no trigger, a ui :popover holding a calendar), which the button
// opens beside itself (data-runeui-open). As it opens, this controller takes the popup over for
// its record: marks what's current, and hears the choice. A choice shows at once, while a form
// copied from a <template> (form value) and pointed at this record (url value) saves it; the
// answer then replaces the picker with what was saved (or puts it back, with the reason, if it
// was refused). If the save fails outright (no answer, or an error), the choice is put back.
//
// kind "status" (also a client's): one choice from a menu. A task's (task value) in a list that
// won't keep it (marked done in an Open list: the list names the statuses it keeps,
// data-task-list-keeps, from Task::List#keeps) fades its row at once; the answer then removes it.
// kind "owners" (Fizzy's assignments): current lists everyone on it, each pick turns one on or
// off and the list stays open; the avatars and names beside it (stack, empty and names targets)
// change at once from each person's own avatar template.
// kind "due": a date from a calendar, or its Today and No date buttons; t picks today.
export default class extends Controller {
  static targets = [ "display", "stack", "empty", "names" ]
  static values = { kind: { type: String, default: "status" }, current: String, menu: String, form: String, url: String, labelled: Boolean, task: String, due: String, field: String }

  connect() {
    this.confirmed = this.currentValue
    this.submitted = this.submitted.bind(this)
    this.element.addEventListener("turbo:submit-end", this.submitted)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.submitted)
    this.#release()
  }

  // The button was pressed (runeui opens the popup beside it right after): the popup is this
  // record's until it closes or another row takes it.
  open() {
    const menu = document.getElementById(this.menuValue)
    if (!menu) return

    menu.pickerOwner?.release()
    this.menu = menu
    menu.pickerOwner = { release: () => this.#release() }
    this.listeners = this.#listeners(menu)
    this.listeners.forEach(([ target, type, handler, capture ]) => target.addEventListener(type, handler, capture))
    this.#mark(menu)
  }

  #release() {
    this.listeners?.forEach(([ target, type, handler, capture ]) => target.removeEventListener(type, handler, capture))
    this.listeners = null
    if (this.menu?.pickerOwner) this.menu.pickerOwner = null
    this.menu = null
  }

  // UI SDK's events don't bubble: each is heard on the element that fires it.
  #listeners(menu) {
    switch (this.kindValue) {
      case "owners":
        return [ [ menu, "valuechange", event => this.#toggled(event) ] ]
      case "due": {
        const calendar = menu.querySelector("ui-calendar")
        return [
          [ calendar, "valuechange", event => { if (event.detail.reason !== "imperative") this.#date(event.detail.value || "") } ],
          [ menu, "click", event => { const button = event.target.closest("[data-picker-set]"); if (button) this.#date(button.dataset.pickerSet) } ],
          [ menu, "keydown", event => { if (event.key === "t" && !event.metaKey && !event.ctrlKey && !event.altKey) { event.preventDefault(); this.#date(menu.querySelector("[data-picker-today]")?.dataset.pickerSet || today()) } } ]
        ]
      }
      default:
        return [ [ menu, "action", event => this.#chose(event.detail.value) ] ]
    }
  }

  // What's current, shown in the popup as it opens for this record.
  #mark(menu) {
    if (this.kindValue === "owners") {
      this.#sync(menu)
      menu.querySelectorAll("[data-picker-value]").forEach(item => {
        // Away on the task's due date (data-picker-away, from Runwell::Plugins.away): marked Out.
        item.toggleAttribute("data-away-on-due", !!this.dueValue && (item.dataset.pickerAway || "").split(" ").includes(this.dueValue))
      })
    } else if (this.kindValue === "due") {
      const calendar = menu.querySelector("ui-calendar")
      calendar.api?.setValue(this.currentValue || null)
      calendar.api?.setMonth((this.currentValue || today()).slice(0, 7))
    } else {
      menu.querySelectorAll("[data-picker-value]").forEach(item => item.toggleAttribute("data-picker-current", item.dataset.pickerValue === this.currentValue))
    }
  }

  // The list's ticks from who's on it, without that counting as a pick.
  #sync(menu) {
    this.syncing = true
    menu.api?.setValue(this.#chosen)
    this.syncing = false
  }

  // One choice from a menu: show it now, fade the row if its list won't keep it, and save.
  #chose(value) {
    const item = this.menu?.querySelector(`[data-picker-value="${CSS.escape(value)}"]`)
    if (!item || value === this.currentValue) return

    this.#leaving(value)
    this.#display(item)
    this.currentValue = value
    this.#save(value)
  }

  // Someone ticked or unticked in the list: who's on it now, in order (the first leads), drawn at
  // once; the one who changed is what's sent (the server turns them on or off).
  #toggled(event) {
    if (this.syncing) return

    const now = [].concat(event.detail.value ?? []).map(String)
    const before = this.#chosen
    const changed = now.find(id => !before.includes(id)) || before.find(id => !now.includes(id))
    if (!changed) return

    const chosen = before.filter(id => id !== changed)
    if (now.includes(changed)) chosen.push(changed)
    this.#show(chosen)
    this.#save(changed)
  }

  // A date (or none) from the calendar or its buttons.
  #date(value) {
    if (value !== this.currentValue) {
      this.currentValue = value
      this.#showDate(value)
      this.#save(value)
    }
    if (this.menu) this.menu.open = false
  }

  // The form, copied from its template and pointed at this record, sent, and dropped again.
  #save(value) {
    const template = document.getElementById(this.formValue)
    if (!template) return

    const form = template.content.firstElementChild.cloneNode(true)
    form.action = this.urlValue
    form.hidden = true
    form.querySelector("[data-picker-field]").value = value
    if (this.labelledValue) this.#hidden(form, "labelled", "1")
    if (this.kindValue === "status" && this.taskValue) this.#list(form)
    this.element.querySelectorAll("form.picker-form").forEach(old => old.remove())
    this.element.append(form)
    form.requestSubmit()
  }

  // In a Tasks list (data-task-list: which list, its filter, the section in focus), the change
  // says so, and the answer brings that list back as it now stands. From the side panel, which
  // sits in no list, it's the list on the page underneath (one per page), and it says it came
  // from the panel: a task that leaves the list closes the panel too.
  #list(form) {
    const panel = this.#panel
    const list = this.#taskList
    if (panel) this.#hidden(form, "panel", "1")
    if (list) {
      this.#hidden(form, "list[kind]", list.dataset.taskList)
      if (list.dataset.taskListState) this.#hidden(form, "list[state]", list.dataset.taskListState)
      if (list.dataset.taskListItem) this.#hidden(form, "list[item]", list.dataset.taskListItem)
    }
  }

  get #panel() {
    return this.element.closest(".task-panel:not(.peek-panel)")
  }

  get #taskList() {
    return this.element.closest("[data-task-list]") || (this.#panel && document.querySelector("[data-task-list]"))
  }

  #hidden(form, name, value) {
    const input = document.createElement("input")
    Object.assign(input, { type: "hidden", name, value })
    form.append(input)
  }

  // The save is answered: keep what it said, or, when it failed (no answer, or an error page), put
  // back what was there. A refusal is an answer: its stream redraws the picker as it was.
  submitted({ detail: { success } }) {
    if (success) {
      this.confirmed = this.currentValue
      return
    }

    if (this.kindValue === "owners") {
      this.#show(this.confirmed.split(",").filter(Boolean))
      if (this.menu) this.#sync(this.menu)
    } else if (this.kindValue === "due") {
      this.currentValue = this.confirmed
      this.#showDate(this.confirmed)
    } else {
      this.currentValue = this.confirmed
      const item = document.getElementById(this.menuValue)?.querySelector(`[data-picker-value="${CSS.escape(this.confirmed)}"]`)
      if (item) this.#display(item)
      this.#leavingRow?.classList.remove("task-leaving")
    }
  }

  get #chosen() {
    return this.currentValue.split(",").filter(Boolean)
  }

  // The trigger's parts (the dot, the label, a badge) from the chosen item's.
  #display(item) {
    this.displayTargets.forEach(display => {
      const source = item.querySelector(`[data-picker-part="${display.dataset.pickerPart}"]`)
      if (source) display.replaceChildren(...Array.from(source.cloneNode(true).childNodes))
    })
  }

  #showDate(value) {
    const display = this.displayTargets[0]
    if (!display) return

    display.textContent = value ? local(value).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" }) : "No date"
    display.closest("button")?.toggleAttribute("data-empty", !value)
  }

  // Who's on it, in order (the first leads), drawn in the trigger the way task_owners_tag draws
  // them (three avatars, then +N): the group from the page's template, each avatar from its
  // person's own.
  #show(chosen) {
    this.currentValue = chosen.join(",")
    const menu = document.getElementById(this.menuValue)
    if (!menu) return

    const people = chosen.map(id => menu.querySelector(`[data-picker-value="${CSS.escape(id)}"]`)).filter(Boolean)
    const template = document.getElementById("task-owner-stack")

    if (this.hasStackTarget && template) {
      const [ stack, more ] = Array.from(template.content.cloneNode(true).children)
      people.slice(0, 3).forEach(person => {
        const avatar = person.querySelector("template[data-picker-avatar]")
        if (avatar) stack.append(avatar.content.cloneNode(true))
      })
      if (people.length > 3) {
        more.textContent = `+${people.length - 3}`
        stack.append(more)
      }
      this.stackTarget.replaceChildren(...(people.length ? [ stack ] : []))
    }
    if (this.hasEmptyTarget) this.emptyTarget.hidden = people.length > 0
    if (this.hasNamesTarget) {
      const names = people.map(person => person.getAttribute("label")).filter(Boolean)
      this.namesTarget.textContent = names.length ? new Intl.ListFormat("en", { type: "conjunction" }).format(names) : "Unassigned"
    }
  }

  // A task's new status, in a list that won't keep it: its row fades at once, and the answer removes
  // it. From the side panel, that's the row of the list underneath.
  #leaving(status) {
    if (!this.taskValue || !status || status === this.currentValue) return

    const keeps = this.#taskList?.dataset.taskListKeeps?.split(" ")
    if (!keeps || keeps.includes(status)) return

    const row = this.#panel ? (document.getElementById(`row_task_${this.taskValue}`) || document.getElementById(`item_task_${this.taskValue}`))
      : this.element.closest("[data-filter-target~=item]")
    row?.classList.add("task-leaving")
    this.#leavingRow = row
  }

  #leavingRow = null
}

// YYYY-MM-DD as a local date (and today as one), so daylight saving can never slip a day.
function local(value) {
  const [ year, month, day ] = value.split("-").map(Number)
  return new Date(year, month - 1, day)
}

function today() {
  const now = new Date()
  const pad = (n) => String(n).padStart(2, "0")
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`
}
