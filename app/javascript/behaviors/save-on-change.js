// A record's own page, fields in place (record_fields/_zone in_place): a field that changes saves at
// once by submitting its own form (each field joins one by its form attribute, so only it is sent).
// Rich text is left to its Save button and ⌘/Ctrl+Enter, since it changes with every keystroke; a
// field that joins no form (a combobox's box to type in, on its own) is skipped. Nothing saves
// while the page is being arranged (template mode).
export default {
  connect(element) {
    element.saveOnChange ||= event => {
      // A runeui control fires change itself or from a field inside it (a date typed in, a number):
      // the form is the one the control joins by its form attribute.
      const control = event.target.closest("[form]")
      const form = control ? document.getElementById(control.getAttribute("form")) : event.target.form
      if (!form || event.target.closest("lexxy-editor") || element.closest(".record-page--arranging")) return
      if (control?.checkValidity && !control.checkValidity()) return control.reportValidity?.()

      form.requestSubmit()
    }
    element.addEventListener("change", element.saveOnChange)
  },

  disconnect(element) {
    if (element.saveOnChange) element.removeEventListener("change", element.saveOnChange)
  }
}
