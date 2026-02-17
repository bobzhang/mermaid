///|
fn github_newline_dark() -> String {
  (
    #|github
    #| dark
    #|
  )
  .trim_end()
  .to_string()
}

///|
fn built_in_theme_slugs_wb() -> Array[String] {
  [
    "zinc-light", "zinc-dark", "tokyo-night", "tokyo-night-storm", "tokyo-night-light",
    "catppuccin-mocha", "catppuccin-latte", "nord", "nord-light", "dracula", "github-light",
    "github-dark", "solarized-light", "solarized-dark", "one-dark",
  ]
}

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
test "Theme parser is case-insensitive and unknown-safe" {
  assert_eq(normalize_theme_name("  TOKYO___NIGHT  "), "tokyo-night")
  assert_eq(normalize_theme_name(github_newline_dark()), "github-dark")
  assert_eq(normalize_theme_name("DEFAULT"), "default")
  assert_eq(normalize_theme_name("__github_dark__"), "github-dark")
  assert_eq(normalize_theme_name("---tokyo-night---"), "tokyo-night")

  assert_true(parse_theme_name("TOKYO-NIGHT") is Some(_))
  assert_true(parse_theme_name("__github_dark__") is Some(_))
  assert_true(parse_theme_name("DEFAULT") is Some(_))
  assert_true(parse_theme_name("TOKYO NIGHT") is Some(_))
  assert_true(parse_theme_name("github_dark") is Some(_))
  assert_true(parse_theme_name("TOKYO   NIGHT") is Some(_))
  assert_true(parse_theme_name("github__dark") is Some(_))
  assert_true(parse_theme_name("tokyo\t night") is Some(_))
  assert_true(parse_theme_name(github_newline_dark()) is Some(_))
  assert_true(parse_theme_name("not-a-theme") is None)
  let default_theme = match theme_by_name("DEFAULT") {
    Some(found) => found
    None => fail("missing default theme")
  }
  let zinc_light = match theme_by_name("zinc-light") {
    Some(found) => found
    None => fail("missing zinc-light theme")
  }
  assert_eq(default_theme.bg, zinc_light.bg)
  assert_eq(default_theme.fg, zinc_light.fg)
  assert_eq(default_theme.line, zinc_light.line)
  assert_eq(default_theme.accent, zinc_light.accent)
  assert_eq(default_theme.muted, zinc_light.muted)
  assert_eq(default_theme.surface, zinc_light.surface)
  assert_eq(default_theme.border, zinc_light.border)
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
  assert_true(theme_by_name("github-neon") is None)
}

///|
test "theme_by_name indicates whether a theme is supported" {
  assert_true(theme_by_name("tokyo-night") is Some(_))
  assert_true(theme_by_name("TOKYO NIGHT") is Some(_))
  assert_true(theme_by_name("default") is Some(_))
  assert_true(theme_by_name("tokyo\t night") is Some(_))
  assert_true(theme_by_name(github_newline_dark()) is Some(_))
  assert_true(theme_by_name("github-neon") is None)
}

///|
test "theme_by_name resolves aliases and normalized names" {
  assert_true(theme_by_name("TOKYO   NIGHT") is Some(_))
  assert_true(theme_by_name("DEFAULT") is Some(_))
  assert_true(theme_by_name("__github_dark__") is Some(_))
  assert_true(theme_by_name("github__dark") is Some(_))
  assert_true(theme_by_name("tokyo\t night") is Some(_))
  assert_true(theme_by_name(github_newline_dark()) is Some(_))
  assert_true(theme_by_name("one-dark") is Some(_))
  assert_true(theme_by_name("github-neon") is None)
}

///|
test "Built-in theme slugs are exported for CLI and config UX" {
  let slugs = built_in_theme_slugs_wb()
  assert_true(slugs.contains("zinc-light"))
  assert_true(slugs.contains("tokyo-night"))
  assert_true(slugs.contains("github-dark"))
  assert_true(slugs.contains("one-dark"))
  assert_eq(slugs.length(), 15)
  let seen : Map[String, Bool] = {}
  for slug in slugs {
    assert_true(!seen.contains(slug))
    seen[slug] = true
  }
  let csv = built_in_theme_slugs_wb().join(", ")
  assert_true(csv.contains("tokyo-night"))
  assert_true(csv.contains("github-dark"))
}

///|
test "theme_by_name resolves built-in slugs" {
  for slug in built_in_theme_slugs_wb() {
    assert_true(theme_by_name(slug) is Some(_))
  }

  let tokyo_night = match theme_by_name("tokyo-night") {
    Some(found) => found
    None => fail("missing tokyo-night")
  }
  assert_eq(tokyo_night.bg, "#1a1b26")
  assert_eq(tokyo_night.accent, Some("#7aa2f7"))
}
