// Runwell's controllers (controllers/**/*_controller). The rune_* ones (rune-dialog, rune-popover,
// rune-sidebar…) are the rune_ui gem's, carried here when the gem came out; each goes as its
// markup moves to a runeui component (docs/runeui-migration.md).
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
import { installBusyButtons } from "helpers/busy_buttons"

installBusyButtons()
eagerLoadControllersFrom("controllers", application)
