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

///|
test "regression: astral characters survive ASCII rendering" {
  // Emoji were split into lone surrogates, dropped, and shortened the row.
  let out = @beautiful_mermaid.render_mermaid_ascii(
    "graph LR\nA[🚀 go] --> B[𝒳]",
  )
  assert_true(out.contains("🚀 go"))
  assert_true(out.contains("𝒳"))
  let widths = out.split("\n").map(line => line.length()).to_array()
  assert_true(widths.all(w => w == widths[0]))
  // Two edge labels drawn over each other must not leave half an emoji.
  let er = @beautiful_mermaid.render_mermaid_ascii(
    "erDiagram\nENT0 ||--o{ ENT1 : ><7🚀 *7\nENT0 |o--|| ENT1 : 🚀?",
  )
  let er_widths = er.split("\n").map(line => line.length()).to_array()
  assert_true(er_widths.all(w => w == er_widths[0]))
}

///|
fn regression_assert_no_overlap(source : String) -> Unit raise {
  let p = @layout.layout_graph(
    @parser_header_core.parse_mermaid(source),
    @model.RenderOptions::default(),
  )
  for i in 0..<p.nodes.length() {
    for j in (i + 1)..<p.nodes.length() {
      let a = p.nodes[i]
      let b = p.nodes[j]
      if (a.x - b.x).abs() * 2 < a.width + b.width &&
        (a.y - b.y).abs() * 2 < a.height + b.height {
        fail("\{a.id} overlaps \{b.id} in:\n\{source}")
      }
    }
  }
}

///|
test "regression: nodes of one rank do not overlap" {
  // LR: a dotted edge put A and C one 30px lane apart (boxes are 44px tall).
  regression_assert_no_overlap("flowchart LR\nA --> B\nC -.-> B")
  regression_assert_no_overlap("flowchart LR\nA\nB\nC\nD\nC -.-> B\nD <-.-> C")
  // TD: labels wider than the 130px lane step.
  regression_assert_no_overlap(
    "flowchart TD\nA --> B[a very long label for node B here]\nA --> C[another very long label for node C]",
  )
  // Upstream "Decision Tree" sample: D and E overlapped by 6px.
  regression_assert_no_overlap(
    (
      #|graph TD
      #|  A{Is it raining?} -->|Yes| B{Have umbrella?}
      #|  A -->|No| C([Go outside])
      #|  B -->|Yes| D([Go with umbrella])
      #|  B -->|No| E{Is it heavy?}
      #|  E -->|Yes| F([Stay inside])
      #|  E -->|No| G([Run for it])
    ),
  )
}
