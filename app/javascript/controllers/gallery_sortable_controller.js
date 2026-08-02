import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      draggable: ".gallery-manage__item",
      filter: ".gallery-manage__delete, .gallery-manage__delete *",
      preventOnFilter: false,
      ghostClass: "gallery-manage__item--drag-ghost",
      onEnd: this.persist.bind(this)
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  async persist() {
    const ids = Array.from(this.element.querySelectorAll("[data-attachment-id]"))
      .map((el) => el.dataset.attachmentId)
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    const body = new FormData()
    ids.forEach((id) => body.append("order[]", id))

    await fetch(this.urlValue, {
      method: "PATCH",
      headers: { "X-CSRF-Token": token, "Accept": "application/json" },
      body
    })
  }
}
