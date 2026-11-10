# Moving Runwell's UI to rune_ui

Status: done. It shipped in 4.0 (2026-11-07) and is kept as the record of why the UI is built the way
it is. For how to build UI now, AGENTS.md (Frontend, Styling) and the rune_ui README are the guide; file
names and scripts below are as they were during the move (`runwell/work.css` is now `runwell/tasks.css`).

Plugins that still use the classes the move retired (`record-form__field`, `__label`, `__hint`, `__row`,
`__cancel`, `settings--split`) draw unstyled until they move to rune's `field` and `card` classes.

## Decisions

- **rune_ui replaces the whole UI.** It replaces `nobuild_ui` (its `ui-` classes, tokens, `ui--popover` and `ui--proxy`) and the Fizzy-derived CSS (`btn`, `panel`, `card`, `popup`, `input`, `status-tag`, the utilities). The gem lives at `../rune_ui` and is shared with Botter.
- **Hard replace in core.** When this lands, `nobuild_ui` and the Fizzy stylesheets go. This is a major version (4.0). Plugins have to move to rune_ui's classes and helpers, and the plugin contract and `theming.md` are rewritten to match.
- **The theming contract keeps its palette.** `--lch-*` tokens (and the `--color-*` built from them), Appearance's schemes, `--font-sans` and `--font-mono`, `--text-scale`, `--radius-scale`, `--radius-control`, `--radius-pill` and `--main-width` keep their names and meaning, so existing custom themes keep working. rune_ui reads the shared names directly. Runwell points rune's colour tokens at its palette in one bridge file (below). shadcn's component tokens (`--primary`, `--card`, `--popover`, `--muted`, `--border`…) go away, and theming.md's "Component tokens" table lists rune's instead.
- **Work on a branch** (`rune-ui`). Collisions between the old and new classes make a mixed page unreliable, so the old stylesheets go at the start of the branch and each area is moved before the branch merges.

## What stays Runwell's own

Behaviour that is about Runwell, not the UI kit, stays in the app and is restyled with rune tokens:

- the `keyboard` controller (`data-keys`, `g h` sequences) and the `?` sheet;
- `panes` (`[` and `]`), the `/` filter (`filter`, `nav_filter`), and `bulk` with its bulk bar;
- the Work board (`card-columns`, drag and drop, `ColumnsHelper`) and the data table (`ui/_data_table`, TableSorting, `ui--data-table` moving to `data-table`);
- pagination, the datepicker, combobox, upload, money, `fixed-popup`, `record-search`, `poll` and the frame controllers;
- ReActionView state patterns (`layouts/shared/_confirm`, details forms, `state-focus`);
- the bar, the notifications tray and the quick actions tray.

## What rune_ui gains for Runwell (in the gem, so Botter gets them too)

| Piece | Replaces | Notes |
|---|---|---|
| `avatar(person, url:, size:)`, `avatar_stack` | `ui-avatar`, `avatars.css`, `avatar_preview_tag` | image or initials; CSS already in marks.css |
| `rune-popover` + `popover_menu` | `ui--popover`, `ui-popover`, `popup.css`, `popup_menu` | native `popover` attribute, placed beside its trigger (side/align) |
| `dialog` partial + `rune-dialog` | `ui-dialog`, `dialog.css`, `delete_dialog` | `<dialog>`, a heading, a body and actions |
| `sheet` | `ui-sheet` | a dialog from the side |
| `tabs(items)` | `ui-tabs`, `record_tabs` | links with `aria-current`, or buttons with `aria-pressed` |
| `tooltip` | `ui-tooltip` | CSS only, on `[data-tooltip]` |
| `toast` / flash | `ui-toaster`, `ui-toast` | flash already exists; add the toast position |
| `table` styles | `ui-table`, `data-table.css` base | the data table's behaviour stays Runwell's |
| `alert` | `ui-alert` | the flash tones on a static block |
| `skeleton`, `progress` | `ui-skeleton`, `ui-progress` | |
| `breadcrumb` | `ui-breadcrumb` | `crumbs` exists; Runwell's `breadcrumb_items` feeds it |
| `kbd` | `ui-kbd` | done (marks.css) |
| `item` | `ui-item` (167 uses) | is `list_row`: grow it a description line and actions |
| `pill` / quick filter | Fizzy's quick filters and pickers | a ghost button with a chevron that opens a popover menu |
| icons | Fizzy's 86 mask icons | Rune-style inline SVG for the ~60 names in use, registered with `RuneUi.register_icons` |

## Token bridge (`app/assets/stylesheets/rune-theme.css`, unlayered, before custom CSS)

