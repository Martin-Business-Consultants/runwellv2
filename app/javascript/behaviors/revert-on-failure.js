// A switch that saves the moment it's flipped (switch_field … submit_on_change): it already shows
// the change, so all that's left is to flip it back if the save fails (no answer, or refused).
// A save that works makes the new position the one to come back to.
export default {
  connect(element) {
    element.form?.addEventListener("turbo:submit-end", element.revertOnFailure ||= event => {
      if (event.detail.success) element.defaultChecked = element.checked
      else element.checked = element.defaultChecked
    })
    element.revertForm = element.form
  },

  disconnect(element) {
    element.revertForm?.removeEventListener("turbo:submit-end", element.revertOnFailure)
  }
}
