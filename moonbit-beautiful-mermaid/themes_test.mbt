///|
test "Theme presets include tokyo-night enrichment colors" {
  let colors = match theme_by_name("tokyo-night") {
    Some(found) => found
    None => fail("missing tokyo-night preset")
  }
  assert_eq(colors.bg, "#1a1b26")
  assert_eq(colors.fg, "#a9b1d6")
  assert_eq(colors.line, Some("#3d59a1"))
  assert_eq(colors.accent, Some("#7aa2f7"))
  assert_eq(colors.muted, Some("#565f89"))
}

///|
test "Theme presets include zinc-dark mono defaults" {
  let colors = match theme_by_name("zinc-dark") {
    Some(found) => found
    None => fail("missing zinc-dark preset")
  }
  assert_eq(colors.bg, "#18181B")
  assert_eq(colors.fg, "#FAFAFA")
  assert_eq(colors.line, None)
  assert_eq(colors.accent, None)
  assert_eq(colors.muted, None)
}

///|
test "Theme presets include zinc-light default colors" {
  let colors = match theme_by_name("zinc-light") {
    Some(found) => found
    None => fail("missing zinc-light preset")
  }
  assert_eq(colors.bg, "#FFFFFF")
  assert_eq(colors.fg, "#27272A")
  assert_eq(colors.line, None)
}

///|
test "Theme slug and parser round-trip" {
  for theme in built_in_themes() {
    let slug = theme_slug(theme)
    match parse_theme_name(slug) {
      Some(parsed) => assert_eq(theme_slug(parsed), slug)
      None => fail("failed to parse theme slug: \{slug}")
    }
  }
}

///|
test "Theme parser is case-insensitive and unknown-safe" {
  match parse_theme_name("TOKYO-NIGHT") {
    Some(parsed) => assert_eq(theme_slug(parsed), "tokyo-night")
    None => fail("TOKYO-NIGHT should parse")
  }
  match parse_theme_name("TOKYO NIGHT") {
    Some(parsed) => assert_eq(theme_slug(parsed), "tokyo-night")
    None => fail("TOKYO NIGHT should parse")
  }
  match parse_theme_name("github_dark") {
    Some(parsed) => assert_eq(theme_slug(parsed), "github-dark")
    None => fail("github_dark should parse")
  }
  assert_eq(parse_theme_name("not-a-theme"), None)
}

///|
test "Theme lookup by name returns colors or none" {
  let github_dark = match theme_by_name("github-dark") {
    Some(found) => found
    None => fail("missing github-dark preset")
  }
  assert_eq(github_dark.bg, "#0d1117")
  assert_eq(github_dark.fg, "#e6edf3")
  assert_eq(github_dark.accent, Some("#4493f8"))
  assert_eq(theme_by_name("github-neon"), None)
}

///|
test "Built-in theme slugs are exported for CLI and config UX" {
  let slugs = built_in_theme_slugs()
  assert_true(slugs.contains("zinc-light"))
  assert_true(slugs.contains("tokyo-night"))
  assert_true(slugs.contains("github-dark"))
  assert_true(slugs.contains("one-dark"))
  assert_eq(slugs.length(), built_in_themes().length())
}

///|
test "from_shiki_theme extracts bg and fg from editor colors" {
  let theme = ShikiTheme::{
    theme_type: Some("dark"),
    colors: Some({
      "editor.background": "#1a1b26",
      "editor.foreground": "#a9b1d6",
    }),
    token_colors: None,
  }
  let colors = from_shiki_theme(theme)
  assert_eq(colors.bg, "#1a1b26")
  assert_eq(colors.fg, "#a9b1d6")
}

///|
test "from_shiki_theme falls back for missing editor colors" {
  let dark = from_shiki_theme(ShikiTheme::{
    theme_type: Some("dark"),
    colors: None,
    token_colors: None,
  })
  assert_eq(dark.bg, "#1e1e1e")
  assert_eq(dark.fg, "#d4d4d4")

  let light = from_shiki_theme(ShikiTheme::{
    theme_type: Some("light"),
    colors: None,
    token_colors: None,
  })
  assert_eq(light.bg, "#ffffff")
  assert_eq(light.fg, "#333333")
}

///|
test "from_shiki_theme maps token and editor colors to enrichment fields" {
  let theme = ShikiTheme::{
    theme_type: Some("dark"),
    colors: Some({
      "editor.background": "#111111",
      "editor.foreground": "#eeeeee",
      "editorLineNumber.foreground": "#666666",
      "editor.selectionBackground": "#222222",
      "editorWidget.border": "#444444",
    }),
    token_colors: Some([
      ShikiTokenColor::{ scopes: ["comment"], foreground: Some("#888888") },
      ShikiTokenColor::{ scopes: ["keyword"], foreground: Some("#ff00ff") },
    ]),
  }
  let colors = from_shiki_theme(theme)
  assert_eq(colors.line, Some("#666666"))
  assert_eq(colors.accent, Some("#ff00ff"))
  assert_eq(colors.muted, Some("#888888"))
  assert_eq(colors.surface, Some("#222222"))
  assert_eq(colors.border, Some("#444444"))
}
