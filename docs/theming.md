# Theming Runwell

Runwell's interface is runeui (`../runeui`), which reads shadcn/ui's design tokens by name and
meaning. A theme is a shadcn theme: a short stylesheet that gives those tokens new values, so the
whole app changes at once, every panel, button, table, board and dialog. Paste it into Settings ›
Appearance › Custom CSS, or ship it as a plugin (`Runwell::Plugins.stylesheet`).

Start with Settings › Appearance (theme, colors, corners, font, text size, logo and favicon). Reach
for custom CSS when those choices aren't enough to make Runwell look like your own. Any theme from
[tweakcn](https://tweakcn.com) or [ui.shadcn.com/themes](https://ui.shadcn.com/themes) works as it
is: copy its CSS (the `:root { … }` and `.dark { … }` blocks) and paste it.

## The contract

- **Tokens are the stable surface.** The tokens below are shadcn's, plus runeui's `--ui-*` scale
  and a few of Runwell's own, and keep their names and meaning across releases. A theme that only
  sets tokens keeps working when Runwell updates.
- **Class names are not.** Component classes and `data-slot` names change as the app does. A rule
  that targets one may break on any update. Use them sparingly, for small touches.
- **Custom CSS loads last and unlayered**, after the app's stylesheets and Appearance's choices
  (which are in cascade layers), so a plain `:root { … }` wins without `!important`, whatever the
  scheme, corners and font chosen in Appearance. A token your theme leaves out keeps Appearance's
  value.
- **Colors are any CSS color.** shadcn's themes use `oklch(…)`; hex, `rgb()` and `hsl()` work
  too.
- **Dark mode is a second block: `.dark { … }`.** Runwell puts `.dark` on `<html>` (before the page
  first paints) when the person picks dark, or the install's default or their system says so.
  Set colors for light under `:root` and for dark under `.dark`, as shadcn's themes do. Leave
  `color-scheme` alone: runeui sets it, and a few surfaces follow it.
- **Not allowed:** `@import`, `url()` other than `data:` URIs, `expression()`, `javascript:`,
  `behavior`, `-moz-binding` and `</`. Fonts must be ones people have installed, or embedded as
  `data:` URIs. Runwell refuses a stylesheet that breaks these rules (so a theme from tweakcn that
  starts with an `@import` of a Google font needs that line taken out).
- **Escape hatch:** add `?theme=off` to any address to see the page without the custom CSS, for
  when a theme makes Settings hard to reach.
- **The portal** (what clients see) takes the custom CSS only when Settings › Appearance says
  "everywhere".

## Tokens

### Color: shadcn's

| Token | What it colors | Neutral, light | Neutral, dark |
| --- | --- | --- | --- |
| `--background`, `--foreground` | The page and panels; body text | `oklch(1 0 0)`, `oklch(0.145 0 0)` | `oklch(0.145 0 0)`, `oklch(0.985 0 0)` |
| `--card`, `--card-foreground` | Cards | as the page | as the page (Runwell's dark keeps cards on the page's ground) |
| `--popover`, `--popover-foreground` | Menus, popovers, the palette | as the page | as the page |
| `--primary`, `--primary-foreground` | The brand's colour: primary buttons, links, switches, checked boxes, the current item; the text on it | `oklch(0.205 0 0)`, `oklch(0.985 0 0)` | `oklch(0.922 0 0)`, `oklch(0.205 0 0)` |
| `--secondary`, `--secondary-foreground` | Secondary buttons | `oklch(0.97 0 0)`, `oklch(0.205 0 0)` | `oklch(0.269 0 0)`, `oklch(0.985 0 0)` |
| `--muted`, `--muted-foreground` | Quiet fills (tab tracks, table headers); secondary text | `oklch(0.97 0 0)`, `oklch(0.556 0 0)` | `oklch(0.269 0 0)`, `oklch(0.708 0 0)` |
| `--accent`, `--accent-foreground` | The hover and highlight fill of menu items, ghost buttons, options (not the brand: that's `--primary`) | `oklch(0.97 0 0)`, `oklch(0.205 0 0)` | `oklch(0.269 0 0)`, `oklch(0.985 0 0)` |
| `--destructive` | Errors, destructive actions | `oklch(0.577 0.245 27.325)` | `oklch(0.704 0.191 22.216)` |
| `--border`, `--input` | Hairlines; field and button borders | `oklch(0.922 0 0)` | `oklch(1 0 0 / 10%)`, `oklch(1 0 0 / 15%)` |
| `--ring` | The focus ring's colour (drawn 3px wide at half strength) | `oklch(0.708 0 0)` | `oklch(0.556 0 0)` |
| `--sidebar`, `--sidebar-foreground`, `--sidebar-accent`, `--sidebar-accent-foreground`, `--sidebar-border` | The nav down the left | `oklch(0.985 0 0)` … | `oklch(0.205 0 0)` … |
| `--sidebar-primary`, `--sidebar-primary-foreground`, `--sidebar-ring` | The nav's current item and focus | `--primary`, `--primary-foreground`, `--ring` | the same |
| `--chart-1` … `--chart-5` | Charts (plugins) | shadcn's | shadcn's |

Settings › Appearance › Colors sets `--primary`, `--primary-foreground` and `--ring` (Indigo,
Forest, Plum, Ocean, Graphite; Neutral is the table above) and leaves the greys alone.

### Color: beyond shadcn's

| Token | What it colors | Default |
| --- | --- | --- |
| `--success`, `--warning`, `--info` | runeui's status colours: badges, alerts, toasts, a task's status | a green and an amber that read as text (lighter in dark); `--info` is `--primary` |
| `--faint-foreground` | A third step of text, under `--muted-foreground`: hints, meta, placeholders | `--muted-foreground` at 80% (72% in dark) |
| `--brand-tint`, `--brand-tint-strong` | What's chosen, current or under the keys (the selected row, the current nav item) | `--primary` mixed into `--background` (shadcn's `--accent` fill in Neutral) |

These are derived from shadcn's tokens, so a theme normally leaves them alone; set one to tune that
role on its own (in both blocks).

### Type, shape and size

| Token | What it sets | Default |
| --- | --- | --- |
| `--font-sans` | Everything | Inter, then the system font (Settings › Appearance › Font) |
| `--font-mono` | Code, refs, keys | `ui-monospace, …` |
| `--radius` | Every corner: runeui derives the rest from it (`--ui-radius-sm` … `--ui-radius-xl`) | `0.625rem` (Settings › Appearance › Corners: Sharp `0.25rem`, Round `1rem`) |

Text size (Settings › Appearance, or a person's own in Your account) sets the root's font size;
every size is rem, so it all scales. A theme can do the same with `html { font-size: … }`.

### runeui's scale (`--ui-*`)

runeui's components read these. They're derived from the tokens above, so a theme rarely needs
them; set one to change that step everywhere.

| Token | What it sets | Default |
| --- | --- | --- |
| `--ui-radius-sm`, `--ui-radius-md`, `--ui-radius-lg`, `--ui-radius-xl`, `--ui-radius-full` | Rows and items; controls and menus; tabs and alerts; cards and dialogs; pills | `--radius` − 4px, − 2px, itself, + 4px; `9999px` |
| `--ui-h-xs`, `--ui-h-sm`, `--ui-h`, `--ui-h-lg` | Control heights | `1.5rem`, `2rem`, `2.25rem`, `2.5rem` |
| `--ui-text-xs`, `--ui-text-sm`, `--ui-text`, `--ui-text-lg` | Text steps (the body is `--ui-text-sm`) | `0.75rem`, `0.875rem`, `1rem`, `1.125rem` |
| `--ui-shadow-xs` … `--ui-shadow-lg` | Shadows | shadcn's |
| `--ui-focus-ring`, `--ui-invalid-ring` | The focus and error rings (box-shadows) | from `--ring`, `--destructive` |
| `--ui-duration`, `--ui-duration-slow`, `--ui-ease` | Motion | `150ms`, `200ms`, an ease-out |

### Retired in 6.0

Themes written for 5.x set Fizzy's palette (`--lch-canvas`, `--lch-ink-*`, `--lch-accent*`,
`--lch-ring`…) and rune_ui's component tokens (`--panel`, `--page`, `--text`, `--line`, `--accent`
as the brand's colour, `--radius-scale`, `--radius-control`, `--text-scale`…). Runwell reads none
of these now: such a theme does nothing (or, for `--accent`, recolours hovers). Rewrite it as a
shadcn theme: `--background` for `--lch-canvas`, `--foreground` for `--lch-ink-darkest`,
`--muted-foreground` for `--lch-ink-dark`, `--border` and `--input` for `--lch-ink-lighter` and
`-light`, `--muted` for `--lch-ink-lightest`, `--primary` and `--primary-foreground` for
`--lch-accent` and `--lch-ink-inverted`, `--ring` for `--lch-ring`, `--radius` for `--radius-scale`
(`0.625rem` × the scale); and `.dark { … }` for `html[data-theme="dark"]` and the
`prefers-color-scheme` block.

## An example

A warm, rounded theme for a bakery, in both modes:

```css
:root {
  --font-sans: "Avenir Next", Avenir, "Segoe UI", sans-serif;
  --radius: 0.875rem;
  --background: oklch(0.99 0.006 85);
  --foreground: oklch(0.27 0.03 50);
  --card: oklch(0.99 0.006 85);
  --popover: oklch(0.99 0.006 85);
  --primary: oklch(0.58 0.14 40);
  --primary-foreground: oklch(0.98 0.01 85);
  --muted: oklch(0.96 0.012 80);
  --muted-foreground: oklch(0.48 0.03 50);
  --accent: oklch(0.95 0.02 60);
  --border: oklch(0.91 0.016 80);
  --input: oklch(0.89 0.016 80);
  --ring: oklch(0.58 0.14 40);
  --sidebar: oklch(0.97 0.01 80);
}

.dark {
  --background: oklch(0.2 0.012 50);
  --foreground: oklch(0.96 0.01 85);
  --card: oklch(0.2 0.012 50);
  --popover: oklch(0.2 0.012 50);
  --primary: oklch(0.72 0.13 45);
  --primary-foreground: oklch(0.22 0.03 45);
  --muted: oklch(0.27 0.014 50);
  --muted-foreground: oklch(0.72 0.02 60);
  --accent: oklch(0.3 0.02 50);
  --border: oklch(1 0 0 / 10%);
  --input: oklch(1 0 0 / 15%);
  --ring: oklch(0.72 0.13 45);
  --sidebar: oklch(0.24 0.014 50);
}
```

## Asking an AI for a theme

Settings › Appearance › Copy brief for AI copies this guide with the install's current settings and
custom CSS. Paste it into any AI with a description, the logo or the website of the business, and
ask for a theme. Its answer is a stylesheet to paste back into Custom CSS, or an AI connected to
Runwell can apply it with the `update_appearance` tool (`custom_css`).

Things to ask of it: a shadcn theme (`:root` and `.dark` blocks of the tokens above), contrast of at
least 4.5:1 for body text on `--background` and for `--primary-foreground` on `--primary` in both
modes, and tokens only unless a class is the only way.
