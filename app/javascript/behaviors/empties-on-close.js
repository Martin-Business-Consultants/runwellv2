// A frame holding a dialog that opens as it arrives (the modal and quick-action frames, holding a
// ui :dialog drawn open): once the dialog has closed (Esc, the ✕, Cancel, a press outside), the
// frame empties, so nothing closed is left behind for Turbo's snapshot to bring up again on Back.
// UI SDK's events don't bubble: listened for in the capture phase.
export default {
  connect(element) {
    element.emptyOnClose ||= event => {
      if (event.detail?.value !== false || !event.target.matches?.("ui-dialog")) return
      if (event.target.closest("turbo-frame") !== element) return

      element.replaceChildren()
    }
    element.addEventListener("openchangecomplete", element.emptyOnClose, true)
  },

  disconnect(element) {
    if (element.emptyOnClose) element.removeEventListener("openchangecomplete", element.emptyOnClose, true)
  }
}
