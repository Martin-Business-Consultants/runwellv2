// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "reactionview"
import { highlightCode } from "lexxy"

// Code blocks in rich text, coloured on the page as they are in the editor. Lexxy's highlighter
// skips blocks it has done, so running it after every Turbo render is safe.
for (const event of [ "turbo:load", "turbo:render", "turbo:frame-load" ]) {
  document.addEventListener(event, () => highlightCode())
}
