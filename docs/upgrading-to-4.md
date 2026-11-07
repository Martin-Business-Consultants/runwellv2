# Upgrading a plugin to Runwell 4.0

Runwell 4.0 replaces the core's whole UI. The components came from two places, nobuild_ui (a
port of shadcn/ui, the `ui-*` classes) and Fizzy's stylesheets (`btn`, `panel`, `popup`, the
utility classes). They now come from **rune_ui**, the UI kit Runwell shares with Botter. Nothing
else in the plugin contract changed: models, slots, events, agents and the portal work as they
did. A plugin with no views or stylesheet of its own needs no change.

A plugin whose views use the old classes still loads and works, but those classes are no longer
styled: buttons draw as plain buttons, cards lose their frame, utility spacing disappears. Set
`requires: ">= 4.0"` once it's moved.

## Before you start

- Read rune_ui's README (`../rune_ui/README.md` beside the core, or the gem's own) for every
  helper and class, and open `/ui` in a development install to see them in Runwell's theme.
- Build markup with the helpers where one fits. They write the markup in Ruby, so it comes out
  right whatever compiles your templates.
- In templates compiled by ReActionView (Herb), pass `class:` as one string
  (`class_names(...)`), never an array, and never `id: nil`.
- Every `<form>` is a flex column with a gap (`form.button_to` stays inline). An inline form needs
  a layout class of your own.
- Inputs, selects and textareas need no class: rune_ui styles the bare elements.

## Helpers

| 3.x | 4.0 |
| --- | --- |
| `ui_button`, `ui_link_button` | `button_link label, url, variant:, size:, icon:`, `action_button` (a `button_to`), `submit_button form` |
| `ui_button_classes(variant:, size:)` | `button_classes(variant:, size:)` (a string) |
| an icon-only `ui-button--icon-sm` | `icon_button :name, label:, url:` |
| `ui_badge` | `badge "Text", tone: :ok` (`:danger`, `:attention`, `:accent`, `:outline`); a Runwell status: `status_tag label` or `ui_status_badge label` |
| `ui_kbd` | `<kbd>` |
| `ui_avatar` | `avatar name, url:, size:` (`:md`, `:lg`); a user: `person_tag user` |
| `ui_dropdown` + `ui_menu_item` / `ui_menu_label` / `ui_menu_separator` | `menu "Label" do … end` with `menu_link`, `menu_button`, `menu_label`, `menu_divider`; in a row that scrolls, `popover_menu` |
| a `ui-dialog` written by hand | `dialog "Title", trigger: "Open" do … dialog_actions { … } end`, `sheet`, or `confirm_dialog` for a destructive action |
| `icon_tag "name"` | unchanged; it now draws an inline SVG (`icon_tag` keeps working for every name the core had) |

`popup_menu`, `switch_field`, `switch_tag`, `secret_field`, `money_field`, `date_input`,
`rich_text_field`, `code_block` and the shared partials (`layouts/shared/empty`, `card`,
`delete_dialog`, `confirm`, `row_actions`, `quick_filter`, `index_toolbar`) keep their
arguments; only their markup changed.

## Classes

