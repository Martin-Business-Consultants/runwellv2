import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

// Runwell: adding documents (documents#create). The chosen or dropped files go straight to
// storage one at a time, their progress on the drop box, then the form posts their signed ids
// instead of the files. A file over the install's limit is refused before anything is sent.
export default class extends Controller {
  static targets = [ "input", "status", "progress" ]
  static values = { url: String, maxSize: Number }

  #fields = []

  async start() {
    const files = Array.from(this.inputTarget.files)
    if (files.length === 0) return

    const tooBig = files.find(file => file.size > this.maxSizeValue)
    if (tooBig) {
      this.inputTarget.value = ""
      this.#say(`${tooBig.name} is ${size(tooBig.size)}, over the ${size(this.maxSizeValue)} limit.`)
      return
    }

    this.#busy(true)
    const total = files.reduce((sum, file) => sum + file.size, 0)
    let sent = 0

    try {
      for (const [ index, file ] of files.entries()) {
        const count = files.length > 1 ? ` (${index + 1} of ${files.length})` : ""
        const signedId = await this.#upload(file, loaded => {
          const percent = Math.floor((sent + loaded) / total * 100)
          this.progressTarget.value = percent
          this.#say(`Uploading ${file.name}${count} · ${size(sent + loaded)} of ${size(total)} · ${percent}%`)
        })
        sent += file.size
        this.#field(signedId)
      }

      this.#say("Saving…")
      window.removeEventListener("beforeunload", this.#warn)
      this.element.requestSubmit()
    } catch (error) {
      this.#busy(false)
      this.#fields.forEach(field => field.remove())
      this.#fields = []
      this.inputTarget.value = ""
      this.#say(`The upload stopped: ${error}. Choose the files again to retry.`)
    }
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.#warn)
  }

  #upload(file, onProgress) {
    const delegate = {
      directUploadWillStoreFileWithXHR(request) {
        request.upload.addEventListener("progress", event => onProgress(event.loaded))
      }
    }

    return new Promise((resolve, reject) => {
      new DirectUpload(file, this.urlValue, delegate).create((error, blob) => {
        error ? reject(error) : resolve(blob.signed_id)
      })
    })
  }

  // The file input is disabled so the files aren't posted a second time; these carry them instead.
  #field(signedId) {
    const field = document.createElement("input")
    field.type = "hidden"
    field.name = this.inputTarget.name
    field.value = signedId
    this.element.append(field)
    this.#fields.push(field)
  }

  #busy(busy) {
    this.inputTarget.disabled = busy
    this.progressTarget.hidden = !busy
    this.progressTarget.value = 0
    this.element.toggleAttribute("aria-busy", busy)
    busy ? window.addEventListener("beforeunload", this.#warn) : window.removeEventListener("beforeunload", this.#warn)
  }

  #say(text) {
    this.statusTarget.textContent = text
  }

  #warn = event => event.preventDefault()
}

function size(bytes) {
  const units = [ "bytes", "KB", "MB", "GB" ]
  let value = bytes, unit = 0
  while (value >= 1024 && unit < units.length - 1) { value /= 1024; unit++ }
  return `${unit === 0 ? value : value.toFixed(value < 10 ? 1 : 0)} ${units[unit]}`
}
