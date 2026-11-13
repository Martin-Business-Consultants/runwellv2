# runeui trial (branch `runeui-trial`)

runeui (`../runeui`) is a component library on UI SDK's behaviours, with no build step. This
branch loads it beside rune_ui and converts one page, to see whether Runwell could move to it.

## What's wired

- `Gemfile`: `gem "runeui", path: "../runeui"`.
- `AppearanceHelper#app_stylesheet_tags`: after rune_ui's sheets,
  `runeui_tags(tokens: false, page: false, theme: false, confirm: false, toasts: false)` and
  `runeui/bridges/rune_ui`. So runeui brings only its components' styles; its tokens are defined
  from rune's on runeui's own parts (Appearance reaches them), light and dark stay Runwell's,
  and Runwell keeps its own confirm dialogs and toasts.
- `app/javascript/application.js`: `import "runeui"` (components autoload by tag; the morph guard).
- `/runeui` is runeui's gallery, in development.

## What's converted

Settings › Address (`settings/addresses/show`): the alert, both fields, the time zone list (a
searchable `form.ui :combobox` in place of Fizzy's combobox) and the Save buttons.
`runwell/settings.css` gives `ui-input` and `ui-combobox` the field's share of a `.settings-inline` row.

## What was checked

- Every other page is pixel-identical with and without runeui loaded (Tasks, the board, Clients,
  Work, a work page, Settings, Appearance, Intake, /ui), light theme, 1360×900.
- The converted page under ReActionView: labels name their controls, the combobox searches and
  picks, the form saves through `Settings::AddressesController` unchanged, the toast is
  Runwell's, the value is there after a reload. Light, dark and Round corners.
- `bin/rails test`, rubocop and herb lint pass.

## Not done, and what it would take

- This departs from "every select is Fizzy's combobox" (AGENTS.md) on one page, on purpose.
  Adopting runeui means deciding that rule, then converting `ComboboxFormBuilder`'s output.
- Runwell markup placed inside a runeui component inherits runeui's meaning of `--accent`,
  `--ring` and `--border` (Runwell's `--border` is a border shorthand): give it class `rune`,
  or keep Runwell markup outside runeui parts until `--border` is renamed.
- Keys: runeui components don't know Runwell's `data-keys` hints; a `data-keys` on a runeui
  button works as on any button.
- The gem is a path dependency; a release needs runeui on GitHub.
