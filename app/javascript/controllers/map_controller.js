import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "latitudeField", "longitudeField", "coords"]
  static values = {
    latitude: Number,
    longitude: Number,
    hasCoordinates: Boolean,
    draggable: { type: Boolean, default: true }
  }

  connect() {
    if (typeof L === "undefined") {
      console.warn("Leaflet not loaded yet")
      return
    }

    const initialLat = this.latitudeValue
    const initialLng = this.longitudeValue
    const zoom = this.hasCoordinatesValue ? 15 : 5

    this.map = L.map(this.canvasTarget, {
      scrollWheelZoom: this.draggableValue
    }).setView([initialLat, initialLng], zoom)

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: "© OpenStreetMap contributors"
    }).addTo(this.map)

    if (this.hasCoordinatesValue) {
      this.addMarker(initialLat, initialLng)
    } else if (this.draggableValue) {
      this.map.on("click", (event) => {
        this.setPin(event.latlng.lat, event.latlng.lng)
      })
    }
  }

  addMarker(lat, lng) {
    if (this.marker) {
      this.marker.setLatLng([lat, lng])
    } else {
      this.marker = L.marker([lat, lng], { draggable: this.draggableValue }).addTo(this.map)
      if (this.draggableValue) {
        this.marker.on("dragend", (event) => {
          const { lat, lng } = event.target.getLatLng()
          this.updateFields(lat, lng)
        })
      }
    }
    if (this.draggableValue) this.updateFields(lat, lng)
  }

  setPin(lat, lng) {
    this.map.off("click")
    this.addMarker(lat, lng)
    this.map.setView([lat, lng], 15)
  }

  updateFields(lat, lng) {
    if (this.hasLatitudeFieldTarget) this.latitudeFieldTarget.value = lat.toFixed(6)
    if (this.hasLongitudeFieldTarget) this.longitudeFieldTarget.value = lng.toFixed(6)
    if (this.hasCoordsTarget) {
      this.coordsTarget.textContent = `Lat ${lat.toFixed(6)}, Lng ${lng.toFixed(6)}`
    }
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }
}
