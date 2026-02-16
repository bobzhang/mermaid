///|
fn simple_graph_ab_wb() -> String {
  (
    #|graph TD
    #|A --> B
  )
}

///|
test "render_mermaid_with_colors applies theme colors by default" {
  let colors = match @themes.theme_by_name("tokyo-night") {
    Some(found) => found
    None => fail("missing tokyo-night theme")
  }
  let svg = render_mermaid_with_colors(simple_graph_ab_wb(), colors)

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
  let merged = merge_options_with_colors(RenderOptions::default(), colors)

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
  let base = RenderOptions::{
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
    layout_engine: None,
  }
  let merged = merge_options_with_colors(base, colors)

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
  let colors = match @themes.theme_by_name("tokyo-night") {
    Some(found) => found
    None => fail("missing tokyo-night theme")
  }
  let options = RenderOptions::{
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
    layout_engine: None,
  }
  let svg = render_mermaid_with_colors(simple_graph_ab_wb(), colors, options~)

  assert_true(svg.contains("--bg:#000000"))
  assert_true(svg.contains("--fg:#a9b1d6"))
}
