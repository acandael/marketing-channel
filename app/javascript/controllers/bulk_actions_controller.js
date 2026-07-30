import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "bar", "checkbox", "toggleAll", "count"]

  connect() {
    this.refresh()
  }

  toggle() {
    this.refresh()
  }

  toggleAll(event) {
    const checked = event.target.checked
    this.checkboxTargets.forEach((cb) => { cb.checked = checked })
    this.refresh()
  }

  refresh() {
    const selected = this.checkboxTargets.filter((cb) => cb.checked).length
    if (this.hasCountTarget) this.countTarget.textContent = selected
    if (this.hasBarTarget) this.barTarget.classList.toggle("is-visible", selected > 0)
    if (this.hasToggleAllTarget) {
      const total = this.checkboxTargets.length
      this.toggleAllTarget.checked = total > 0 && selected === total
      this.toggleAllTarget.indeterminate = selected > 0 && selected < total
    }
  }
}
