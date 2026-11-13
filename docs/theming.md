# Theming Runwell

Runwell's look is built on CSS custom properties (design tokens). A theme is a short stylesheet that
gives those tokens new values, so the whole app changes at once: every panel, button, table and
board reads them. Paste it into Settings › Appearance › Custom CSS, or ship it as a plugin
(`Runwell::Plugins.stylesheet`).

Start with Settings › Appearance (theme, colors, corners, font, text size, logo and favicon). Reach
for custom CSS when those choices aren't enough to make Runwell look like your own.

## The contract

- **Tokens are the stable surface.** The tokens below keep their names and meaning across
  releases. A theme that only sets tokens keeps working when Runwell updates.
- **Class names are not.** Component classes (`.btn`, `.card`, `.list-row`…) change as the app does.
  A rule that targets one may break on any update. Use them sparingly, for small touches.
- **Custom CSS loads last and unlayered**, after the app's stylesheets and Appearance's choices,
  so a plain `:root { … }` wins without `!important`.
- **Colors are OKLCH triples.** Color tokens hold `L% C H` (lightness, chroma, hue) without
  `oklch()`, so the app can add transparency: `--lch-accent: 51% 0.26 277;`. Set the `--lch-*`
  tokens; the `--color-*` tokens are built from them.
- **Dark mode is a second block.** Set colors for light under `:root`, and again for dark under
  `html[data-theme="dark"]` and `@media (prefers-color-scheme: dark) { html:not([data-theme]) { … } }`
  (dark is either chosen, or the system's when nobody chose).
- **Leave Colors on Neutral** in Settings › Appearance when your theme sets the accent: the other
  schemes set it with a more specific selector.
- **Not allowed:** `@import`, `url()` other than `data:` URIs, `expression()`, `javascript:`,
  `behavior`, `-moz-binding` and `</`. Fonts must be ones people have installed, or embedded as
  `data:` URIs. Runwell refuses a stylesheet that breaks these rules.
- **Escape hatch:** add `?theme=off` to any address to see the page without the custom CSS, for
  when a theme makes Settings hard to reach.

## Tokens

### Color

| Token | What it colors | Default (light) |
| --- | --- | --- |
| `--lch-canvas` | The page and panels | `100% 0 0` |
| `--lch-ink-darkest` | Body text, headings | `14.5% 0 0` |
| `--lch-ink-darker` | Secondary text | `37.1% 0 0` |
| `--lch-ink-dark` | Muted text | `55.6% 0 0` |
| `--lch-ink-medium` | Placeholder text, icons | `64% 0 0` |
| `--lch-ink-light` | Input borders | `92.2% 0 0` |
| `--lch-ink-lighter` | Hairlines, dividers | `92.2% 0 0` |
| `--lch-ink-lightest` | Faint fills, hover rows | `97% 0 0` |
| `--lch-ink-inverted` | Text on the accent | `98.5% 0 0` |
| `--lch-accent` | Buttons, links, switches, the current item | `20.5% 0 0` |
| `--lch-accent-light` | Strong selection | `87% 0 0` |
| `--lch-accent-lighter` | Selection | `94% 0 0` |
| `--lch-accent-lightest` | Faint selection | `97% 0 0` |
| `--lch-ring` | The focus ring, drawn 3px wide at half strength | `70.8% 0 0` |
| `--lch-red-dark` | Errors, destructive actions (`--color-negative`) | `57.7% 0.245 27.325` |
| `--lch-green-dark` | Success (`--color-positive`) | `55% 0.162 147` |

Families for status colors (`red`, `yellow`, `lime`, `green`, `aqua`, `blue`, `purple`) each run
`-darkest` to `-lightest`; change them only to retune the palette.

The defaults are shadcn/ui's neutral theme: greys with no hue, and an accent (its `--primary`)
that is near-black in light and near-white in dark. Settings › Appearance › Color gives the accent
a colour and leaves the greys alone.

### Component tokens

The components come from rune_ui (the UI kit Runwell shares with Botter) and read its token names.
Runwell builds each from the tokens above (`rune-theme.css`), light and dark, so a theme normally
leaves them alone; set one only to change that role on its own (a theme in both modes sets it in
both blocks).

| Token | What it colors | Built from |
| --- | --- | --- |
| `--page` | Behind the panel (the nav's ground) | halfway from `--lch-canvas` to `--lch-ink-lightest` (`--lch-ink-lightest` in dark) |
| `--panel` | The page's panel, cards, menus and dialogs | `--lch-canvas` |
| `--layer-1`, `--layer-2`, `--layer-3` | Faint fills: settings cards, tab tracks, hovered menu items, switch tracks | the ink steps |
| `--text`, `--text-muted`, `--text-faint` | Body text, secondary text, hints and icons | `--lch-ink-darkest`, `-dark`, `-medium` |
| `--line`, `--line-strong` | Hairlines, field and button borders | `--lch-ink-lighter`, `-light` |
| `--hover` | Hovered rows and ghost buttons | `--lch-ink-darkest` at 4% (white at 8% in dark) |
| `--accent`, `--accent-hover`, `--accent-ink`, `--accent-soft` | Primary buttons, links, switches, checked boxes, picked rows | `--lch-accent`, `--lch-ink-inverted`, `--lch-accent-lightest` |
| `--ring` | The focus ring (a box-shadow) | `--lch-ring` |
| `--ok`, `--danger`, `--attention` | Success, errors and destructive actions, warnings and counts | `--color-positive`, `--color-negative`, `--lch-yellow-dark` |

Primary buttons are drawn in the accent, with `--accent-ink` for their text.

### Type

| Token | What it sets | Default |
| --- | --- | --- |
| `--font-sans` | Everything | Inter, then the system font |
| `--font-mono` | Code, refs, keys | `ui-monospace, …` |
| `--text-scale` | Every size at once (Text size sets it): the root is `calc(1rem * --text-scale)` and every size is rem | `1` |
| `--text-xs`, `--text-meta`, `--text-ui`, `--text-read`, `--text-title` | The size steps: badges, hints, the UI (the body), reading text, a page title | `0.75rem`, `0.75rem`, `0.875rem`, `0.875rem`, `1.25rem` |
| `--weight`, `--weight-strong` | Body and emphasis weights | `400`, `500` |

### Shape, space and depth

| Token | What it sets | Default |
| --- | --- | --- |
| `--radius-scale` | Every container's corners, as a multiple (of 0.625rem and the steps round it: 0.375rem rows, 0.875rem cards) | `1` |
| `--radius-control` | Buttons, inputs, tags, toggles | `0.5rem`, times `--radius-scale` |
| `--radius-pill` | Pill shapes | `99rem` |
| `--s-1` … `--s-6` | The space steps | `0.25rem` … `2rem` |
| `--control-h`, `--control-h-sm` | Button and field heights | `2.25rem`, `2rem` |
| `--shadow-popover` | Menus and dialogs | a deeper shadow |
| `--main-width` | The widest a page grows | `1400px` |

### Retired in 4.0

These were read by the old components and no longer are, so setting them does nothing:
`--font-serif`, `--text-x-small` … `--text-xx-large` (use `--text-scale` or the steps above),
`--inline-space`, `--block-space`, `--shadow`, and shadcn's component tokens (`--primary`,
`--card`, `--popover`, `--muted`, `--border`, `--input`…). Set the `--lch-*` palette
instead, or the component tokens above.

## An example

A warm, rounded theme for a bakery, in both modes:

```css
:root {
  --font-sans: "Avenir Next", Avenir, "Segoe UI", sans-serif;
  --lch-canvas: 99% 0.006 85;
  --lch-ink-darkest: 27% 0.03 50;
  --lch-ink-darker: 40% 0.03 50;
  --lch-ink-lightest: 96% 0.012 80;
  --lch-ink-lighter: 91% 0.016 80;
  --lch-accent: 58% 0.14 40;
  --lch-accent-light: 84% 0.06 40;
  --lch-accent-lighter: 93% 0.03 40;
  --lch-accent-lightest: 97% 0.014 40;
  --radius-scale: 1.4;
  --radius-control: 0.75rem;
}

html[data-theme="dark"] {
  --lch-canvas: 20% 0.012 50;
  --lch-accent: 72% 0.13 45;
}

@media (prefers-color-scheme: dark) {
  html:not([data-theme]) {
    --lch-canvas: 20% 0.012 50;
    --lch-accent: 72% 0.13 45;
  }
}
```

## Asking an AI for a theme

Settings › Appearance › Copy brief for AI copies this guide with the install's current settings and
custom CSS. Paste it into any AI with a description, the logo or the website of the business, and
ask for a theme. Its answer is a stylesheet to paste back into Custom CSS, or an AI connected to
Runwell can apply it with the `update_appearance` tool (`custom_css`).

Things to ask of it: contrast of at least 4.5:1 for body text on the canvas in both modes, an
accent that reads on white and on the dark canvas, and tokens only unless a class is the only way.
