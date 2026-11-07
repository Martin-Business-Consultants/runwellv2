// Runwell's controllers (controllers/**/*_controller) and rune_ui's (rune-*, the UI kit).
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
import { registerRuneUi } from "rune_ui"

registerRuneUi(application)
eagerLoadControllersFrom("controllers", application)