```css
:root {
  --page: oklch(var(--lch-ink-lightest));
  --panel: oklch(var(--lch-canvas));
  --layer-1: oklch(var(--lch-ink-lightest));
  --layer-2: oklch(var(--lch-ink-lighter));
  --layer-3: oklch(var(--lch-ink-light));
  --text: oklch(var(--lch-ink-darkest));
  --text-muted: oklch(var(--lch-ink-dark));
  --text-faint: oklch(var(--lch-ink-medium));
  --line: oklch(var(--lch-ink-lighter));
  --line-strong: oklch(var(--lch-ink-light));
  --hover: oklch(var(--lch-ink-lightest));
  --accent: oklch(var(--lch-accent));
  --accent-hover: oklch(var(--lch-accent) / 88%);
  --accent-ink: oklch(var(--lch-ink-inverted));
  --accent-soft: oklch(var(--lch-accent-lightest));
  --attention: oklch(var(--lch-yellow-dark));
  --danger: var(--color-negative);
  --ok: var(--color-positive);
  /* --shadow-popover, --font-sans, --font-mono, --main-width and the --radius-* knobs share
     their names with Runwell's tokens, so Runwell's unlayered values apply as they are. */
}
```

Dark mode needs nothing extra, because the `--lch-*` values change under `html[data-theme="dark"]` and `rune` reads them. Two checks: Runwell's sun/moon toggle sets `data-theme` (the same attribute rune uses), and `appearance.css` sets `--radius-control` for Corners.

## Mapping, old to new

| Old | New |
|---|---|
| `ui_button`, `ui_link_button`, `.ui-button` (`--secondary`, `--outline`, `--ghost`, `--destructive`, `--sm`, `--icon-sm`) | `button_link`, `action_button`, `submit_button`, `icon_button` (`:primary`, `:secondary`, `:ghost`, `:danger`; `:sm`) |
| `ui_button_classes` | `button_classes` |
| `ui_badge`, `ui_status_badge`, `.status-tag` | `badge(status, label, tone:)` with Runwell's `STATUS_TONES` in `RuneUi.badge_tones` |
| `ui_dropdown` / `ui_menu_item` / `ui_menu_label` / `ui_menu_separator` | `menu` / `menu_link` / `menu_button` / `menu_label` / `menu_divider` (or `popover_menu` in scrolling rows) |
| `.ui-card` (`__header`, `__title`, `__description`, `__content`, `__footer`) | `card(title, hint:, actions:)`, `.card__footer` |
| `.ui-field`, `.ui-label`, `.ui-input`, `.ui-select`, `.ui-textarea` | `field(form, :attr, label:, hint:)`; bare inputs are styled by `rune.base` |
| `.ui-checkbox`, `.ui-switch`, `switch_field` | `switch(form, :attr)` in a `setting_row`, `.checkbox` |
| `.ui-item` | `list_row` |
| `.ui-empty`, `layouts/shared/empty` | `empty_state(text) { action }` |
| `.ui-sidebar`, `sidenav`, `inset_header` | `app_shell`, `sidebar_brand`, `sidebar_link`, `sidebar_section`, the panel bar |
| `.ui-kbd` | `<kbd>` |
| `.ui-separator` | `<hr>`, `menu_divider` |
| `settings__section`, `settings--split`, `record-facts` | `settings_group` / `setting_row`; the record page layout is Runwell's own (`record-page.css`) on rune tokens |
| `icon_tag "name"` | `icon(:name)` |

## Phases

0. **Gem readiness.**
   - Done: rem sizes, `--radius-scale`, `--radius-control`, `--radius-pill`, `--text-scale`, the shared token names, `--row-h` and `--icon-size`. Also `avatar` / `empty_avatar` / `avatar_stack`, `popover_menu` with `rune-popover`, `dialog` / `sheet` / `confirm_dialog` with `rune-dialog`, `tabs`, `data-tooltip`, `callout` (the old `ui-alert`), `.table`, `.skeleton`, `progress_bar` and `<kbd>`.
   - To do: the toast position for flash, `list_row` with a description line and actions (for `ui-item`), the pill / quick filter, and the icons.
