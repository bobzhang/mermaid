///|
#cfg(target="native")
async fn flow_fixture_source() -> String {
  @fs.read_file("fixtures/flow.mmd").text()
}

///|
#cfg(target="native")
async test "Flow fixture layout snapshot stays stable" (it : @test.Test) {
  let source = flow_fixture_source()
  snapshot_layout_only(it, "layout_flow_fixture.txt", source)
}

///|
#cfg(target="native")
async test "Flow fixture SVG snapshot stays stable" (it : @test.Test) {
  let source = flow_fixture_source()
  let svg = @beautiful_mermaid.render_mermaid(source)
  it.write(svg)
  it.snapshot(filename="flow_fixture_svg.svg")
  assert_true(svg.has_prefix("<svg "))
  assert_true(svg.has_suffix("</svg>"))
}
