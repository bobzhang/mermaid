# bobzhang/beautiful_mermaid

Render Mermaid diagrams as SVG or ASCII/Unicode text in MoonBit.

## Features

- Flowchart, state, sequence, class, and ER parsing/rendering.
- SVG output with CSS-variable theming.
- ASCII/Unicode terminal rendering.
- Configurable layout and rendering options.
- Smoke coverage against the upstream `beautiful-mermaid/samples-data.ts` corpus.

## Architecture

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the parser/layout/renderer pipeline, module boundaries, and test architecture.

## Credits

This project is a MoonBit port of [`beautiful-mermaid`](https://github.com/lukilabs/beautiful-mermaid) by Luki Labs, with additional inspiration from [`mermaid-ascii`](https://github.com/AlexanderGrooff/mermaid-ascii) by Alexander Grooff.

- Original project: `beautiful-mermaid` (TypeScript)
- Original terminal renderer inspiration: `mermaid-ascii` (Go)
- Port in this repository: `bobzhang/beautiful_mermaid` (MoonBit)
- License: MIT (aligned with the original project)

## Maintainer Workflow

Regenerate the upstream sample smoke test after upstream `samples-data.ts` changes:

- `bun run scripts/generate_upstream_samples_smoke.ts`
- `moon test upstream_samples_smoke_test.mbt --target native`
- `moon test ascii_flowchart_corpus_test.mbt --target native`
- `moon test ascii_state_corpus_test.mbt --target native`
- `CATEGORY=State bun run scripts/check_sample_text_parity.ts` (optional parity audit against upstream text output)
- `bun run scripts/check_upstream_parity_title_coverage.ts` (ensures parity titles match upstream sample titles exactly)

## Quick Start

### SVG rendering

```mbt check
///|
test "simple_td" (it : @test.Test) {
  let svg = render_mermaid(
    (
      #|graph TD
      #|A --> B
    ),
  )
  it.write(svg)
  it.snapshot(filename="simple_td.svg")
}
```

### ASCII rendering

```mbt check
///|
test {
  let ascii = render_mermaid_ascii(
    (
      #|graph LR
      #|A --> B
    ),
  )
  inspect(
    ascii,
    content=(
      #|┌───┐     ┌───┐
      #|│   │     │   │
      #|│ A ├────►│ B │
      #|│   │     │   │
      #|└───┘     └───┘
    ),
  )
}
```

## Public API

- `parse_mermaid(text) -> MermaidGraph raise MermaidError`
- `render_mermaid(text, options?) -> String raise MermaidError`
- `render_mermaid_ascii(text, options?) -> String raise MermaidError`
- `render_mermaid_with_theme_name(text, theme_name, options?) -> String raise MermaidError`

## Styling Options

`render_mermaid` accepts `RenderOptions` for colors, font, spacing, and transparency.

```mbt check
///|
test {
  let options = RenderOptions::{
    bg: Some("#18181B"),
    fg: Some("#FAFAFA"),
    line: Some("#7aa2f7"),
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: Some("Inter"),
    padding: None,
    node_spacing: None,
    layer_spacing: None,
    transparent: Some(true),
  }
  let svg = render_mermaid(
    (
      #|graph TD
      #|A --> B
    ),
    options~,
  )
  assert_true(svg.contains("--bg:#18181B"))
  assert_true(svg.contains("--line:#7aa2f7"))
}
```

## Built-in Themes

Use built-in theme presets by name directly in `render_mermaid_with_theme_name`.
`default` is accepted as an alias for `zinc-light`.
Available slugs: `zinc-light`, `zinc-dark`, `tokyo-night`, `tokyo-night-storm`, `tokyo-night-light`, `catppuccin-mocha`, `catppuccin-latte`, `nord`, `nord-light`, `dracula`, `github-light`, `github-dark`, `solarized-light`, `solarized-dark`, `one-dark`.
Theme names are case-insensitive and accept whitespace/underscores/hyphens.
Leading/trailing separators are ignored, so forms like `__github_dark__` also normalize.

```mbt check
///|
test {
  let svg = render_mermaid_with_theme_name(
    (
      #|graph TD
      #|A --> B
    ),
    "tokyo-night",
  )
  assert_true(svg.contains("--bg:#1a1b26"))
  assert_true(svg.contains("--accent:#7aa2f7"))
}
```

Or render in one call:

```mbt check
///|
test {
  let svg = render_mermaid_with_theme_name(
    (
      #|graph TD
      #|A --> B
    ),
    "github-dark",
  )
  assert_true(svg.contains("--bg:#0d1117"))
  assert_true(svg.contains("--accent:#4493f8"))
}
```

## CLI

Run the local CLI entrypoint from the module root:

- `moon run cmd/main -- "graph TD\nA --> B"`
- `moon run cmd/main -- --ascii "graph LR\nA --> B"`
- `moon run cmd/main -- --ascii --ascii-padding-x 8 "graph LR\nA --> B"`
- `moon run cmd/main -- --ascii --ascii-padding-y 2 "graph LR\nA --> B"`
- `moon run cmd/main -- --ascii --ascii-box-border-padding 2 "graph LR\nA --> B"`
- `moon run cmd/main -- --unicode "graph LR\nA --> B"`
- `--ascii-padding-x`, `--ascii-padding-y`, and `--ascii-box-border-padding` are valid only with `--ascii` or `--unicode`
- SVG flags (`--theme`, `--font`, `--bg`, etc.) are valid only in SVG output mode (without `--ascii`/`--unicode`)
- `moon run cmd/main -- --theme=tokyo-night "graph TD\nA --> B"`
- `moon run cmd/main -- --theme=default "graph TD\nA --> B"`
- `moon run cmd/main -- --theme tokyo-night "graph TD\nA --> B"`
- `moon run cmd/main -- --theme "TOKYO   NIGHT" "graph TD\nA --> B"` (normalized automatically)
- `moon run cmd/main -- --font "Roboto Mono" "graph TD\nA --> B"`
- `moon run cmd/main -- --bg "#0f172a" "graph TD\nA --> B"`
- `moon run cmd/main -- --fg "#e2e8f0" "graph TD\nA --> B"`
- `moon run cmd/main -- --line "#64748b" "graph TD\nA --> B"`
- `moon run cmd/main -- --accent "#38bdf8" "graph TD\nA --> B"`
- `moon run cmd/main -- --muted "#94a3b8" "graph TD\nA --> B"`
- `moon run cmd/main -- --surface "#0b1220" "graph TD\nA --> B"`
- `moon run cmd/main -- --border "#334155" "graph TD\nA --> B"`
- `moon run cmd/main -- --padding 20 "graph TD\nA --> B"`
- `moon run cmd/main -- --node-spacing 80 "graph TD\nA --> B --> C"`
- `moon run cmd/main -- --layer-spacing 90 "graph TD\nA --> B --> C"`
- `moon run cmd/main -- --transparent "graph TD\nA --> B"`
- `moon run cmd/main -- --list-themes`
- `--list-themes` includes built-in slugs plus `default` (alias of `zinc-light`)
