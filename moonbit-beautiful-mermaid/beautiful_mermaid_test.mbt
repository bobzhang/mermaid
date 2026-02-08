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
