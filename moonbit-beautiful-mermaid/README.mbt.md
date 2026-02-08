# hongbozhang/beautiful_mermaid

Render Mermaid diagrams as SVG or ASCII/Unicode text in MoonBit.

## Features

- Flowchart, state, sequence, class, and ER parsing/rendering.
- SVG output with CSS-variable theming.
- ASCII/Unicode terminal rendering.
- Configurable layout and rendering options.

## Quick Start

### SVG rendering

```mbt check
test {
  let svg = try! render_mermaid("graph TD\nA --> B")
  assert_true(svg.has_prefix("<svg "))
  assert_true(svg.contains(">A</text>"))
  assert_true(svg.contains(">B</text>"))
}
```

### ASCII rendering

```mbt check
test {
  let ascii = try! render_mermaid_ascii("graph LR\nA --> B")
  assert_true(ascii.contains("A"))
  assert_true(ascii.contains("B"))
}
```

## Styling Options

`render_mermaid` accepts `RenderOptions` for colors, font, spacing, and transparency.
Use `default_colors()` if you want to start from package defaults and override selectively.

```mbt check
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
  let svg = try! render_mermaid("graph TD\nA --> B", options~)
  assert_true(svg.contains("--bg:#18181B"))
  assert_true(svg.contains("--line:#7aa2f7"))
}
```

## Built-in Themes

Use built-in theme presets by name and pass the resulting colors through `RenderOptions`.
Use `built_in_theme_colors()` if you want the full slug-to-colors map.

```mbt check
test {
  let colors = match theme_by_name("tokyo-night") {
    Some(found) => found
    None => fail("missing theme")
  }
  let options = RenderOptions::{
    bg: Some(colors.bg),
    fg: Some(colors.fg),
    line: colors.line,
    accent: colors.accent,
    muted: colors.muted,
    surface: colors.surface,
    border: colors.border,
    font: None,
    padding: None,
    node_spacing: None,
    layer_spacing: None,
    transparent: None,
  }
  let svg = try! render_mermaid("graph TD\nA --> B", options~)
  assert_true(svg.contains("--bg:#1a1b26"))
  assert_true(svg.contains("--accent:#7aa2f7"))
}
```

Or render in one call:

```mbt check
test {
  let svg = try! render_mermaid_with_theme_name(
    "graph TD\nA --> B",
    "github-dark",
  )
  assert_true(svg.contains("--bg:#0d1117"))
  assert_true(svg.contains("--accent:#4493f8"))
}
```

Typed variant via parsed enum:

```mbt check
test {
  let theme = match parse_theme_name("tokyo-night") {
    Some(found) => found
    None => fail("missing theme")
  }
  let svg = try! render_mermaid_with_theme("graph TD\nA --> B", theme)
  assert_true(svg.contains("--bg:#1a1b26"))
}
```

### Theme Extraction from Editor-Like Theme Data

Use `from_shiki_theme` to map editor/theme token data into `DiagramColors`.

```mbt check
test {
  let shiki_theme = ShikiTheme::{
    theme_type: Some("dark"),
    colors: Some({
      "editor.background": "#1a1b26",
      "editor.foreground": "#a9b1d6",
      "editorLineNumber.foreground": "#565f89",
      "focusBorder": "#7aa2f7",
    }),
    token_colors: Some([
      ShikiTokenColor::{ scopes: ["comment"], foreground: Some("#565f89") },
    ]),
  }
  let colors = from_shiki_theme(shiki_theme)
  let svg = try! render_mermaid_with_colors("graph TD\nA --> B", colors)
  assert_true(svg.contains("--bg:#1a1b26"))
  assert_true(svg.contains("--accent:#7aa2f7"))
}
```

## CLI

Run the local CLI entrypoint from the module root:

- `moon run cmd/main -- "graph TD\nA --> B"`
- `moon run cmd/main -- --ascii "graph LR\nA --> B"`
- `moon run cmd/main -- --theme=tokyo-night "graph TD\nA --> B"`
- `moon run cmd/main -- --theme tokyo-night "graph TD\nA --> B"`
- `moon run cmd/main -- --font "Roboto Mono" "graph TD\nA --> B"`
- `moon run cmd/main -- --bg "#0f172a" "graph TD\nA --> B"`
- `moon run cmd/main -- --fg "#e2e8f0" "graph TD\nA --> B"`
- `moon run cmd/main -- --line "#64748b" "graph TD\nA --> B"`
- `moon run cmd/main -- --accent "#38bdf8" "graph TD\nA --> B"`
- `moon run cmd/main -- --muted "#94a3b8" "graph TD\nA --> B"`
- `moon run cmd/main -- --surface "#0b1220" "graph TD\nA --> B"`
- `moon run cmd/main -- --transparent "graph TD\nA --> B"`
- `moon run cmd/main -- --list-themes`
