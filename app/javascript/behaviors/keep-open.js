// A <details> marked keep-open stays open through a morph (a Turbo refresh, a stream that morphs its
// section): the page's answer is drawn with the server's idea of which are open, so without this every
// accordion someone opened would snap shut whenever anything on the page changed. Only closing is
// refused; the server may still open one (the section a task was just added to).
export default {
  connect(element) {
    element.keepOpen ||= event => {
      if (event.target === element && event.detail.attributeName === "open" && event.detail.mutationType === "removed") event.preventDefault()
    }
    element.addEventListener("turbo:before-morph-attribute", element.keepOpen)
  },

  disconnect(element) {
    if (element.keepOpen) element.removeEventListener("turbo:before-morph-attribute", element.keepOpen)
  }
}
