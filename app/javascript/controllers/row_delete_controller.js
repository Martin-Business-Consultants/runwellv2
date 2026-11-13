import { Controller } from "@hotwired/stimulus"

// A table row on its way out (row_delete_button, row_remove_button): once its delete is sent (after
// the confirm dialog's yes, where there is one) the row fades at once; the answer removes it, or a
// refusal brings it back.
export default class extends Controller {
  // turbo:submit-start on the row's delete form
  leave({ target }) {
    target.closest("tr")?.classList.add("is-leaving")
  }

  // turbo:submit-end: refused or failed, the row comes back
  settle({ target, detail }) {
    if (!detail.success) target.closest("tr")?.classList.remove("is-leaving")
  }
}
