// A frame that's slow to arrive (the modal, holding a New form) shows a placeholder shaped like
// its content once it has taken longer than a blink (150ms): a copy of the <template> its
// data-loading-placeholder names, as the side panel shows one for a task. The frame's answer then
// replaces it (the timer stops as the answer starts rendering, which can take longer than the
// delay); a load that fails takes it away again. The copy's root is marked
// data-loading-placeholder-content (not data-placeholder, which UI SDK puts on an empty select).
const DELAY = 150

export default {
  connect(element) {
    element.placeholderStart ||= event => {
      if (event.target !== element) return

      clearTimeout(element.placeholderTimer)
      element.placeholderTimer = setTimeout(() => {
        const template = document.getElementById(element.dataset.loadingPlaceholder)
        if (template) element.replaceChildren(template.content.cloneNode(true))
      }, DELAY)
    }
    element.placeholderEnd ||= event => {
      if (event.target !== element) return

      clearTimeout(element.placeholderTimer)
      if (event.type !== "turbo:before-frame-render" && !event.detail?.fetchResponse?.succeeded && element.querySelector(":scope > [data-loading-placeholder-content]")) element.replaceChildren()
    }
    element.addEventListener("turbo:before-fetch-request", element.placeholderStart)
    element.addEventListener("turbo:before-frame-render", element.placeholderEnd)
    element.addEventListener("turbo:frame-render", element.placeholderEnd)
    element.addEventListener("turbo:fetch-request-error", element.placeholderEnd)
    element.addEventListener("turbo:frame-missing", element.placeholderEnd)
  },

  disconnect(element) {
    clearTimeout(element.placeholderTimer)
    element.removeEventListener("turbo:before-fetch-request", element.placeholderStart)
    element.removeEventListener("turbo:before-frame-render", element.placeholderEnd)
    element.removeEventListener("turbo:frame-render", element.placeholderEnd)
    element.removeEventListener("turbo:fetch-request-error", element.placeholderEnd)
    element.removeEventListener("turbo:frame-missing", element.placeholderEnd)
  }
}
