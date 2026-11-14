# Moving Runwell to runeui (6.0)

Runwell's whole interface moves onto runeui (`../runeui`: components on UI SDK's behaviours,
shadcn/ui's look and tokens, no build step), with nothing left of rune_ui or of the pieces taken
from Fizzy. Branch `runeui-trial`. It began as a trial (the trial's notes are folded into "How the
two kits shared a page", below): runeui linked beside rune_ui with a bridge for its tokens, one
page (Settings › Address) converted, and every other page pixel-identical with and without
runeui loaded, which is what made the area-by-area move below possible.

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

## How the two kits shared a page (phases 0 to 8), and the flip (phase 9)

The vocabularies collide (`--accent` and `--ring` mean different things; Runwell's `--border` was
a border shorthand), so until the old CSS was gone runeui was linked as in the trial:
`runeui_tags(tokens: false, page: false, theme: false)` then `runeui/bridges/rune_ui`, which
defined runeui's tokens on runeui's own parts from the page's. The page's tokens kept their old
names and meanings for whatever was still old (and for plugins); the look changed by changing
those tokens' values, not their names. Runwell markup inside a runeui part read runeui's meanings
for the shared names, so Runwell gave `--accent` and `--ring` back inside the parts that hold its
markup (runwell.css section 2, components.css, records.css, compat.css: "the restore machinery").

Phase 9 flipped it: runeui is linked as any app links it, its tokens (shadcn's) on `:root`, and
Runwell's theme (`appearance.css`), its own sheets and the compatibility layer read those. The
bridge (`runeui/bridges/rune_ui.css`) stays in runeui for other apps; Runwell no longer links it.

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
   **Done:** the gem is out. `RuneCompatHelper` draws buttons, badges, cards, fields, empty
   states, menus, dialogs, sheets, callouts and progress with runeui (`RuneCompatShellHelper`
   keeps the shell, crumbs and flash for phase 2); `runwell/compat.css` carries rune_ui's sheets
   in the layer `runeui.rune`, between runeui's base and components, and dresses those parts;
   the `rune-*` controllers still named in views are in `app/javascript/controllers`. Left on
   rune's markup: `avatar`, `tabs`, `list_row`, the settings rows, `status_dot`; `button_classes`
   stays rune's `btn` (a class can't carry `data-variant`); the icons stay Runwell's own 16×16
   set (`Runwell::Icons`), not registered into runeui's 24×24 one.
2. **The shell**: `app_shell`, the sidenav, the panel bar and breadcrumb → `ui :app_shell`,
   `ui :sidebar_group`, `ui :sidebar_item`, `ui :breadcrumb`; `NavLayout` and the per-person menu
   kept. Toasts → `ui :toaster` (`turbo_stream_flash` → `turbo_stream.ui_toast`); every
   `delete_dialog`, `row_delete_dialog` and `layouts/shared/confirm` → `ui :alert_dialog` /
   `data-turbo-confirm`.
   **Done:** staff pages are `ui :app_shell` (inset), the nav `ui :sidebar_group` /
   `ui :sidebar_item` (`sidenav_link_to`) between a brand and a foot (`layouts/shared/_sidenav`,
   `_sidenav_brand`, `_sidenav_foot`), the bar `ui :breadcrumb` beside the + and the bell
   (`_panel_bar`); `[`, the cookie, the phone sheet and the nav's kept scroll are runeui's sidebar
   controller (`rune-sidebar`, `RuneCompatShellHelper`, the `keeps-scroll` behavior and the panes
   controller's nav half are gone). Every message is a toast in `ui :toaster` and every question
   is asked in `ui :confirm` (both in `layouts/shared/_feedback`, in the staff, public and portal
   layouts; `runeui_tags` no longer passes `confirm: false, toasts: false`): `turbo_stream_flash`
   is `turbo_stream.ui_toast`, the flash is `ui_flash_toasts`, Undo is a toast action; deletes and
   confirms are forms whose button carries `data-turbo-confirm` (`ConfirmHelper`: `delete_button`,
   `confirm_button`, `row_delete_button`, `bulk_delete`), and erasing work is `ui :alert_dialog`
   with `confirm_text:`. `rune-flash`, the flash and row-delete-dialog partials and their CSS are
   gone; `layouts/shared/_delete_dialog` and `_confirm` stay as the names plugins render, drawn
   the new way, as do `crumbs` and `flash_messages` (RuneCompatHelper). Added to runeui for it:
   the sidebar's header and footer (`sidebar_header:`, `sidebar_footer:`) with only the groups
   scrolling, `content_attrs:`, an item's `icon:` as markup, toast actions that send a request or
   visit a page and `duration: 0`, hash messages in the flash, typed confirmation
   (`confirm_text:`). Left: the `rune-dialog` controller for the shortcut sheet (phase 7) and a
   piece of work's About dialog (phase 5); `works/_close` (two in-place forms with a note, on
   ReActionView state: phase 5); `.main`, `.crumbs` and `.sidebar__brand` / `.sidebar__logo` in
   compat.css for the public and portal layouts (phase 8). Inside the shell Runwell's markup
   needs `--accent` and `--ring` back (runwell.css, 2), and `data-sidebar` on `<html>` is still
   the record page's details sidebar, not the nav's (which is on the shell).
3. **Lists**: `ui/_data_table` → `ui :table` with `selectable:`, `ui :sort_header`,
   `ui :select_cell`, `ui :bulk_bar`, `ui :pagination` (geared_pagination's pages kept);
   `quick_filter` → `ui :filter` / `ui :filter_bar`; the Columns menu → `ui :menu`.
   **Done:** every index (clients, work, tasks, users, intake, AI activity, the audit log) is
   `layouts/shared/_list_table`: `ui :table` with `ui :sort_header` (the `sort` / `direction`
   params `TableSorting` already read), `ui :select_cell` and runeui's selection controller,
   the page's `bulk_bar` (`ui :bulk_bar` holding `ui :menu`, `ui :popover` with `ui :date_picker`
   or `ui :input`, `ui :button`; `BulkHelper`) handed to the table, `ui :columns_menu` in the
   header's corner and `ui :pagination` under it (`table_pagination`). The table sizes itself:
   no colgroup, no measured widths (`column_widths`, `COLUMN_SHAPES`, `CustomField.column_widths`
   and the 13px exception are gone); the naming column grows and truncates (`data-grow`), free
   text is capped (`data-truncate`). Filters are `ui :filter` in `ui :filter_bar` (the index
   toolbar), labelled ("Owner: Anyone"), advancing history so Back undoes one; New is `ui :button`,
   the Table / Board toggle `ui :toggle_group` as links, empty lists `ui :empty`. Runwell's `bulk`
   controller keeps only the sending (ids added to the bar's forms, rows dimmed, selection
   cleared); `data-table`, `rune-popover`, `ui/_data_table*` and their CSS are gone. Enter on a row
   now opens the link in its naming cell (`[data-grow]`), not the first button (a task's owner
   picker came first). Added to runeui for it: `data-grow` / `data-truncate` / `data-align="center"`
   and a scroll box inside the table's container (the bulk bar stays put above it), `checkbox:`
   on `ui :select_cell`, `columns:` on `ui :table` with `ui :columns_menu` and the
   `runeui--columns` controller, `search:` on `ui :filter` (a combobox behind the pill,
   `runeui--filter`), a filter marked active only when its param is in the address, filters put
   back before Turbo caches the page (Back showed the choice just made), `ui :toggle_group` as
   links (`href:` options). Kept for plugins, drawn the new way: `layouts/shared/quick_filter`,
   `index_toolbar` (with `content_for :index_filters` and `:index_bulk`), `row_actions`, `empty`,
   `new_link` / `new_button` / `view_toggle`, `bulk_bar`, `bulk_menu`, `bulk_button`, `bulk_date`,
   `bulk_text`, `bulk_delete`, `sortable_th`, `table_pagination`, `table_next_page_row`; and, as
   they were, `bulk_select_all_header` / `bulk_select_cell` and `data-bulk-target="item"` (native
   checkboxes, whose selection the `bulk` controller still keeps for a bar in the toolbar). Left:
   avatars (`person_tag`, `task_owners_tag`, `contact_stack`) stay rune's markup until the pickers
   that redraw them move (phase 4); the status and owner pickers and the due date in rows are
   phase 4's, inside the new cells; plain `.table`s (settings' roles, webhooks and updates, the
   portal's lists) and `segmented_filter` (rune's tabs) are phases 5 and 8's.
