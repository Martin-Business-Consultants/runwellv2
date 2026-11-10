// A row of tabs that load into a frame (a record page's tabs, a work's List / Board switch): the
// one clicked is current at once, before its frame arrives; the frame's old content dims meanwhile
// (CSS, on the frame's aria-busy). A click that opens elsewhere (⌘, Shift, middle) changes nothing.
export default {
  connect(element) {
    element.picksCurrent ||= event => {
      const tab = event.target.closest("a.tabs__tab")
      if (!tab || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

      element.querySelectorAll("a.tabs__tab").forEach(other => other.setAttribute("aria-current", other === tab ? "page" : "false"))
    }
    element.addEventListener("click", element.picksCurrent)
  },

  disconnect(element) {
    if (element.picksCurrent) element.removeEventListener("click", element.picksCurrent)
  }
}
