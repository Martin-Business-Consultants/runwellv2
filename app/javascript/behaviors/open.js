// A form opened in a <details> (Resolve, Record decision) focuses its autofocus field, which
// browsers leave alone. Dialogs share the attribute and focus themselves.
export default {
  connect(element) {
    if (element instanceof HTMLDetailsElement) element.querySelector("[autofocus]")?.focus()
  }
}
