import { Controller } from "@hotwired/stimulus"

// Manages inline name editing and auto-polling for video blocks
export default class extends Controller {
  static values = {
    videoId: Number,
    ready: Boolean,
    statusUrl: String
  }

  static targets = ["player"]

  connect() {
    if (!this.readyValue && this.statusUrlValue) {
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.pollTimer = setInterval(() => this.checkStatus(), 5000)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async checkStatus() {
    try {
      const response = await fetch(this.statusUrlValue, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      if (!response.ok) return

      const data = await response.json()

      if (data.ready && data.player_html) {
        this.stopPolling()
        this.readyValue = true
        if (this.hasPlayerTarget) {
          this.playerTarget.innerHTML = data.player_html
        }
      }
    } catch (e) {
      // Silently retry on next interval
    }
  }

  editName(event) {
    const viewName = event.currentTarget
    const editName = viewName.nextElementSibling

    viewName.classList.add('d-none')
    editName.classList.remove('d-none')
    editName.querySelector('input').focus()
  }

  saveName(event) {
    const input = event.currentTarget
    const name = input.value

    fetch(this.statusUrlValue, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ video: { name: name } })
    })
    .then(() => {
      const editName = input.closest('.name-edit')
      const viewName = editName.previousElementSibling

      viewName.textContent = name || 'Click to add name...'
      viewName.classList.remove('d-none')
      editName.classList.add('d-none')
    })
  }

  cancelName(event) {
    const editName = event.currentTarget.closest('.name-edit')
    const viewName = editName.previousElementSibling

    viewName.classList.remove('d-none')
    editName.classList.add('d-none')
  }
}
