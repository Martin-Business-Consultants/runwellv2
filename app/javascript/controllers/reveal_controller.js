import { Controller } from "@hotwired/stimulus"

// A secret field (secret_field): masked until the eye is clicked, masked again on a second click.
// secret_field is a helper used inside form_with blocks, where ReActionView state can't reach
// (helpers aren't compiled templates, and partials can't render in a form), so this flips the
// input's type and says so on the button.
export default class extends Controller {
  static targets = [ "input", "button" ]

  toggle() {
    const shown = this.inputTarget.type === "password"
    this.inputTarget.type = shown ? "text" : "password"
    this.element.classList.toggle("secret-field--shown", shown)
    this.buttonTarget.setAttribute("aria-pressed", shown)
    this.buttonTarget.title = shown ? "Hide" : "Show"
  }
}
