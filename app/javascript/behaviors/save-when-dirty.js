// Rich text changed in place (a work's description): it doesn't save per keystroke. Once someone
// types in it the form is marked dirty, which shows its Save button (CSS: form[data-dirty]);
// ⌘/Ctrl+Enter saves too (the keyboard controller). Esc puts back what the server last drew and
// lets go of the field. The answer redraws the form, clean again.
export default {
  connect(element) {
    const editor = element.querySelector("lexxy-editor")
    if (!editor) return

    element.markDirty ||= () => {
      if (editor.contains(document.activeElement)) element.dataset.dirty = ""
    }
    element.revert ||= event => {
      if (event.key !== "Escape" || !("dirty" in element.dataset)) return

      event.preventDefault()
      event.stopPropagation()
      editor.value = editor.getAttribute("value") || ""
      delete element.dataset.dirty
      document.activeElement?.blur()
    }
    editor.addEventListener("lexxy:change", element.markDirty)
    element.addEventListener("keydown", element.revert, true)
  },

  disconnect(element) {
    element.querySelector("lexxy-editor")?.removeEventListener("lexxy:change", element.markDirty)
    if (element.revert) element.removeEventListener("keydown", element.revert, true)
  }
}
