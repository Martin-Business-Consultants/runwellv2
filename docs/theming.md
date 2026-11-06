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
- **Class names are not.** Component classes (`.panel`, `.btn`, `.card`…) change as the app does.
  A rule that targets one may break on any update. Use them sparingly, for small touches.
- **Custom CSS loads last and unlayered**, after the app's stylesheets and Appearance's choices,
  so a plain `:root { … }` wins without `!important`.
- **Colors are OKLCH triples.** Color tokens hold `L% C H` (lightness, chroma, hue) without
  `oklch()`, so the app can add transparency: `--lch-accent: 55% 0.16 277;`. Set the `--lch-*`
  tokens; the `--color-*` tokens are built from them.
- **Dark mode is a second block.** Set colors for light under `:root`, and again for dark under
  `html[data-theme="dark"]` and `@media (prefers-color-scheme: dark) { html:not([data-theme]) { … } }`
  (dark is either chosen, or the system's when nobody chose).
- **Leave Colors on Indigo** in Settings › Appearance when your theme sets the accent: the other
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
| `--lch-ink-darkest` | Body text, headings | `14.1% 0.005 285.8` |
| `--lch-ink-darker` | Secondary text | `37% 0.013 285.8` |
| `--lch-ink-dark` | Muted text | `55.2% 0.016 285.9` |
| `--lch-ink-medium` | Placeholder text, icons | `64% 0.015 286` |
| `--lch-ink-light` | Input borders | `87.1% 0.006 286.3` |
| `--lch-ink-lighter` | Hairlines, dividers | `92% 0.004 286.3` |
| `--lch-ink-lightest` | Faint fills, hover rows | `96.7% 0.001 286.4` |
| `--lch-ink-inverted` | Text on the accent | `100% 0 0` |
| `--lch-accent` | Links, buttons, focus, the current item | `55% 0.16 277` |
| `--lch-accent-light` | Strong selection | `84% 0.06 277` |
| `--lch-accent-lighter` | Selection | `93% 0.025 277` |
| `--lch-accent-lightest` | Faint selection | `97% 0.012 277` |
| `--lch-red-dark` | Errors, destructive actions (`--color-negative`) | `59% 0.19 38` |
| `--lch-green-dark` | Success (`--color-positive`) | `55% 0.162 147` |

Families for status colors (`red`, `yellow`, `lime`, `green`, `aqua`, `blue`, `purple`) each run
`-darkest` to `-lightest`; change them only to retune the palette.

### Component tokens

The components follow shadcn/ui and read its token names. Each is built from the tokens above, so
a theme normally leaves them alone; set one only to change that role on its own (a theme in both
modes sets it in both blocks).

| Token | What it colors | Built from |
| --- | --- | --- |
| `--primary`, `--primary-foreground` | Primary buttons, switches, checked boxes | the accent, `--lch-ink-inverted` |
| `--card`, `--popover` | Cards, menus and popovers (a step lighter than the page in dark) | `--lch-canvas` |
| `--muted`, `--muted-foreground` | Tab tracks, counts, secondary text | the ink steps |
| `--accent` | Hover and selected rows, menu items | `--lch-ink-lightest` |
| `--destructive` | Delete buttons, errors | `--lch-red-dark` |
| `--border`, `--input`, `--ring` | Hairlines, field borders, focus rings | the ink steps and accent |

### Type

| Token | What it sets | Default |
| --- | --- | --- |
| `--font-sans` | Everything | Inter, then the system font |
| `--font-serif` | Serif text in rich text | `ui-serif, serif` |
| `--font-mono` | Code, refs, keys | `ui-monospace, …` |
| `--text-scale` | Every size at once (Text size sets it) | `1` |
| `--text-x-small` … `--text-xx-large` | The size steps, in rem (shadcn/ui's: the body is `--text-normal`, 14px) | `0.75rem` … `1.875rem` |

### Shape, space and depth

| Token | What it sets | Default |
| --- | --- | --- |
| `--radius-scale` | Every container's corners, as a multiple | `1` |
| `--radius-control` | Buttons, inputs, tags, toggles | `var(--radius-lg)` (0.625rem, shadcn's rounded-lg) |
| `--radius-pill` | Pill shapes | `99rem` |
| `--inline-space` | Horizontal rhythm | `1ch` |
| `--block-space` | Vertical rhythm | `1rem` |
| `--shadow` | Panels and cards | a soft three-layer shadow |
| `--shadow-popover` | Menus and dialogs | a deeper shadow |
| `--main-width` | The widest a page grows | `1400px` |

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
