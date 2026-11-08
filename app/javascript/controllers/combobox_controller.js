import { Controller } from "@hotwired/stimulus"

// Fizzy's combobox: a popup of choices (role=checkbox items) writing the chosen value into a
// hidden field. Runwell: the field may come from the server (field target, every form select,
// ComboboxHelper) so a morph keeps it; with blankSubmits a blank choice is sent as "" (a select's
// include_blank) rather than left out; and a pick fires change on the field, so a form that saves
// on change (change->form#submit) does.

export default class extends Controller {
  #hiddenField

  static targets = [ "label", "item", "hiddenFieldTemplate", "field" ]
  static values = {
    selectPropertyName: { type: String, default: "aria-checked" },
    defaultValue: String,
    defaultLabel: String,
    blankSubmits: Boolean
  }
  static classes = ["withDefault"]

  connect() {
    this.#selectedItem = this.#selectedItem
  }

  change(event) {
    const item = event.target.closest("[role='checkbox']")
    if (item) {
      const before = this.hasFieldTarget || this.#hiddenField ? this.hiddenField.value : null
      this.#selectedItem = item
      if (this.hiddenField.value !== before) this.hiddenField.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  get #selectedLabel() {
    const selectedValue = this.#selectedItemValue()

    if (this.hasDefaultLabelValue && (selectedValue === this.defaultValueValue || !selectedValue)) {
      return this.defaultLabelValue
    }

    return this.#selectedItem?.dataset?.comboboxLabel || ""
  }

  get #selectedItem() {
    return this.itemTargets.find(item => item.getAttribute(this.selectPropertyNameValue) === "true")
  }

  #selectedItemValue() {
    return this.#selectedItem?.dataset?.comboboxValue || ""
  }

  set #selectedItem(item) {
    if (!item) return

    this.#clearSelection()
    item.setAttribute(this.selectPropertyNameValue, "true")
    this.labelTarget.textContent = this.#selectedLabel
    this.hiddenField.value = item.dataset.comboboxValue
    this.hiddenField.disabled = !item.dataset.comboboxValue && !this.blankSubmitsValue
    this.#updateWithDefaultClass()
  }

  #clearSelection() {
    this.itemTargets.forEach(target => {
      target.setAttribute(this.selectPropertyNameValue, "false")
    })
  }

  get hiddenField() {
    if (this.hasFieldTarget) return this.fieldTarget
    if (!this.#hiddenField) {
      this.#hiddenField = this.#buildHiddenField()
    }
    return this.#hiddenField
  }

  #buildHiddenField() {
    const [field] = this.hiddenFieldTemplateTarget.content.cloneNode(true).children
    this.element.appendChild(field)
    return field
  }

  #updateWithDefaultClass() {
    if (this.hasWithDefaultClass && this.hasDefaultValueValue) {
      const selectedValue = this.#selectedItemValue()
      const shouldHaveClass = selectedValue === this.defaultValueValue

      if (shouldHaveClass) {
        this.element.classList.add(this.withDefaultClass)
      } else {
        this.element.classList.remove(this.withDefaultClass)
      }
    }
  }
}
