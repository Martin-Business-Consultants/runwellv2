// ReActionView behaviors: JavaScript that follows elements as reactive templates add, move and
// remove them (https://reactionview.dev/guides/stimulus-and-turbo#behaviors). Each file exports
// the callbacks for one attribute: connect, enter (only for elements a state change just built),
// updated, moved, settled, leave and disconnect, each given the element and its context.
import { Runtime } from "reactionview"
import open from "behaviors/open"

const BEHAVIORS = { open }

// The runtime starts itself in a microtask once reactionview loads; define on it right after.
queueMicrotask(() => {
  const runtime = Runtime.get()
  for (const [ attribute, behavior ] of Object.entries(BEHAVIORS)) runtime?.behaviors.define(attribute, behavior)
})
