import { Controller } from "@hotwired/stimulus"

// Something heavy kept off the page until it's wanted (the side panel's note editor, notes/_section
// with deferred: true): a <template> stamped in place of its trigger when the trigger is clicked,
// then its editor or first field focused.
export default class extends Controller {
  static targets = [ "template", "trigger" ]

  stamp() {
    this.triggerTarget.replaceWith(this.templateTarget.content.cloneNode(true))
    requestAnimationFrame(() => this.element.querySelector("lexxy-editor, input:not([type=hidden]), textarea")?.focus())
  }
}
