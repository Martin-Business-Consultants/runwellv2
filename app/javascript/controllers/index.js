// Runwell's controllers (controllers/**/*_controller). The rune_* ones (rune-clipboard,
// rune-local-time) are the rune_ui gem's, carried for the compatibility layer's helpers
// (copy_button, time_ago) that plugins call; they go with it (docs/runeui-migration.md).
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
import { installBusyButtons } from "helpers/busy_buttons"

installBusyButtons()
eagerLoadControllersFrom("controllers", application)
