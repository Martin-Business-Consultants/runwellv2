// An element that scrolls on its own and comes back on every page (the sidenav): where it was
// scrolled to is kept by its id as it scrolls, and put back when a visit brings the new one in, so
// a long nav doesn't jump to the top on every click. Lasts as long as the tab (a full reload starts
// at the top).
const positions = new Map

export default {
  connect(element) {
    if (!element.id) return

    const top = positions.get(element.id)
    if (top) element.scrollTop = top
    element.keepScroll ||= () => positions.set(element.id, element.scrollTop)
    element.addEventListener("scroll", element.keepScroll, { passive: true })
  },

  disconnect(element) {
    if (element.keepScroll) element.removeEventListener("scroll", element.keepScroll)
  }
}
