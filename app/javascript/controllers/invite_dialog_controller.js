import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "email"]

  open(event) {
    event?.preventDefault()
    if (!this.hasDialogTarget) return
    this.dialogTarget.showModal()
    if (this.hasEmailTarget) {
      this.emailTarget.focus()
      this.emailTarget.select()
    }
  }

  close(event) {
    event?.preventDefault()
    if (!this.hasDialogTarget) return
    this.dialogTarget.close()
  }
}
