// Pages fetched ahead of a visit the keys are about to make: the row j / k landed on (its plain
// link, the one Enter follows) and, once g is pressed, the pages its second key reaches. Turbo's
// own prefetch keeps one page, for the link under the mouse; this keeps a few, for ten seconds, and
// hands the visit that asks for one its response (turbo:before-fetch-request's fetchRequest, as
// Turbo and the side panel do). Each response is used once: a body reads once.
const TTL = 10_000
const KEPT = 8
const prefetched = new Map

let listening = false

export function prefetchLink(link) {
  if (!prefetchable(link)) return
  listen()

  const url = new URL(link.href, document.baseURI).toString()
  const kept = prefetched.get(url)
  if (kept && Date.now() - kept.at < TTL) return

  const response = fetch(url, {
    credentials: "same-origin", priority: "low",
    headers: { Accept: "text/html, application/xhtml+xml", "X-Sec-Purpose": "prefetch" }
  })
  response.catch(() => { if (prefetched.get(url)?.response === response) prefetched.delete(url) })
  prefetched.delete(url)
  prefetched.set(url, { response, at: Date.now() })
  while (prefetched.size > KEPT) prefetched.delete(prefetched.keys().next().value)
}

// Turbo's rules for what it may fetch ahead: same site, a page (not the one you're on), no
// target, no method, not opted out (data-turbo-prefetch="false", data-turbo="false").
function prefetchable(link) {
  if (!link?.matches?.("a[href]:not([target]):not([download])")) return false
  if (link.origin !== location.origin || link.pathname + link.search === location.pathname + location.search) return false
  if (link.closest("[data-turbo-prefetch='false'], [data-turbo='false']")) return false
  if (link.hasAttribute("data-turbo-method") || link.hasAttribute("data-turbo-confirm") || link.hasAttribute("data-turbo-stream")) return false
  if (link.getAttribute("data-turbo-frame") && link.getAttribute("data-turbo-frame") !== "_top") return false
  return document.querySelector("meta[name='turbo-prefetch']")?.content !== "false"
}

function listen() {
  if (listening) return
  listening = true

  document.addEventListener("turbo:before-fetch-request", event => {
    const { fetchOptions, fetchRequest, url } = event.detail || {}
    if (event.target.tagName === "FORM" || fetchOptions?.method !== "GET" || fetchRequest || !url) return
    if (fetchOptions.headers?.["Turbo-Frame"]) return

    const kept = prefetched.get(url.toString())
    prefetched.delete(url.toString())
    if (kept && Date.now() - kept.at < TTL) event.detail.fetchRequest = { response: kept.response }
  }, true)
}
