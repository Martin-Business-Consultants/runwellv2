// A record's own page, fields in place (record_fields/_zone in_place): a field that changes saves at
// once by submitting its own form (each field joins one by its form attribute, so only it is sent).
// Rich text is left to its Save button and ⌘/Ctrl+Enter, since it changes with every keystroke; a
// field inside an open popup (a combobox's filter box) has no form and is skipped. Nothing saves
// while the page is being arranged (template mode).
export default {
  connect(element) {
    element.saveOnChange ||= event => {
      // A date's change comes from its display and a multi-pick's from its wrapper: the form is
      // the one their hidden field joins.
      const form = event.target.form || event.target.closest(".layout-field")?.querySelector("input[form]")?.form
      if (!form || event.target.closest("lexxy-editor") || element.closest(".record-page--arranging")) return
      if (event.target.type !== "hidden" && !event.target.checkValidity()) return event.target.reportValidity()

      form.requestSubmit()
    }
    element.addEventListener("change", element.saveOnChange)
  },

  disconnect(element) {
    if (element.saveOnChange) element.removeEventListener("change", element.saveOnChange)
  }
}
