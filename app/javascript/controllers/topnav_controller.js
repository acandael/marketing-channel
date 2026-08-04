import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "opener"]

  connect() {
    this.onKey = (event) => { if (event.key === "Escape") this.close() }
    document.addEventListener("keydown", this.onKey)
    // Delay the transition until after first paint so the initial closed
    // state doesn't slide in from off-screen on mobile.
    requestAnimationFrame(() => this.menuTarget.classList.add("animating"))
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
  }

  open() {
    this.menuTarget.style.translate = "0 0"
    this.openerTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.menuTarget.style.translate = ""
    this.openerTarget.setAttribute("aria-expanded", "false")
  }
}
