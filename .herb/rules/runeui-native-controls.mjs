// Managed by runeui (bin/rails runeui:lint keeps it current): edit runeui, not this copy.
// runeui-native-controls: a Herb linter rule (herb-tools.dev) that keeps an app's templates on
// runeui's components. It flags a control runeui draws for you, written by hand or by a Rails
// helper that draws the browser's own:
//
//   <button>, <input>, <select>, <textarea>, <dialog>, <table> (not runeui's: no ui-* class, no
//   data-slot); tag.button, content_tag(:select…), button_tag, check_box_tag, select_tag and the
//   other *_tag fields; button_to without class "ui-button"; form.text_field and the other form
//   builder fields the app's builder doesn't draw with runeui (config/runeui.yml, form_builder).
//
// A deliberate one says why, on its line or the line above:
//
//   <%# runeui:allow native-control — a bare trigger, one menu per page %>
//
// It reads config/runeui.yml (skip, form_builder, wrappers), the same file bin/rails runeui:lint
// reads. Self-contained (no imports), so it loads from .herb/rules/ without node_modules.

import { readFileSync, existsSync } from "node:fs"
import { join, isAbsolute, relative } from "node:path"

const RULE = "runeui-native-controls"
const MARKER = "native-control"

const ELEMENTS = {
  button: "ui :button (or class \"ui-button\" with data-variant on a button_to)",
  input: "ui :input (form.ui :input), or ui :checkbox / :switch / :radio_group / :date_picker / :file_input",
  select: "ui :select or ui :combobox (form.ui :select)",
  textarea: "ui :textarea (form.ui :textarea)",
  dialog: "ui :dialog, ui :alert_dialog or ui :sheet",
  table: "ui :table"
}

const INPUT_TYPES_ALLOWED = new Set(["hidden"])
const NOT_COMPONENT_CLASSES = new Set(["ui-sr-only", "ui-icon"])

