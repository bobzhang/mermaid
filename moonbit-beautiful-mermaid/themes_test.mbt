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
