import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "spinner"]

  submit() {
    this.buttonTarget.disabled = true
    this.buttonTarget.textContent = ""
    this.spinnerTarget.classList.remove("d-none")
  }
}