1. **Shell. Done on 2026-11-06.**
   - **Gems:** `nobuild_ui` is out of the Gemfile and `rune_ui` (path `../rune_ui`) is in.
   - **Stylesheets:** `app_stylesheet_tags` loads rune_ui, then `RUNWELL_STYLESHEETS`:
     - the theming contract: `_global`, `appearance`, `font-face`;
     - `icons` and `utilities`, kept until the last phase;
     - `rune-theme`, the bridge (with text size and the `svg.icon` guard);
     - `runwell`, Runwell's own sidebar, filter, theme toggle, settings layout, sign-in and portal styles.

     Every other stylesheet is unloaded but still on disk, as the reference for each area's port.
   - **JS:** `registerRuneUi(application)` in `controllers/index.js`.
   - **Layouts:**
     - The staff layout uses `app_shell`: `#global-container` (filter) is the shell, `#main` (bulk) its main, `[` is `rune-sidebar` under the `sidenav` key that `_theme_preference` preloads, and the breadcrumb is `crumbs(*breadcrumb_items)`.
     - The sidebar, nav filter, `?` sheet, flash, public and portal layouts are on rune.
     - `_inset_header` is unused.
   - **Helpers:** every `nobuild_ui` helper call is replaced, and `ui_status_badge` sits on `badge`.
   - **Styleguide:** `/ui` is rebuilt on rune.
   - **Checks:** every staff page renders, 84 of 84 tests pass, and `herb lint` on the layouts has no errors.
   - **Not styled yet:** page bodies, the footer trays (bar, notifications, quick actions), the hint legend, the board and the data table. Phases 3 to 6 cover them.
   - **Lesson:** with Herb's slots, a template's `link_to` or `tag.*` prints an array `class:` as text, prints `id: nil` as `id=""` and drops `**splat`. So rune_ui builds its markup in Ruby and `button_classes` returns a string. Runwell's templates should use `class_names` or strings.
2. **Icons. Done on 2026-11-07.** Rune-style SVGs registered; `icon_tag` draws them; `icons.css` unloaded.
3. **Home** (briefings), **Requests**, **Notifications**, **Search**, **Quick actions**, **the bar**. Done on 2026-11-07 (`runwell/home.css`).
4. **Work**: the table, the board, the todo page, the owner picker, status dots, bulk. Done on 2026-11-07 (`runwell/work.css`; the todo page in `records.css`).
5. **Clients**, **Contacts**, **Engagements**, **Scope items**, **Documents**, **Notes**, **Custom fields**. Done on 2026-11-07 (`runwell/records.css`; form widgets in `components.css` section 7).
6. **Settings** (every page), **Users**, **Invitations**. Done on 2026-11-07 (`runwell/settings.css`; its blocks are `settings-*`, apart from the record pages' old `settings__*`).
7. **Auth and portal**: sessions, passwords, signups, OAuth, the portal and its emails' links. Done on 2026-11-07 (`runwell/public.css`, `runwell.css` sections 6 and 7).
8. **Finish. Done on 2026-11-07.** The Fizzy and `ui/` stylesheets, Fizzy's utilities and the 86 mask-icon SVGs are deleted; `RUNWELL_STYLESHEETS` loads only the theming contract, `rune-theme`, `runwell` and `runwell/*`. The `/ui` styleguide is on rune (with a card of Runwell's own pieces). AGENTS.md (Stack, Frontend, Documents, Appearance), `theming.md` (rune's component tokens, retired tokens) and `plugin-contract.md` (the UI kit as part of the contract, 4.0's removals) are rewritten, and `docs/upgrading-to-4.md` holds the plugin upgrade notes. Left to whoever releases 4.0: look at every page in a browser, bump `VERSION`, and decide whether `_global.css` drops the tokens theming.md now lists as retired.

## State (2026-11-07)