4. **Pickers and forms**: `ComboboxFormBuilder`, `combobox_tag`, the status and owner pickers,
   `popup_menu` → `ui :select`, `ui :combobox`, `ui :menu`; `date_input` → `ui :date_picker`;
   `switch_field` → `ui :switch`; `money_field` → `ui :number_input` (cents kept);
   `rich_text_field` → `ui :editor`; fields → `form.ui :field`. Custom fields follow.
   **Done:** the default form builder is `RunwellFormBuilder` (was `ComboboxFormBuilder`):
   `form.select` and its kin go through `select_control` (`SelectHelper`, was `ComboboxHelper`) to
   `ui :select`, or past seven choices, for `multiple` or `search: true`, `ui :combobox,
   trigger: true` (a select-like button, the search box in the popup; include_blank is a choice
   sent as ""); `text_field` and kin are `ui :input`, `text_area` `ui :textarea`, `check_box`
   `ui :checkbox`. `date_input` is `ui :date_picker` (`t` is the `date-keys` controller);
   `switch_field` is `ui :switch` sending "0"; `secret_field` is `ui :password_input`;
   `money_field` is `ui :input` with Runwell's `money` controller (dollars shown, cents sent);
   `rich_text_field` is `ui :editor` (Lexxy through `lexxy_rich_textarea_tag`, the `@` prompt,
   uploads, drafts and Esc-to-revert unchanged). `record_fields/*` and custom fields are
   `form.ui :field` (per-field errors), every kind a runeui control joining its form by `form:`.
   The task status, owner and due pickers and the clients table's status are one `ui :menu`,
   `ui :combobox` (no trigger) and `ui :popover` + `ui :calendar` on the page, opened beside each
   row's button (`data-runeui-open`), driven by the `picker` controller; avatars are `ui :avatar` /
   `ui :avatar_group`. Gone: `combobox_helper.rb`, the `multi-selection-combobox`, `popup-filter`,
   `fixed-popup`, `reveal` and `date-field` controllers, vanillajs-datepicker, and their CSS
   (datepicker, `.combobox`, secret field). Kept for plugins: `combobox_tag { select_tag … }`,
   `switch_tag` (the native switch, compat styles), `popup_menu`, `date_input_tag`,
   `money_field_tag`, `custom_field_inputs`. Added to runeui: `trigger:` / `search:` on
   `ui :combobox`, `form:` on `ui :switch` and `ui :checkbox`, one menu or combobox serving many
   buttons (`data-runeui-open` opens it beside its opener, hotwire.js), the date picker firing
   `change` and controls' inner inputs no longer leaking a second `change` (forms.js),
   `aria-invalid` following the server on a morph (morph.js), and the combobox button's words
   kept through a morph. Left: Lexxy keeps `runwell/compat-lexxy.css` (runeui's `runeui/lexxy`
   skin reads runeui's tokens from `:root`, which only phase 9 puts there); hand-written `.field`
   wrappers outside `record_fields` (settings, the quick-action form, the portal), the
   appearance and text-size choice cards (native radios in picture cards), the bulk and
   oauth checkboxes, the file inputs; the quick-actions tray's record picker (Fizzy's `combobox`
   and `dialog` controllers, `popup_menu`, `.popup` CSS) is phase 7's.
