///|
fn snapshot_public_api_svg(
  it : @test.Test,
  filename : String,
  svg : String,
) -> Unit raise {
  it.write(svg)
  it.snapshot(filename~)
}

///|
fn simple_graph_ab() -> String {
  (
    #|graph TD
    #|A --> B
  )
}

///|
test "Public API smoke test" (it : @test.Test) {
  let svg = @beautiful_mermaid.render_mermaid(simple_graph_ab())
  snapshot_public_api_svg(it, "public_api_smoke.svg", svg)
  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("</svg>"))

  let ascii = @beautiful_mermaid.render_mermaid_ascii(simple_graph_ab(), options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(ascii.contains("+---+"))
  assert_true(ascii.contains("| A |"))
  assert_true(ascii.contains("| B |"))
}

///|
test "default_colors matches DiagramColors default" {
  assert_eq(
    @beautiful_mermaid.default_colors(),
    @beautiful_mermaid.DiagramColors::default(),
  )
}

///|
test "render_mermaid_with_colors applies theme colors by default" (
  it : @test.Test,
) {
  let colors = match @themes.theme_by_name("tokyo-night") {
    Some(found) => found
    None => fail("missing tokyo-night theme")
  }
  let svg = @beautiful_mermaid.render_mermaid_with_colors(
    simple_graph_ab(),
    colors,
  )
  snapshot_public_api_svg(it, "public_api_with_colors_default.svg", svg)

  assert_true(svg.contains("--bg:#1a1b26"))
  assert_true(svg.contains("--fg:#a9b1d6"))
  assert_true(svg.contains("--accent:#7aa2f7"))
}

///|
test "merge_options_with_colors fills missing fields from theme colors" {
  let colors = match @themes.theme_by_name("dracula") {
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
  let colors = match @themes.theme_by_name("dracula") {
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
test "render_mermaid_with_colors keeps explicit option overrides" (
  it : @test.Test,
) {
  let colors = match @themes.theme_by_name("tokyo-night") {
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
  let svg = @beautiful_mermaid.render_mermaid_with_colors(
    simple_graph_ab(),
    colors,
    options~,
  )
  snapshot_public_api_svg(
    it, "public_api_with_colors_override_options.svg", svg,
  )

  assert_true(svg.contains("--bg:#000000"))
  assert_true(svg.contains("--fg:#a9b1d6"))
}

///|
test "render_mermaid_with_theme_name applies built-in theme" (it : @test.Test) {
  let svg = @beautiful_mermaid.render_mermaid_with_theme_name(
    simple_graph_ab(),
    "github-dark",
  )
  snapshot_public_api_svg(it, "public_api_theme_name_github_dark.svg", svg)
  assert_true(svg.contains("--bg:#0d1117"))
  assert_true(svg.contains("--accent:#4493f8"))
}

///|
test "render_mermaid_with_theme_name normalizes user theme input" (
  it : @test.Test,
) {
  let svg = @beautiful_mermaid.render_mermaid_with_theme_name(
    simple_graph_ab(),
    "TOKYO   NIGHT",
  )
  snapshot_public_api_svg(
    it, "public_api_theme_name_normalized_tokyo_night.svg", svg,
  )
  assert_true(svg.contains("--bg:#1a1b26"))
  assert_true(svg.contains("--accent:#7aa2f7"))
}

///|
test "render_mermaid_with_theme_name accepts default alias" (it : @test.Test) {
  let svg = @beautiful_mermaid.render_mermaid_with_theme_name(
    simple_graph_ab(),
    "default",
  )
  snapshot_public_api_svg(it, "public_api_theme_name_default_alias.svg", svg)
  assert_true(svg.contains("--bg:#FFFFFF"))
  assert_true(svg.contains("--fg:#27272A"))
}

///|
test "render_mermaid_with_theme applies enum theme directly" (it : @test.Test) {
  let theme = match @themes.parse_theme_name("tokyo-night") {
    Some(found) => found
    None => fail("failed to parse tokyo-night theme")
  }
  let svg = @beautiful_mermaid.render_mermaid_with_theme(
    simple_graph_ab(),
    theme,
  )
  snapshot_public_api_svg(it, "public_api_theme_enum_tokyo_night.svg", svg)
  assert_true(svg.contains("--bg:#1a1b26"))
  assert_true(svg.contains("--line:#3d59a1"))
  assert_true(svg.contains("--accent:#7aa2f7"))
}

///|
test "render_mermaid_with_theme_name rejects unknown theme" {
  let rendered = try? @beautiful_mermaid.render_mermaid_with_theme_name(
    simple_graph_ab(),
    "moonbit-neon",
  )
  match rendered {
    Ok(_) => fail("expected unknown theme to fail")
    Err(err) =>
      match err {
        UnknownTheme(name) => assert_eq(name, "moonbit-neon")
        _ => fail("expected UnknownTheme error")
      }
  }
}

///|
test "render_mermaid_with_theme_name unknown error keeps original input" {
  let rendered = try? @beautiful_mermaid.render_mermaid_with_theme_name(
    simple_graph_ab(),
    "  moonbit   neon  ",
  )
  match rendered {
    Ok(_) => fail("expected unknown theme to fail")
    Err(err) =>
      match err {
        UnknownTheme(name) => assert_eq(name, "  moonbit   neon  ")
        _ => fail("expected UnknownTheme error")
      }
  }
}
