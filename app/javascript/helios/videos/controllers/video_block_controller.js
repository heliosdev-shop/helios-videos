import { Controller } from "@hotwired/stimulus"

// Manages inline name editing for video blocks
export default class extends Controller {
  static values = {
    videoId: Number
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

    fetch(`/helios_videos/admin/videos/${this.videoIdValue}`, {
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
