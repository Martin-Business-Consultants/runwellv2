// A switch that saves the moment it's flipped (switch_field … submit_on_change): it already shows
// the change, so all that's left is to flip it back if the server refuses the save. With no answer
// at all (the network) it stays as flipped, marked unsaved, and is sent again once the connection
// is back (the connection controller). A save that works makes the new position the one to come
// back to.
export default {
  connect(element) {
    element.form?.addEventListener("turbo:submit-end", element.revertOnFailure ||= event => {
      if (event.detail.success) element.defaultChecked = element.checked
      else if (event.detail.fetchResponse) element.checked = element.defaultChecked
    })
    element.revertForm = element.form
  },

  disconnect(element) {
    element.revertForm?.removeEventListener("turbo:submit-end", element.revertOnFailure)
  }
}
