///|
test "Public API smoke test" {
  let svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA --> B")
  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("</svg>"))

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(
    "graph TD\nA --> B",
    options={
      use_ascii: true,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(ascii.contains("[A]"))
  assert_true(ascii.contains("[B]"))
}

///|
test "render_mermaid_with_colors applies theme colors by default" {
  let colors = match @beautiful_mermaid.theme_by_name("tokyo-night") {
    Some(found) => found
    None => fail("missing tokyo-night theme")
  }
  let svg = try! @beautiful_mermaid.render_mermaid_with_colors(
    "graph TD\nA --> B",
    colors,
  )

  assert_true(svg.contains("--bg:#1a1b26"))
  assert_true(svg.contains("--fg:#a9b1d6"))
  assert_true(svg.contains("--accent:#7aa2f7"))
}

///|
test "merge_options_with_colors fills missing fields from theme colors" {
  let colors = match @beautiful_mermaid.theme_by_name("dracula") {
    Some(found) => found
    None => fail("missing dracula theme")
  }
  let merged = @beautiful_mermaid.merge_options_with_colors(
    @beautiful_mermaid.RenderOptions::default(),
    colors,
  )

  assert_eq(merged.bg, Some("#282a36"))
  assert_eq(merged.fg, Some("#f8f8f2"))
  assert_eq(merged.line, Some("#6272a4"))
  assert_eq(merged.accent, Some("#bd93f9"))
}

///|
test "merge_options_with_colors preserves explicit overrides" {
  let colors = match @beautiful_mermaid.theme_by_name("dracula") {
    Some(found) => found
    None => fail("missing dracula theme")
  }
  let base = @beautiful_mermaid.RenderOptions::{
    bg: Some("#101010"),
    fg: Some("#f0f0f0"),
    line: Some("#111111"),
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: Some("Inter"),
    padding: Some(8),
    node_spacing: None,
    layer_spacing: None,
    transparent: Some(true),
  }
  let merged = @beautiful_mermaid.merge_options_with_colors(base, colors)

  assert_eq(merged.bg, Some("#101010"))
  assert_eq(merged.fg, Some("#f0f0f0"))
  assert_eq(merged.line, Some("#111111"))
  assert_eq(merged.accent, Some("#bd93f9"))
  assert_eq(merged.font, Some("Inter"))
  assert_eq(merged.padding, Some(8))
  assert_eq(merged.transparent, Some(true))
}

///|
test "render_mermaid_with_colors keeps explicit option overrides" {
  let colors = match @beautiful_mermaid.theme_by_name("tokyo-night") {
    Some(found) => found
    None => fail("missing tokyo-night theme")
  }
  let options = @beautiful_mermaid.RenderOptions::{
    bg: Some("#000000"),
    fg: None,
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: None,
    padding: None,
    node_spacing: None,
    layer_spacing: None,
    transparent: None,
  }
  let svg = try! @beautiful_mermaid.render_mermaid_with_colors(
    "graph TD\nA --> B",
    colors,
    options~,
  )

  assert_true(svg.contains("--bg:#000000"))
  assert_true(svg.contains("--fg:#a9b1d6"))
}

///|
test "render_mermaid_with_theme_name applies built-in theme" {
  let svg = try! @beautiful_mermaid.render_mermaid_with_theme_name(
    "graph TD\nA --> B",
    "github-dark",
  )
  assert_true(svg.contains("--bg:#0d1117"))
  assert_true(svg.contains("--accent:#4493f8"))
}

///|
test "render_mermaid_with_theme applies enum theme directly" {
  let theme = match @beautiful_mermaid.parse_theme_name("tokyo-night") {
    Some(found) => found
    None => fail("failed to parse tokyo-night theme")
  }
  let svg = try! @beautiful_mermaid.render_mermaid_with_theme(
    "graph TD\nA --> B",
    theme,
  )
  assert_true(svg.contains("--bg:#1a1b26"))
  assert_true(svg.contains("--line:#3d59a1"))
  assert_true(svg.contains("--accent:#7aa2f7"))
}

///|
test "render_mermaid_with_theme_name rejects unknown theme" {
  let rendered = try? @beautiful_mermaid.render_mermaid_with_theme_name(
    "graph TD\nA --> B",
    "moonbit-neon",
  )
  match rendered {
    Ok(_) => fail("expected unknown theme to fail")
    Err(err) =>
      match err {
        @beautiful_mermaid.MermaidError::UnknownTheme(name) =>
          assert_eq(name, "moonbit-neon")
        _ => fail("expected UnknownTheme error")
      }
  }
}