5. **Record pages and the sheet**: record page cards and tabs → `ui :card`, `ui :tabs`; the task
   panel and peek → `ui :side_panel` (`?task=`, `?peek=` kept as the address); the in-place
   field forms kept (save-on-change), on runeui controls.
   **Done:** the sheet is `ui :side_panel, params: %w[task peek]` (`layouts/shared/_side_panel`,
   its content `_side_panel_content`, the frame alone `_side_panel_frame` for
   `render_side_panel`), drawn open from the first paint on a full load; runeui's controller opens,
   closes, shows the skeleton and keeps the address, and Runwell's `side-panel` controller (rewritten,
   about half the size) keeps only the links, `j` / `k`, fetching ahead and the click outside. The
   portal's sheet is the same (`params: %w[task]`). The panel's and peeks' contents carry
   `data-morph="replace"` (they sit inside a `ui-*` element, where runeui's morph guard would keep
   nodes a script moved). Record pages: headers are `record_header` (`ui :page_header`,
   `RecordPagesHelper`), cards `record_card` (`ui :card`), empty sections `ui :empty, size: :sm`,
   History `ui :card` + `ui :collapsible`, record tabs `ui :tabs` as links
   (`layouts/shared/record_tabs`, `record_tab_links`, settings' tabs too), the List / Board switch
   `ui :toggle_group` as links, the work's sidebar `ui :tabs` (Sections / General: its ReActionView
   state gone), the About dialog `ui :dialog` (save-when-dirty, ⌘/Ctrl+Enter and Esc unchanged),
   `works/_close` two `ui :alert_dialog`s with a note (`ui :input` joined to the dialog's form; its
   ReActionView state gone), the sidebar toggle, arrange button, panel and peek buttons, the arrange
   bar and the record pages' buttons `ui :button` / `ui-button`. The Tasks tab's sections stay native
   `<details>` (styled as before): `ui :accordion`'s open items would follow the server's list on a
   morph, undoing the `keep-open` rule (only closing is refused; the server may open one). Added to
   runeui: `params:` on `ui :side_panel` (the panel as the page's own state: the frame loads this
   page with the param, the address is the frame's), a block drawn in the frame from the first paint,
   `closable: false`, `initial_focus:`, a reload of what shows keeping it on screen
   (`data-refreshing`); `ui :tabs` as links (`href:` tabs, the block as the panel, current by
   `aria-current`). Gone: the old panel's placeholder, motion and skeleton CSS, the `rune-dialog` and
   ReActionView state on record pages, `record-card__empty` / `card__*` markup in the core's record
   pages. Kept for plugins: `.card` / `card__*`, `.record-page__header` / `__heading` /
   `__description`, `.record-card__empty`, `.tabs` / `.tabs--pills` (compat.css, records.css),
   `layouts/shared/record_tabs`, `sidebar_toggle`, `peek_header`, `peek_tasks`, `card`,
   `side_panel_link_to`, `peek_link_to`, `record_tab`, `plugin_record_tabs`, `current_record_tab`.
   Left: the user page and the invitation page keep settings-section markup inside `ui :card`
   wrappers (the invitation page keeps `.card`; phase 8); `segmented_filter` (rune tabs, phase 8);
   the scope list's rows and progress are Runwell's own markup; the shortcut sheet's `rune-dialog`
   (phase 7). Esc from a field inside the panel now closes it (UI SDK's drawer), where it used to
   only leave the field. Also fixed on the way: a section's delivery state in the Tasks tab comes
   from the tasks already loaded (an N+1 on a quick add's answer), and the List / Board switch
   drawn in a stream answer links to the work's page (`tasks/_view_switch, work:`).
6. **The board**: `tasks/board/*`, `columns/*`, the Fizzy drag-and-drop → `ui :board`
   (`Task#move!`, `before`, one endpoint).
   **Done:** the Tasks board and a work's board are `ui :board` (`tasks/board/_columns`), a
   `ui :board_column` per status (`tasks/board/_column`: `total:`, a lazy next-page item `more:`,
   `collapsible:` for the doing columns and Done, `url:` its own drop endpoint with `__card__`), the
   cards `ui :board_card` (`tasks/display/_preview`, its title link `side_panel_link_data`). The
   drop endpoints and `Task#move!` with `before` are unchanged; their answers replace
   `board-column-<status>`. Later pages: `task_board_more` (a lazy frame) answered by
   `Tasks::ColumnsController` with `tasks/board/_more` (a stream replacing the item with the next
   page's cards). A column's own page is a one-column board laid out as a grid. Keys: the keyboard
   controller hands h j k l to the focused card as arrows and H J K L as Shift+arrows, then selects
   the card it lands on (the side panel follows). Gone: `ColumnsHelper` (`column_tag`,
   `column_frame_tag`), the `collapsible-columns`, `drag-and-strum` and `css-variable-counter`
   controllers, `tasks/board/_cards`, `_closed`, `_stream`, `_expander`, `tasks/display/_previews`,
   `tasks/columns/_empty_placeholder`, the `card-columns` / `cards__*` / `app-card--compact` CSS.
   Added to runeui: a url naming the card (`__card__`), moves through Turbo's fetch, `total:` and a
   next-page item (`more:`) on a column, folding columns (`collapsible:`, `collapsed:`, kept per
   browser, safe from morphs, opening as a card is held over or moved into one), `link:` attributes
   on a card's title, Enter marked handled, the card after a card found in document order (cards an
   app wraps, as ReActionView's debug spans do). Kept: `drag-and-drop` (plugins and the core's
   other sortable lists use it), `navigable-list` (notifications, quick actions),
   `layouts/shared/card` and `.app-card` (plugins). Left: column dots are Runwell's status colours
   on runeui's tone dot (planned an outline), not the status-dot icons.
7. **Search, quick actions, keys**: the bar and tray → `ui :command, dialog: true`; the keyboard
   controller kept, pointed at runeui's markup (`data-keys` unchanged); hint mode kept.
   **Done:** search is `ui :command, dialog: true, src: search_path, min: 2`
   (`layouts/shared/_search`, permanent in the footer): `s` presses its out-of-sight button, ⌘K is
   the palette's own; from two characters it asks /search, and `searches#show` answers a request
   carrying `Runeui-Command` with the palette's items (`searches/_palette`, `search_palette_items`:
   the same groups and order, people included, each result a link, a task's opening the side panel,
   then "See all results" to /search); the `search-palette` controller empties it as it closes.
   /search is a `ui :input` over the results frame (`form#debouncedSubmit`). Runwell has no recent
   or jump-to items, so none were added; before two characters the palette says what it searches.
   Quick actions are a `ui :popover` under the + (`#quick-actions`, `a` presses the +): the record
   picker is `quick_actions/_record_picker`, a `ui :combobox, trigger: true, src:` reading
   `quick_actions/records` as JSON by kind (`quick_action_record_items`; `record=` leaves out the
   one the picker already holds), set to `current_record`; the actions are buttons submitting the same GET form into
   the `quick_action` frame (`data-runeui-close` shuts the popover); the modal (`quick_actions#new`)
   keeps its `<dialog>` and takes the same picker; `g t n` unchanged. The `?` sheet is `ui :dialog`
   (`#shortcuts`, size xl) with every key a `ui :kbd` and hint mode's `ui :switch`
   (`#hints-switch`, `keyboard#setHints`, kept in step by the controller); the account menu still
   presses its button (`rune-proxy`). The hint legend's keys are `ui :kbd`; keycaps keep their
   place, sized like runeui's kbd. The keyboard controller's `OVERLAY` now takes in runeui's
   select, combobox and date-picker popups and `ui-command`, so a key pressed in one never reaches
   the page and Esc closes it before dropping the selection or going up. Gone: `bar/_bar`,
   `searches/_form`, `quick_actions/_picker`, `_records`, `records/index`, the `bar`,
   `search-form`, `record-search`, Fizzy's `combobox` and `rune-dialog` controllers, the bar,
   search box, tray-actions and picker CSS, `--z-bar`. Kept: `popup_menu` / `PopupHelper` and the
   `.popup` CSS (the plugin contract; the meetings plugin uses `.popup__*`), the `dialog`
   controller (the notifications tray, the modals, `popup_menu`, the meetings plugin),
   `navigable-list` (notifications), `filter` (the page filter; meetings' picker), `rune-proxy`
   (the account menu's Keyboard shortcuts), `searches/_results`, `_result`, `_person` (/search),
   `QuickAction#records`. Added to runeui: `src:`, `min:`, `prompt:` on `ui :command` (HTML from the
   server through `remote.js`, sent with `Runeui-Command`, `ui-command-status`), `part: "items"`
   to draw just the items, and on a command `description:`, `meta:`, `link:` (a real link,
   `as-child`) and an icon given as markup; a combobox behind a button with `src:` loading its
   first page empty (it searched for the chosen label) and not searching as it closes. Accepted:
   Esc in the palette clears the box first, then closes (UI SDK's command); the match isn't bold
   (UI SDK's item text keeps text only); `g b` reaches the board only from Tasks (as before:
   it's declared on the view toggle). Left: the notifications tray (Fizzy's `dialog` and
   `navigable-list`) and the modals' `<dialog>` (`layouts/shared/_modal`, the quick-action and
   placeholder modals); the picker lists the chosen record after a search's results (runeui's
   `src:` keeps the value's option).
8. **Settings, public pages and the portal**: every settings page, sign-in and its showcase, the
   portal's pages and sheet.
   **Done:** the modals are `ui :dialog` drawn open inside their frames (`layouts/shared/_modal`,
   `#modal_dialog`, title and `description:`; `quick_actions/new`, `#quick_action_dialog`); Cancel is
   `data-runeui-close`, a refused save still comes back in the dialog, success still answers with
   streams or breaks out, and a new `empties-on-close` behavior empties the frame once the dialog
   has closed (so Turbo's snapshot never brings it back). The placeholder is the same dialog with
   `ui :skeleton` lines; `loading-placeholder` now stops its timer as the answer starts rendering
   (a slow render showed the skeleton over the form) and marks its copy
   `data-loading-placeholder-content` (UI SDK puts `data-placeholder` on an empty select, which
   emptied a refused modal). The quick-action forms are `form.ui :field`, `form-grid`,
   `form-actions`. The bell's tray is a `ui :menu` (`notifications/_tray`, `_tray_item`,
   `notification_menu_item`: each notification a link item, then See all and Mark all as read, which
   now answers the tray with a stream emptying its frame since the broadcast refresh skips the tab
   that asked); /notifications is two `record_card`s of Runwell rows with the read toggle
   (`ui-button`), `j` / `k` from the keyboard controller. Settings: the nav's links are runeui ghost
   buttons (`settings_nav_link`, so plugins' `section_nav_link` too); every page's fields are
   `form.ui :field`, checkboxes `form.ui :checkbox`, tables `ui :table`, badges `ui :badge`, alerts
   `ui :alert`, cards `ui :card` (plugins, webhooks, the intake schedule, the invitation page),
   rows `settings-item` (Runwell's own); Appearance's and Your account's choice cards are
   `form.ui :radio_group` with picture-card radios (`settings/appearances/_choices`, the appearance
   controller previewing on the group's change); 2FA setup is `ui :otp_input`; "who sees it" is a
   `ui :popover`; switches with hints are runeui's field with `control:` (new); `setting_row` and
   `settings_group` draw that and `ui :card` for plugins. Public pages are `auth_card`
   (`AuthHelper`, runeui's card) with `form.ui :field` and full-width `ui :button`s; the showcase's
   cards, pills and avatars are `ui :card`, `ui :badge`, `ui :avatar` on runeui's tokens; the theme
   toggles are `ui-button`s. The portal: `portal_card` (runeui's card), `ui :table` for its lists,
   `portal-list` rows, `ui :breadcrumb`, `ui :badge`, `ui :progress`, `ui :file_input` for request and
   reply files, `ui :menu` for the contact's menu, `ui :input` for search; `segmented_filter` (core
   and portal) is `ui :tabs` as links. Also moved while here: row actions, delete and confirm
   buttons, the AI brief button and the leftover `btn`/`list-row`/`field__hint` markup on record
   pages (`item-row`, `field-note`, `state-dot`), the account menu (`ui :menu`; Keyboard shortcuts
   opens the sheet by `data-runeui-open`), the document preview (`ui :dialog`), form errors
   (`ui :alert`), `ui_status_badge` (draws `ui :badge` itself). Added to runeui: `control:` on
   `ui :field` (label and description in `field-content`, the control at the row's end; with
   `control_id:`, which `form.ui :field` fills in, the label is a native `<label for>`, since UI SDK's
   field doesn't always link a control that upgrades after it), and a menu
   item carrying `data-runeui-open` / `-close` acting when chosen with the keys too (UI SDK fires
   `select`, not `click`). Gone: `navigable_list_controller`, `rune_proxy_controller`, the
   notification header/mention partials, the tray's and modals' old CSS, compat's `.segmented`,
   `.sidebar__brand` / `__logo`, `.btn--block`, `.link-button`, `.dialog--lg` / `__box` / `__header` /
   `__hint`. Kept for plugins (the compatibility layer): every `RuneCompatHelper` helper
   (`button_link`, `action_button`, `submit_button`, `icon_button`, `button_classes`, `badge`, `card`,
   `list_row`, `field`, `empty_state`, `menu`, `popover_menu`, `menu_link`, `menu_button`,
   `menu_label`, `menu_divider`, `dialog`, `sheet`, `dialog_actions`, `confirm_dialog`, `tabs`,
   `callout`, `avatar`, `avatar_stack`, `settings_group`, `setting_row`, `copy_button`, `copy_field`,
   `progress_bar`, `status_dot`, `time_ago`, `crumbs`, `flash_messages`), `switch_tag`,
   `popup_menu` / `PopupHelper` with the `dialog` controller and `.popup` CSS (the meetings plugin),
   `layouts/shared/card` (`.app-card`), the `rune-clipboard` and `rune-local-time` controllers,
   compat.css's classes (`btn`, `card`, `list-row`, `field`, `field-row`, `alert`, `tabs`, `count`,
   `pill`, `icon-button`, `table`, `table-wrap`, `crumbs`, utilities), and `views/ui/show` (the
   styleguide of that layer). The core still calls `avatar` / `avatar_stack` (they draw
   `ui :avatar`, keeping Runwell's lettered colours) and uses compat's utility classes (`muted`,
   `button-row`, `stack`, `visually-hidden`, `hide-on-touch`) and the `.main` column (kept in
   compat's layer so runeui's app-content wins). Accepted: runeui's sizes for small buttons and
   field descriptions (14px where rune's were 12–13px), a section filter's inactive tabs no longer
   muted, the portal's avatar in runeui's neutral, the tray without a per-row read toggle (it's on
   /notifications), the modal 42rem wide (was 48rem).
9. **The flip and the clean-up**: runeui's tokens on `:root`, the bridge out; the old sheets
   (`rune-theme`, what's left of `runwell/*`), Fizzy's controllers and the unused behaviors
   deleted; AGENTS.md, docs/theming.md, docs/plugin-contract.md rewritten; VERSION 6.0.0.
   **Done:** runeui is linked as any app links it: `runeui_tags(lexxy: true)` (its tokens on
   `:root`, `page.css`, the theme script, toasts and confirm, Lexxy with `runeui/lexxy`), with
   nothing turned off; `runeui/bridges/rune_ui` isn't linked. `appearance.css` is Runwell's theme,
   in a `runwell.theme` layer over runeui's tokens (linked first: its `@layer` statement is the
   page's order): Inter, Runwell's `--success` / `--warning` / `--info`, `--sidebar-primary` as the
   brand, dark cards and popovers on the page's ground, and its additions derived from shadcn's
   (`--faint-foreground`, `--brand-tint`, `--brand-tint-strong`); schemes set `--primary`,
   `--primary-foreground` (light, and `.dark`) and `--ring`; corners `--radius` (Sharp 0.25rem,
   Soft 0.625rem, Round 1rem); fonts `--font-sans`; text size the root's font size (87.5–125%).
   Light and dark are one mechanism, runeui's: its theme script sets `.dark` and `data-theme` before
   the first paint from localStorage `runeui-theme` or `data-default-theme`; the toggles are
   `data-runeui-theme="toggle"` (buttons and menu items); a 5.x choice (`theme`) is carried over
   once (`layouts/_theme_preference`); Appearance's preview calls `refreshTheme()`. Runwell's own
   sheets read only runeui's tokens (and its three additions): `--primary` for the brand,
   `--ui-focus-ring` for focus, plain rems for spacing, `--ui-radius-*` / `calc(var(--radius) * n)`
   for corners. `runwell/compat.css` defines every old name plugins read from runeui's tokens
   (rune_ui's and Fizzy's; `--accent` and `--ring` excepted: they're runeui's), and
   `lib/rails_ext/propshaft_plugin_stylesheets.rb` reads a plugin stylesheet's `var(--accent)` /
   `var(--ring)` as `--primary` / `--ui-focus-ring`. Custom CSS is a shadcn theme (`:root` and
   `.dark` blocks, unlayered, last), `ThemeBrief`, the Appearance page and docs/theming.md say so;
   the validation rules are unchanged. Gone: `rune-theme.css`, `_global.css` (Fizzy's palette, its
   `--border` shorthand and layer order), `runwell/compat-lexxy.css`, the restore machinery
   (`--rune-accent`, `--rune-ring` and every rule giving `--accent` / `--ring` back inside runeui's
   parts: runwell.css 2, components.css, records.css, tasks.css, compat.css), the `theme` and
   `frame` controllers (the second unused since the board moved), `.main` in compat's layer (it's
   Runwell's own now, unlayered in runwell.css with the portal's and sign-in's overrides after it:
   only `flex: 1` and padding of runeui's app-content are layered under it, and runwell.css sets
   that padding), dead CSS (the board's old popup leftovers, `fixed-popup--placed`,
   `record-form__toggle`, `record-form__head*`, `document-link__wrap`, `settings-code`, the
   `menu__items` width, a duplicate table convention) and compatibility classes neither the core
   nor any plugin uses (listed in plugin-contract.md, 6.0); `docs/runeui-trial.md` (folded in
   above) and `docs/rune-ui-migration.md` (4.0's record). Moved: the popups' CSS (`popup_menu`, the
   meetings plugin) from components.css into compat.css; the appearance samples into settings.css;
   code blocks take Lexxy's code colours. Kept: `font-face.css` (Inter is bundled; runeui ships no
   font), `/ui` as the compatibility layer's styleguide (runeui's gallery is `/runeui`).
   compat.css's bare focus rules now skip runeui's own parts (they draw their own focus; the bridge
   had hidden this by making `--ring` a colour inside them, so a palette input showed no double
   ring). Added to runeui: a menu item with `data-runeui-theme` acting when chosen with the keys or
   the pointer (once), and `refreshTheme()`.
   Differences on screen, all from runeui's own values where the bridge had mapped Runwell's:
   faint text a hair different (`--faint-foreground` is `--muted-foreground` at 80% / 72%);
   dialog and empty-state titles 18px (runeui's `--ui-text-lg`; were 20px); menus, selects and
   popovers at runeui's control radius (8px; the bridge rounded them 14px), textareas likewise;
   the Lexxy editor as a runeui field (closed border, a faint fill in dark); `--secondary` /
   `--accent-foreground` text a step lighter in light (shadcn's `0.205`); the brand tints mixed
   from `--primary` (a hair off the old fixed steps); Round corners no longer make controls pills
   (`--radius: 1rem` for everything); in dark from the system, the sign-in showcase's dark shading
   and card borders now apply (they were written for `data-theme="dark"`, which runeui now always
   sets). The browser bar's dark `theme-color` is the page's (`#0a0a0a`, was Fizzy's `#0d181d`).

### For phase 10 (each plugin onto runeui)

Each plugin in `../runwell-*` moves its views to `ui :name` / `form.ui` and its stylesheet to
runeui's tokens, sets `requires: ">= 6.0.0"`, and once all have, 7.0 deletes `runwell/compat.css`,
`RuneCompatHelper`, `PopupHelper`, `views/ui/show`, the `rune-clipboard`, `rune-local-time` and
`dialog` controllers (only `popup_menu` uses the last now) with `helpers/orientation_helpers`, and
`propshaft_plugin_stylesheets.rb`. Writing `--accent`
in a migrated plugin means shadcn's fill: rename the brand uses to `--primary` and focus shadows to
`--ui-focus-ring` in the same commit. What each still uses (from its CSS, views and helpers; class
names approximate, matched as words):

| Plugin | Old token names | Compat helpers | Compat classes (main ones) |
| --- | --- | --- | --- |
| ads | `--accent`, `--danger`, `--radius-control`, `--s-1…5`, `--text-faint`, `--text-meta`, `--text-muted`, `--text-title` | `badge`, `callout`, `card`, `field` | `btn*`, `card`, `field*`, `table`, `table-wrap`, `table__grow`, `badge`, `switch`, `empty`, `stack`, `button-row` |
| approvals | `--accent`, `--brand-tint`, `--line`, `--radius-lg`, `--s-2…5`, `--text-meta`, `--text-muted`, `--weight-strong` | `card`, `sheet` | `btn*`, `card*` (`--flush`, `__head--bordered`), `table`, `switch`, `empty`, `copy` |
| brain | `--accent`, `--brand-tint`, `--danger`, `--line`, `--ok`, `--radius-scale`, `--s-1…4`, `--text-meta`, `--text-muted`, `--weight-strong` | `badge`, `card`, `menu` | `btn*`, `card*` (`--sm`, `__action`, `__footer`), `list-row*`, `field*`, `select--sm`, `separator`, `table` |
| calendar | `--accent`, `--accent-ink`, `--attention`, `--brand-tint`, `--control-h-sm`, `--danger`, `--hover`, `--layer-1`, `--layer-2`, `--line`, `--line-strong`, `--ok`, `--panel`, `--radius-pill`, `--radius-scale`, `--s-1…4`, `--text`, `--text-faint`, `--text-meta`, `--text-muted`, `--text-title`, `--text-ui`, `--text-xs`, `--weight-strong` | `badge`, `card`, `copy_field`, `field`, `tabs` | `btn*`, `card*`, `list-row*`, `tabs*` (`--pills`), `alert--danger`, `badge--*`, `pill`, `search`, `table*`, `field*` |
| client-dashboard | `--line`, `--s-1…5`, `--text`, `--text-meta`, `--text-muted`, `--text-read`, `--text-title`, `--weight-strong` | `badge`, `card`, `empty_state` | `card*` (`--flush`), `list-row*`, `alert--danger`, `table`, `field*`, `checkbox`, `select--sm` |
| desktop | none | none | none |
| google-ads | Fizzy's: `--block-space*`, `--color-ink`, `--color-ink-lighter`, `--color-ink-medium`, `--color-link`, `--color-positive`, `--inline-space*`, `--text-x-large`, `--text-xx-large` | `card`, `field` | `btn`, `card`, `field`, `progress`, `search` |
| leads | `--accent`, `--brand-tint`, `--danger`, `--hover`, `--layer-1`, `--line`, `--panel`, `--radius-scale`, `--s-1…4`, `--text-faint`, `--text-meta`, `--text-title`, `--text-ui`, `--weight-strong` | `action_button`, `badge`, `button_classes`, `button_link`, `callout`, `card`, `copy_field`, `dialog`, `dialog_actions`, `field`, `submit_button`, `time_ago` | `btn*`, `list-row*`, `grid-2`, `count--quiet`, `pill`, `table*`, `field*` |
| media | `--accent`, `--accent-soft`, `--brand-tint`, `--brand-tint-strong`, `--control-h`, `--danger`, `--hover`, `--layer-1`, `--layer-2`, `--line`, `--line-strong`, `--ok`, `--panel`, `--radius-control`, `--radius-lg`, `--radius-pill`, `--radius-sm`, `--s-1…6`, `--text`, `--text-faint`, `--text-meta`, `--text-muted`, `--text-read`, `--text-xs`, `--weight-strong` | `badge`, `card`, `crumbs`, `dialog`, `icon`, `sheet`, `tabs` | `btn*`, `card*`, `tabs*` (`--icons`, `--pills`), `badge--ok`, `badge--outline`, `crumbs`, `pill`, `search`, `switch` |
| meetings | Fizzy's: `--block-space*`, `--color-canvas`, `--color-ink-dark`, `--color-ink-lighter`, `--color-ink-medium`, `--color-link`, `--color-positive`, `--color-selected*`, `--focus-ring-color`, `--inline-space`, `--text-medium`, `--text-small`, `--text-x-small`; `--radius-control` | `card`, `dialog`, `field`, `menu`, `popup_menu` | `popup__*`, `data-table`, `dialog__title`, `menu`, `btn`, `card`, `table` |
| plugin-template | `--block-space-half`, `--color-ink-lighter`, `--inline-space`, `--radius-scale` | `field` | `data-table`, `table`, `btn`, `field` |
| quickbooks | none | `field` | `btn`, `field` |

## 6.0 release notes (draft)

**Runwell 6.0: a new interface.** Every page is rebuilt on runeui, shadcn/ui's look: the nav,
tables and filters, the board, the side panel, pickers and forms, search (⌘K), quick actions,
Settings, sign-in and the client portal. Everything works as before (the same pages, addresses,
keys, agent tools and permissions); it looks cleaner and more consistent.

What people see:

- shadcn's neutral look by default; Settings › Appearance's colours (Indigo, Forest, Plum, Ocean,
  Graphite), corners (Sharp, Soft, Round), fonts and text size act on it. Round corners round
  everything more; buttons and fields are no longer pills.
- Light or dark is remembered as before and applies before the page shows, with no flash, whether
  it's your choice, the install's default or your device's. (Your choice is carried over.)
- Menus and popovers have slightly tighter corners, dialog titles are a touch smaller, and the
  rich text editor looks like the other fields.

For whoever wrote custom CSS (Settings › Appearance › Custom CSS):

- **A theme written for 5.x stops working.** Custom CSS is now a shadcn theme: `:root { … }` and
  `.dark { … }` blocks of shadcn's tokens (`--background`, `--foreground`, `--primary`, `--muted`,
  `--border`, `--radius`…), as tweakcn (tweakcn.com) and ui.shadcn.com/themes write them: paste
  one in (without its `@import` line). Fizzy's palette (`--lch-*`), rune_ui's tokens (`--panel`,
  `--text`, `--accent` as the brand, `--radius-scale`, `--text-scale`) and `html[data-theme="dark"]`
  blocks do nothing now, or, for `--accent`, recolour hovers. docs/theming.md has the tokens and a
  mapping from the old names; Copy brief for AI hands an AI the new guide.
- The rules are unchanged: no `@import`, no `url()` but `data:`; `?theme=off` still skips it.

For plugin authors:

- Plugins keep working unchanged through a compatibility layer, until 7.0: rune_ui's helpers
  (`card`, `badge`, `button_link`, `field`, `menu`, `tabs`…) are drawn by runeui, its classes
  (`.btn`, `.card`, `.table`…) and token names (`--panel`, `--text`, `--line`, `--s-*`…) are
  defined from runeui's tokens, and a plugin stylesheet's `var(--accent)` / `var(--ring)` are
  read as the brand's colour and the focus shadow.
- Move before 7.0: draw with `ui :name` and `form.ui :field`, read runeui's (shadcn's) tokens:
  `--primary` for the brand's colour (`--accent` is now shadcn's hover fill), `--ui-focus-ring` for
  focus, `--muted-foreground`, `--border`… (docs/plugin-contract.md: The UI kit, the compatibility
  layer and its token table), and set `requires: ">= 6.0.0"`.
- Gone: a handful of compatibility classes no published plugin used (`card--danger`, `card--fold`,
  `fold`, `list-row--tall`, `list-row--outline`, `field--inline`, `icon-button--danger`,
  `alert--attention`, `dialog__body`, `menu__*`, `prose`, `table--even`, `table__cap`,
  `crumbs__sep`, `crumbs__current`).
10. **Plugins**, one repository at a time, onto runeui's API; then the compatibility layer goes
    (7.0, as the contract says). Each moved plugin's stylesheet starts `/* tokens: runeui */`, so
    the core serves it unchanged (its `--accent` is shadcn's fill). **Done** (each needs 6.0.0):
    ads 0.3.0, approvals 0.2.0, brain 0.4.0, calendar 0.7.0, client-dashboard 0.3.0, media 0.6.0,
    quickbooks 0.3.0 (which also caught up with 5.0's rename: its tables' `engagement_id` became
    `work_id` and their `contact_id` a user id, by its own migrations). **Left:** google-ads (still
    on engagements, like quickbooks was), leads, meetings (uncommitted work in its repo) and
    plugin-template. For 7.0: a select asks to be small with compat's `select--sm` class
    (`select_control` reads it), which needs a name of its own before compat.css goes. runeui
    gained, from these: a date picker's input wide enough for its placeholder, and an alert that
    wraps a long unbroken line. A badge over an image (media's) needs a solid background of the
    plugin's own; runeui's outline and success badges are see-through.

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
