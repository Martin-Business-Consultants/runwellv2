// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "reactionview"
import "behaviors"
// runeui (trial): UI SDK's components, autoloaded by tag, and their Hotwire layer.
import "runeui"
import { highlightCode } from "lexxy"

// Staff pages link the manifest: they register the service worker (the offline page, pushed
// notifications; app/views/pwa/service-worker.js.erb), once, at load.
if ("serviceWorker" in navigator && document.querySelector("link[rel=manifest]")) {
  navigator.serviceWorker.register("/service-worker.js", { scope: "/" }).catch(() => {})
}

// Turbo's progress bar after 200ms rather than 500, so a slower page says it's coming.
if (window.Turbo?.config) window.Turbo.config.drive.progressBarDelay = 200

// <turbo-stream action="close_side_panel">: an answer closing the side panel (a task marked done from
// it leaves the list under it). The side-panel controller closes it the way ✕ does, history included.
if (window.Turbo?.StreamActions) {
  window.Turbo.StreamActions.close_side_panel = () => document.dispatchEvent(new CustomEvent("side-panel:close-requested"))
}

// Lexxy's Prism has no JSON: the grammar from Prism's own json component, for code_block.
window.Prism.languages.json ||= {
  property: { pattern: /(^|[^\\])"(?:\\.|[^\\"\r\n])*"(?=\s*:)/, lookbehind: true, greedy: true },
  string: { pattern: /(^|[^\\])"(?:\\.|[^\\"\r\n])*"(?!\s*:)/, lookbehind: true, greedy: true },
  comment: { pattern: /\/\/.*|\/\*[\s\S]*?(?:\*\/|$)/, greedy: true },
  number: /-?\b\d+(?:\.\d+)?(?:e[+-]?\d+)?\b/i,
  punctuation: /[{}[\],]/,
  operator: /:/,
  boolean: /\b(?:false|true)\b/,
  null: { pattern: /\bnull\b/, alias: "keyword" }
}

// Code blocks in rich text and code_block snippets, coloured on the page as they are in the
// editor. Lexxy's highlighter skips blocks it has done, so running it after every Turbo render
// (and morph, which puts back the plain text) is safe.
for (const event of [ "turbo:load", "turbo:render", "turbo:frame-load", "turbo:morph" ]) {
  document.addEventListener(event, () => highlightCode())
}
