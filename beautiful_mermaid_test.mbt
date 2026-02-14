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
