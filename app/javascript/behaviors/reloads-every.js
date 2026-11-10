// A frame that keeps itself fresh (the workspace rail): data-reloads-every="120" reloads it every
// two minutes while the page is in view, and once when the tab comes back after being hidden.
export default {
  connect(element) {
    const seconds = Number(element.dataset.reloadsEvery)
    if (!seconds || element.reloadTimer) return

    element.reloadTimer = setInterval(() => { if (!document.hidden) element.reload?.() }, seconds * 1000)
    element.reloadOnShow ||= () => { if (!document.hidden) element.reload?.() }
    document.addEventListener("visibilitychange", element.reloadOnShow)
  },

  disconnect(element) {
    clearInterval(element.reloadTimer)
    element.reloadTimer = null
    if (element.reloadOnShow) document.removeEventListener("visibilitychange", element.reloadOnShow)
  }
}
