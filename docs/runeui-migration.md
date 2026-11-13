# Moving Runwell to runeui (6.0)

Runwell's whole interface moves onto runeui (`../runeui`: components on UI SDK's behaviours,
shadcn/ui's look and tokens, no build step), with nothing left of rune_ui or of the pieces taken
from Fizzy. Branch `runeui-trial`. `docs/runeui-trial.md` is how the trial went.

## Decisions (Ted, 2026-11-13)

1. **Area by area.** One area at a time, Runwell working and `bin/rails test`, rubocop and
   `herb lint` passing after each, each area its own commit. rune_ui and the old CSS go at the
   end, once nothing uses them.
2. **Plugins keep running: a compatibility layer, then migrate.** This is 6.0. The helper names
   and classes the plugin contract promises (`badge`, `card`, `button_link`, `icon_tag`, `field`,
   `.btn`, `.card`, `.table`…) keep working, drawn by runeui, so the twelve plugins run unchanged.
   Each plugin moves to runeui's API afterwards; then the layer goes.
3. **shadcn's look and tokens.** Its default look and token names outright. Appearance's schemes
   and corners become shadcn themes; custom CSS becomes a pasted shadcn theme. Themes written
   against the old token guide stop working (docs/theming.md is rewritten).
4. **Features stay, rebuilt on runeui.** The keyboard system (j/k, g-chords, hint mode) stays as
   Runwell's own code. Search and quick actions go onto the command palette, the sheet onto
   `ui :side_panel`, the board onto `ui :board`. Lexxy stays (shadcn has no rich text editor),
   with runeui's skin.

## How the two kits share a page until the end

The vocabularies collide (`--accent` and `--ring` mean different things; Runwell's `--border` is
a border shorthand), so until the old CSS is gone runeui is linked as in the trial:
`runeui_tags(tokens: false, page: false, theme: false, confirm: false, toasts: false)` then
`runeui/bridges/rune_ui`, which defines runeui's tokens on runeui's own parts from the page's.
The page's tokens keep their old names and meanings for whatever is still old (and for plugins).
The look changes by changing those tokens' values, not their names. The last phase flips this:
runeui's tokens on `:root`, the bridge and the old names gone.

## Phases

Each phase lists what replaces what. "Done" means no call site of the old thing is left in the
core (plugins go through the compatibility layer).

0. **The look.** The palette, corners, control sizes and type take shadcn's defaults
   (`_global.css`, `appearance.css`, `rune-theme.css`): neutral by default, the schemes as
   shadcn's colour themes, corners from `--radius`. Everything on the page, old and new, shifts
   together, so nothing looks half-moved while the rest follows.
1. **The compatibility layer** (`app/helpers/rune_compat_helper.rb`, `runwell/compat.css`):
   rune_ui's helpers reimplemented on runeui (`button_link`, `action_button`, `submit_button`,
   `icon_button`, `button_classes`, `badge`, `card`, `list_row`, `field`, `empty_state`, `menu`,
   `popover_menu`, `menu_link`, `menu_button`, `dialog`, `sheet`, `confirm_dialog`, `tabs`,
   `callout`, `avatar`, `avatar_stack`, `settings_group`, `setting_row`, `switch`, `segmented`,
   `copy_button`, `progress_bar`, `icon_tag`, `flash_messages`, `crumbs`), the classes
   (`btn`, `icon-button`, `pill`, `card`, `list-row`, `field`, `badge`, `count`, `tabs`, `alert`,
   `table`, `dl.details`, `empty`, `stack`, `grid-2`, `button-row`, `separator`, `kbd`, `muted`,
   `faint`, `small`, `visually-hidden`) styled from runeui's tokens, and Runwell's icons as
   runeui icons (`Runeui::Icons.register`). Then the rune_ui gem comes out of the Gemfile.
2. **The shell**: `app_shell`, the sidenav, the panel bar and breadcrumb → `ui :app_shell`,
   `ui :sidebar_group`, `ui :sidebar_item`, `ui :breadcrumb`; `NavLayout` and the per-person menu
   kept. Toasts → `ui :toaster` (`turbo_stream_flash` → `turbo_stream.ui_toast`); every
   `delete_dialog`, `row_delete_dialog` and `layouts/shared/confirm` → `ui :alert_dialog` /
   `data-turbo-confirm`.
3. **Lists**: `ui/_data_table` → `ui :table` with `selectable:`, `ui :sort_header`,
   `ui :select_cell`, `ui :bulk_bar`, `ui :pagination` (geared_pagination's pages kept);
   `quick_filter` → `ui :filter` / `ui :filter_bar`; the Columns menu → `ui :menu`.
4. **Pickers and forms**: `ComboboxFormBuilder`, `combobox_tag`, the status and owner pickers,
   `popup_menu` → `ui :select`, `ui :combobox`, `ui :menu`; `date_input` → `ui :date_picker`;
   `switch_field` → `ui :switch`; `money_field` → `ui :number_input` (cents kept);
   `rich_text_field` → `ui :editor`; fields → `form.ui :field`. Custom fields follow.
5. **Record pages and the sheet**: record page cards and tabs → `ui :card`, `ui :tabs`; the task
   panel and peek → `ui :side_panel` (`?task=`, `?peek=` kept as the address); the in-place
   field forms kept (save-on-change), on runeui controls.
6. **The board**: `tasks/board/*`, `columns/*`, the Fizzy drag-and-drop → `ui :board`
   (`Task#move!`, `before`, one endpoint).
7. **Search, quick actions, keys**: the bar and tray → `ui :command, dialog: true`; the keyboard
   controller kept, pointed at runeui's markup (`data-keys` unchanged); hint mode kept.
8. **Settings, public pages and the portal**: every settings page, sign-in and its showcase, the
   portal's pages and sheet.
9. **The flip and the clean-up**: runeui's tokens on `:root`, the bridge out; the old sheets
   (`rune-theme`, what's left of `runwell/*`), Fizzy's controllers and the unused behaviors
   deleted; AGENTS.md, docs/theming.md, docs/plugin-contract.md rewritten; VERSION 6.0.0.
10. **Plugins**, one repository at a time, onto runeui's API; then the compatibility layer goes
    (7.0, as the contract says).

## Rules while it's in progress

- runeui's own rules hold (`../runeui/AGENTS.md`): elements built with `ui_tag`, no inline
  handlers, Stimulus for stateful pieces, `data-slot` rendered on the server.
- A missing or wrong component is fixed in runeui (and its tests run: `script/test` there), never
  worked around in Runwell.
- Agent tools, routes, params, events and permissions don't change: this is the interface only.
- Mailers keep their inline styles (email can't load stylesheets).
- After each phase: `bin/rails test`, `bin/rubocop`, `bundle exec herb lint app/views`,
  `bin/rails agent:coverage`, and screenshots of Tasks, the board, Clients, Work, a work page, a
  client's sheet, Settings and the portal, light and dark.