- **Phase 2 (icons) is done.** `config/initializers/rune_ui.rb` registers rune-style SVGs for the 86 Fizzy names (plus `paper-plane` and a fallback `dot`); `icon_tag` draws `icon(name)`; `icons.css` is unloaded and the `svg.icon` guard is gone.
- **Every `ui-*` class is gone from the views and helpers.** `tmp/check/rewrite_ui.rb` rewrote them to rune's in one pass (`ui-button` → `btn btn--*` or `icon-button`, `ui-card*` → `card*`, `ui-item*` → `list-row*`, `ui-field`/`ui-label` → `field`/`field__label`, `ui-badge` → `badge`/`count`, `ui-alert` → `alert`, `ui-tabs` → `tabs`, `ui-table` → `table`; `ui-input`, `ui-select` and `ui-checkbox` dropped, since rune styles bare inputs). The rest was done by hand.
- **rune_ui grew** (so Botter has them too): `card__content`, `card__action` (beside the title and hint), `card--sm`, `card__head--bordered`, `card__footer--bordered`; `list-row__media`, `__content`, `__desc`, `__actions`, `list-row--outline`; `btn--block`; `pill` (a filter or picker's trigger); `field-row`; `separator`, `separator--label`; `dialog__hint`; `alert__icon`, `alert__body`; `tabs--icons`, `tabs--pills`; `.table a.row-link`.
- **Shared pieces are on rune** (`runwell/components.css`): popups, the index toolbar and quick filters, the data table (now the `data-table` controller, with the Columns menu in a `rune-popover`), pagination, the bulk bar, index cards, `_confirm`, `_delete_dialog` (a `rune-dialog`), `_empty`, `_errors`, `_record_tabs`, `_row_actions`, `_segmented_filter`, `_view_toggle`, `_new_link`, hint mode, `secret_field`, `switch_field` / `switch_tag` (rune's switch), `person_tag` and `contact_stack` (rune's avatar).
- **Popups stay Runwell's.** The pickers, quick filters and bulk menus keep their `<dialog class="popup">` and the `dialog`, `picker`, `fixed-popup` and `combobox` controllers; only the look moved (a rune menu). `popover_menu` is for new menus.
- Column widths (`table_colgroup`, `ui_data_table_colgroup`) are inline `style="width: N%"` on each `<col>`, not 100 classes.

- **Phases 3 to 7 are done** (2026-11-07). Each area's check script is in `tmp/check/` (`home_pages.rb`, `work_pages.rb`, `records_pages.rb`, `settings_pages.rb`, `public_pages.rb`); all pages render, 84 of 84 tests pass and `herb lint` has 0 errors. None of it has been looked at in a browser yet: that is the first thing to do (light, dark, each scheme, text sizes, Corners).
- Left for phase 8: `turbo-frame { display: contents }` now lives in `runwell.css`; `date_field_controller`'s `buttonClass: "btn txt-small"`; `docs/plugin-contract.md` (`label.btn.input--upload`) and AGENTS.md's Frontend section (`settings__panel`, `record-facts`) describe the old classes; `clients/_client.html.erb` looks unused.

## Conventions for the area phases

- **Stylesheets.** Each area has its own file in `app/assets/stylesheets/runwell/` (all in `RUNWELL_STYLESHEETS`): `home`, `work`, `records`, `settings`, `public`. Shared pieces are in `components.css` and the shell in `runwell.css`. An area's CSS is ported from its unloaded Fizzy or `ui/` stylesheet (still on disk for reference) onto rune's tokens (`--panel`, `--layer-1..3`, `--text`, `--text-muted`, `--text-faint`, `--line`, `--line-strong`, `--hover`, `--accent`, `--accent-soft`, `--ok`, `--danger`, `--attention`, `--s-1..6`, `--radius*`, `--control-h`, `--control-h-sm`, `--row-h`, `--text-xs/meta/ui/read/title`, `--weight`, `--weight-strong`). Never shadcn's (`--primary`, `--muted`, `--foreground`…) or Fizzy's `--color-*` directly; `--lch-*` only for a palette colour rune has no token for.
- **Use rune first.** A rune class or helper where one fits (`card`, `list-row`, `field`, `badge`, `btn`, `icon-button`, `pill`, `tabs`, `alert`, `settings_group` / `setting_row`, `dl.details`, `empty`, `stack`, `grid-2`, `button-row`, `muted`, `faint`, `small`); an area class only for what's Runwell's own.
- **rune styles bare elements.** Inputs, selects and textareas need no class. Every `<form>` is a flex column with a `--s-4` gap (`form.button_to` is inline), so an inline form needs its own layout class.
- **Fizzy's utilities** (`flex`, `gap`, `txt-*`, `margin-*`, `pad-*`, `for-screen-reader`, `overflow-ellipsis`…) still load until phase 8. Replace them in the area as it moves (`visually-hidden` for `for-screen-reader`).
- **Templates** (Herb-compiled): `class:` as a string (`class_names`), never an array; never `id: nil`; no `**splat` in tag helpers; strict locals on every partial.
- **Space with `gap`**, never sibling margins. **No coloured left borders**; states show as tints, weight, dots and badges.
- **Checks**, without a browser (headless Chromium can't start in the sandbox):
  - `bin/rails runner tmp/check/pages.rb` renders every staff page signed in as ted@brem.io (`ONLY=/work,/clients` limits it; `DUMP=dir` saves the HTML);
  - `bin/rails test`;
  - `npm_config_cache=$TMPDIR/npm bundle exec herb lint app/views/<area>`;
  - `grep -rnE '\bui-|class="[^"]*\b(btn--(link|plain|circle|reversed)|panel|popup|status-tag|input)\b' app/views/<area>` finds what's left.

## Checks per phase

- `bin/rails test` and `bundle exec herb lint app/views`.
- Every page in the area in light, dark and each Appearance scheme, at the small and larger text sizes, with Corners set to square and round.
- No `ui-` class or Fizzy class left in the area: `grep -rnE '\bui-|class="[^"]*\b(btn|panel|popup|status-tag)\b' app/views/<area>`.
