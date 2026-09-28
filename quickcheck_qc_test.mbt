// ---------------------------------------------------------------------------
// Regression tests for counterexamples found by the properties above.
// ---------------------------------------------------------------------------

///|
test "regression: control characters in labels keep the SVG well-formed" {
  // Found by the token-soup property: a NUL in a label was copied verbatim
  // into the SVG, which no XML parser accepts.
  let svg = @beautiful_mermaid.render_mermaid(
    "graph TD\nA[x\u{0}y\u{1}z] --> B",
  )
  assert_false(svg.contains("\u{0}"))
  assert_false(svg.contains("\u{1}"))
  assert_true(svg.contains(">x\u{FFFD}y\u{FFFD}z</text>"))
}

///|
test "regression: color options are escaped in the root style attribute" {
  let svg = @beautiful_mermaid.render_mermaid("graph TD\nA --> B", options={
    ..@model.RenderOptions::default(),
    bg: Some("red\" onload=\"alert(1)"),
    line: Some("<&>"),
  })
  assert_false(svg.contains("onload=\"alert"))
  assert_true(svg.contains("--bg:red&quot; onload=&quot;alert(1)"))
  assert_true(svg.contains("--line:&lt;&amp;&gt;"))
}

///|
test "regression: an apostrophe in a node label does not hide the edge" {
  let g = @parser_header_core.parse_mermaid("graph TD\nA[it's] --> B")
  assert_eq(g.node_definition_order, ["A", "B"])
  assert_eq(g.nodes["A"].label, "it's")
  assert_eq(g.edges.length(), 1)
  assert_eq(g.edges[0].source, "A")
  assert_eq(g.edges[0].target, "B")
  let mid = @parser_header_core.parse_mermaid("graph TD\nA -- it's --> B")
  assert_eq(mid.edges.length(), 1)
  assert_eq(mid.edges[0].label, Some("it's"))
}

///|
test "regression: '>' inside a bracketed label is not an asymmetric shape" {
  let g = @parser_header_core.parse_mermaid(
    "graph TD\nA[x>y] --> B\nC[a-->b] --> D\nE>asym]",
  )
  assert_eq(g.node_definition_order, ["A", "B", "C", "D", "E"])
  assert_eq(g.nodes["A"].label, "x>y")
  assert_eq(node_shape_name(g.nodes["A"].shape), "Rectangle")
  assert_eq(g.nodes["C"].label, "a-->b")
  assert_eq(node_shape_name(g.nodes["C"].shape), "Rectangle")
  assert_eq(node_shape_name(g.nodes["E"].shape), "Asymmetric")
  assert_eq(g.nodes["E"].label, "asym")
}