const TAG_HELPERS = /\b(button_tag|submit_tag|image_submit_tag|check_box_tag|checkbox_tag|radio_button_tag|text_field_tag|email_field_tag|password_field_tag|search_field_tag|number_field_tag|telephone_field_tag|phone_field_tag|url_field_tag|date_field_tag|datetime_field_tag|datetime_local_field_tag|time_field_tag|month_field_tag|week_field_tag|color_field_tag|range_field_tag|file_field_tag|text_area_tag|textarea_tag|select_tag)\b/
const TAG_BUILDER = /\btag\.(button|input|select|textarea|dialog|table)\b|\bcontent_tag[ (]+:(button|input|select|textarea|dialog|table)\b/
const BUTTON_TO = /\bbutton_to\b/
// A form builder by its usual names (form, f, builder, fields, *_form, form_*): Enumerable#select
// on a collection isn't one.
const FORM_FIELDS = /\b(form|f|builder|fields|form_builder|\w+_form|form_\w+|\w+_fields)\.(text_field|email_field|password_field|search_field|number_field|telephone_field|phone_field|url_field|date_field|datetime_field|datetime_local_field|time_field|month_field|week_field|color_field|range_field|file_field|text_area|textarea|check_box|checkbox|radio_button|select|collection_select|grouped_collection_select|time_zone_select|collection_check_boxes|collection_checkboxes|collection_radio_buttons|submit|button)\b(?!\?)/g

// config/runeui.yml, read by hand: the file is a few lists and true/false, so no YAML library
// (which a rule in .herb/rules/ couldn't import) is needed. Nested keys and flow style aren't read.
function readConfig(root) {
  const config = { skip: [], form_builder: [], wrappers: [] }
  const path = root && join(root, "config/runeui.yml")
  if (!path || !existsSync(path)) return config
  let key = null
  for (const raw of readFileSync(path, "utf8").split("\n")) {
    const line = raw.replace(/\s+#.*$/, "")
    if (!line.trim() || line.trim().startsWith("#")) continue
    const top = line.match(/^([a-z_]+):\s*(.*)$/)
    if (top) {
      key = top[1]
      const value = top[2].trim()
      if (value === "[]") config[key] = []
      else if (value) config[key] = value.replace(/^["']|["']$/g, "")
      else config[key] = []
      continue
    }
    const item = line.match(/^\s+-\s+(.+)$/)
    if (item && key && Array.isArray(config[key])) config[key].push(item[1].trim().replace(/^["']|["']$/g, ""))
  }
  return config
}

function globToRegExp(glob) {
  let out = ""
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i]
    if (c === "*" && glob[i + 1] === "*") { out += ".*"; i++; if (glob[i + 1] === "/") i++ }
    else if (c === "*") out += "[^/]*"
    else if (c === "?") out += "[^/]"
    else out += c.replace(/[.+^${}()|[\]\\]/g, "\\$&")
  }
  return new RegExp(`^${out}$`)
}

const configs = new Map()
function configFor(root) {
  if (!configs.has(root)) configs.set(root, readConfig(root))
  return configs.get(root)
}

function text(nodes) {
  return (nodes || []).map(node => {
    if (node.type === "AST_LITERAL_NODE") return node.content
    if (node.type === "AST_RUBY_LITERAL_NODE") return `<%${node.content}%>`
    if (node.content && typeof node.content.value === "string") return `<%${node.content.value}%>`
    return ""
  }).join("")
}

function attributes(openTag) {
  const out = {}
  for (const child of openTag?.children || []) {
    if (child.type !== "AST_HTML_ATTRIBUTE_NODE") continue
    out[text(child.name?.children).toLowerCase()] = child.value ? text(child.value.children) : ""
  }
  return out
}

// A whole line, shaped as Herb's own locations are (it serialises them with toJSON).
function lineLocation(line, length) {
  const location = { start: { line, column: 0 }, end: { line, column: length } }
  location.toJSON = () => ({ start: location.start, end: location.end })
  return location
}

function walk(node, visit) {
  if (!node) return
  visit(node)
  for (const child of node.compactChildNodes?.() || []) walk(child, visit)
}

// runeui's own markup: a ui-* class (ui-button, ui-item, ui-input…) or a data-slot.
function runeuiMarkup(attrs) {
  if ("data-slot" in attrs) return true
  const value = attrs.class || ""
  if (/["' ]ui-button\b/.test(` ${value}`) && value.includes("<%")) return true
  return value.split(/\s+/).some(name => name.startsWith("ui-") && !NOT_COMPONENT_CLASSES.has(name))
}

export default class RuneuiNativeControls {
  static ruleName = RULE
  static type = "parser"

  get defaultConfig() {
    return { enabled: true, severity: "error", exclude: [] }
  }

  get parserOptions() {
    return {}
  }

  check(result, context = {}) {
    const root = context.projectPath || process.cwd()
    const file = context.fileName && (isAbsolute(context.fileName) ? context.fileName : join(root, context.fileName))
    const config = configFor(root)
    const path = file ? relative(root, file) : ""
    if (config.skip.some(glob => globToRegExp(glob).test(path))) return []

    const source = file && existsSync(file) ? readFileSync(file, "utf8").split("\n") : []
    const allowed = new Set()
    const offenses = []
    const add = (message, location) => offenses.push({ rule: RULE, code: RULE, source: "Herb Linter", message, location })
    source.forEach((line, index) => {
      const marker = line.match(/runeui:allow\s+([\w-]+)(.*)/)
      if (!marker || marker[1] !== MARKER) return
      if (!marker[2].replace(/%>.*$/, "").replace(/^[\s—–:-]+/, "").trim()) {
        add("Say why after runeui:allow native-control (`runeui:allow native-control — why`).", lineLocation(index + 1, line.length))
        return
      }
      allowed.add(index + 1)
      allowed.add(index + 2)
    })
    const flag = (message, location) => {
      if (!location || allowed.has(location.start.line)) return
      add(`${message} (A deliberate one: runeui:allow native-control — why.)`, location)
    }
    const builder = new Set(config.form_builder)
    const wrapped = code => config.wrappers.some(name => new RegExp(`\\b${name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`).test(code))

    walk(result.value, node => {
      if (node.type === "AST_HTML_ELEMENT_NODE") {
        const name = node.tag_name?.value?.toLowerCase()
        if (!ELEMENTS[name]) return
        const attrs = attributes(node.open_tag)
        if (name === "input" && INPUT_TYPES_ALLOWED.has((attrs.type || "").toLowerCase())) return
        if (runeuiMarkup(attrs)) return
        flag(`<${name}> isn't runeui's: use ${ELEMENTS[name]}.`, node.open_tag?.location || node.location)
        return
      }

      const code = node.type?.startsWith("AST_ERB_") && node.content && typeof node.content.value === "string" ? node.content.value : null
      if (code === null || node.tag_opening?.value?.startsWith("<%#")) return

      if (TAG_HELPERS.test(code) && !wrapped(code) && !/["' ]ui-/.test(code)) {
        flag(`\`${code.match(TAG_HELPERS)[1]}\` is the browser's own control: use runeui's (ui :input, :checkbox, :select, :button…).`, node.location)
      }
      const built = code.match(TAG_BUILDER)
      if (built && !/["' ]ui-/.test(code)) {
        const name = built[1] || built[2]
        flag(`\`${built[0]}\` draws a <${name}>: use ${ELEMENTS[name]}.`, node.location)
      }
      if (BUTTON_TO.test(code) && !/\bui-button\b/.test(code)) {
        flag("`button_to` without class \"ui-button\" is a bare <button>: give it class: \"ui-button\" (data: { variant:, size: }).", node.location)
      }
      for (const match of code.matchAll(FORM_FIELDS)) {
        const method = match[2]
        if (builder.has(method) || wrapped(code) || /["' ]ui-/.test(code)) continue
        flag(`\`${match[1]}.${method}\` is the browser's own control: use ${match[1]}.ui, or list ${method} under form_builder in config/runeui.yml if the app's builder draws it with runeui.`, node.location)
      }
    })

    return offenses
  }
}
