// The modal frame: a form in it submits there, so a refused save comes back in the modal with what
// was typed. A save that goes on to a page of its own (a new piece of work, redirected to) has no
// modal in its answer: rather than Turbo's "content missing", the whole page visits that answer,
// using the response it already has.
export default {
  connect(element) {
    element.breakOut ||= event => {
      if (event.target !== element) return

      event.preventDefault()
      event.detail.visit(event.detail.response)
    }
    element.addEventListener("turbo:frame-missing", element.breakOut)
  },

  disconnect(element) {
    if (element.breakOut) element.removeEventListener("turbo:frame-missing", element.breakOut)
  }
}
