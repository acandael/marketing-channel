import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "field", "tag"]
  static values = { name: String }

  keydown(event) {
    if (event.key === "Enter" || event.key === ",") {
      event.preventDefault()
      this.commit()
    } else if (event.key === "Backspace" && this.fieldTarget.value === "") {
      const tags = this.tagTargets
      if (tags.length > 0) tags[tags.length - 1].remove()
    }
  }

  commit() {
    const raw = this.fieldTarget.value.trim().replace(/,+$/, "").trim()
    if (raw === "") return

    const existing = this.tagTargets.map((el) => el.dataset.value?.toLowerCase() || el.textContent.trim().toLowerCase())
    if (existing.includes(raw.toLowerCase())) {
      this.fieldTarget.value = ""
      return
    }

    const tag = document.createElement("span")
    tag.className = "tag-input__tag"
    tag.dataset.tagInputTarget = "tag"
    tag.dataset.value = raw
    tag.innerHTML = `${this.escape(raw)}
      <button type="button" class="tag-input__remove" data-action="tag-input#remove" aria-label="Remove ${this.escape(raw)}">×</button>
      <input type="hidden" name="${this.nameValue}" value="${this.escape(raw)}">`

    this.containerTarget.insertBefore(tag, this.fieldTarget)
    this.fieldTarget.value = ""
  }

  remove(event) {
    event.target.closest(".tag-input__tag")?.remove()
  }

  escape(str) {
    return str.replace(/[&<>"']/g, (c) => ({
      "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
    })[c])
  }
}