| 3.x | 4.0 |
| --- | --- |
| `ui-button` (`--secondary`, `--outline`, `--ghost`, `--destructive`; `--sm`) | `btn btn--primary` (`btn--secondary`, `btn--ghost`, `btn--danger`; `btn--sm`) |
| `ui-button--icon`, `--icon-sm`; Fizzy's `btn--circle`, `btn--plain` | `icon-button` |
| `ui-button--block` | `btn--block` |
| `ui-button--link`, Fizzy's `btn--link` | `link-button`, or a plain link |
| a filter's trigger (`ui-dropdown__trigger`) | `pill`, with `icon_tag "caret-down"` after its text |
| `ui-card` (`__header`, `__title`, `__description`, `__action`, `__content`, `__footer`), Fizzy's `panel` | `card` (`__head`, `__title`, `__hint`, `__action`, `__content`, `__footer`), or the `card` helper |
| `ui-item` (`__media`, `__content`, `__title`, `__description`, `__actions`) | `list-row` (`__media`, `__content`, `__title`, `__desc`, `__actions`) in a `list`, or `list_row` |
| `ui-field`, `ui-label`, `ui-field__description` | `field`, `field__label`, `field__hint`, or the `field` helper; side by side, `field-row` |
| `ui-input`, `ui-select`, `ui-textarea`, `ui-checkbox`, Fizzy's `input` | nothing (bare elements are styled); a small one, `input--sm` / `select--sm` |
| `ui-switch`, Fizzy's `switch` with `switch__btn` | `switch(form, :attr)`, or `switch_field` / `switch_tag` |
| `ui-badge`, Fizzy's `status-tag` | `badge` with a tone; a count, `count` (`count--quiet`) |
| `ui-tabs`, `ui-tabs__trigger` | `tabs`, `tabs__tab` (`tabs--pills`, `tabs--icons`), or the `tabs` helper |
| `ui-alert` (`--destructive`, `--warning`) | `alert alert--danger` (`--attention`, `--info`, `--ok`), or `callout` |
| `ui-table`, `ui-table-container` | `table` in a `table-wrap` |
| `ui-empty`, Fizzy's `blank-slate` | `empty`, or `empty_state` |
| `ui-separator` | `separator` (`separator--label` with text), or `<hr>` |
| facts (`record-facts`, a `dl`) | `dl.details` |

## Utility classes

Fizzy's utilities are gone. Lay out with your own class and `gap`, or rune_ui's:

| 3.x | 4.0 |
| --- | --- |
| `flex`, `flex-column`, `gap`, `gap-half` | `stack` (a column with a gap), `button-row` (a wrapping row), or a class of your own |
| `margin-*`, `pad-*` | `gap` on the parent; rune_ui never uses sibling margins |
| `txt-subtle`, `txt-small`, `txt-x-small` | `muted`, `faint`, `small` |
| `txt-nowrap`, `overflow-ellipsis` | `nowrap`, or `text-overflow` in your stylesheet |
| `for-screen-reader` | `visually-hidden` |
| `hide-on-touch` | unchanged |

## Icons

The 86 mask icons (`icons.css` and their SVG files) are gone. `icon_tag "name"` draws the same
names as inline SVG, through rune_ui's icon registry, and a name nobody registered draws a dot. A
plugin with icons of its own registers them in its engine's `config.to_prepare`:

```ruby
RuneUi.register_icons(
  "invoice" => '<rect x="3" y="2" width="10" height="12" rx="1.5"/><path d="M6 6h4M6 9h4"/>'
)
```

Each value is the inner SVG of a 16 × 16 icon stroked with `currentColor`.

## Stylesheets and tokens

A plugin's stylesheet (`Runwell::Plugins.stylesheet`) loads after the core's, unlayered. Read
rune_ui's tokens (`--panel`, `--text`, `--text-muted`, `--line`, `--accent`, `--s-1` … `--s-6`,
`--radius-control`, `--text-meta`…; the table is in [theming.md](theming.md)). shadcn's tokens
(`--primary`, `--card`, `--muted`, `--border`…) and Fizzy's `--color-ink-*` steps are no longer
built. Space children with `gap`, never sibling margins, and show states with tints, weight, dots
and badges rather than coloured left borders.

## Checking a plugin

1. `grep -rnE '\bui-|\b(btn--(plain|circle|link|reversed)|panel|status-tag|blank-slate|for-screen-reader|txt-[a-z-]+|margin-[a-z-]+|pad-[a-z-]+|flex-[a-z-]+)\b' app/views`
   finds what's left.
2. Open each of its pages in light and dark, at the larger text sizes, and with Corners set to
   square and round.
3. `bundle exec herb lint app/views` in the plugin, if its templates go through ReActionView.
