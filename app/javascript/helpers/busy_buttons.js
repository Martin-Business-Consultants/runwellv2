// Whichever button sent a form shows it's working until the answer comes back, and can't be
// pressed twice (.btn[aria-busy] draws a spinner; runeui's button dims). From the rune_ui gem's
// index.js, carried here when the gem came out (docs/runeui-migration.md, phase 1).
let installed = false

export function installBusyButtons() {
  if (installed) return
  installed = true
  document.addEventListener("turbo:submit-start", ({ detail }) => {
    const button = detail.formSubmission.submitter
    if (button) { button.setAttribute("aria-busy", "true"); button.disabled = true }
  })
  document.addEventListener("turbo:submit-end", ({ detail }) => {
    const button = detail.formSubmission.submitter
    if (button) { button.removeAttribute("aria-busy"); button.disabled = false }
  })
}
