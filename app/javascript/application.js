// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "reactionview"
import "behaviors"
import { highlightCode } from "lexxy"

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
