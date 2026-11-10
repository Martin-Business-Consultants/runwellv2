// Starts ReActionView's runtime with Runwell's options, then defines its behaviors.
//
// refetch: "off". Every state change runs in the browser (client-mode templates, forms hidden rather
// than branched; see AGENTS.md), so nothing ever needs the server to re-render a page. Left on
// ("auto"), any page with a server-side `if` asked for itself again whenever its DOM changed: each
// page of cards loading, each morph. That was a whole-page render on the server every time, and it
// failed wherever a helper's block renders a partial (card grids, the board, notifications).
// debounce: 150 is ReActionView's own default, which these options replace.
//
// Behaviors are JavaScript that follows elements as reactive templates add, move and remove them
// (https://reactionview.dev/guides/stimulus-and-turbo#behaviors). Each file exports the callbacks
// for one attribute: connect, enter (only for elements a state change just built), updated, moved,
// settled, leave and disconnect, each given the element and its context.
import { Runtime } from "reactionview"
import open from "behaviors/open"
import keepOpen from "behaviors/keep-open"
import saveOnChange from "behaviors/save-on-change"
import saveWhenDirty from "behaviors/save-when-dirty"
import picksCurrent from "behaviors/picks-current"
import revertOnFailure from "behaviors/revert-on-failure"
import keepsScroll from "behaviors/keeps-scroll"
import loadingPlaceholder from "behaviors/loading-placeholder"
import breaksOut from "behaviors/breaks-out"

const BEHAVIORS = { open, "keep-open": keepOpen, "save-on-change": saveOnChange, "save-when-dirty": saveWhenDirty, "picks-current": picksCurrent, "revert-on-failure": revertOnFailure, "keeps-scroll": keepsScroll, "loading-placeholder": loadingPlaceholder, "breaks-out": breaksOut }

const runtime = Runtime.start({ state: { debounce: 150, refetch: "off" } })
for (const [ attribute, behavior ] of Object.entries(BEHAVIORS)) runtime.behaviors.define(attribute, behavior)
