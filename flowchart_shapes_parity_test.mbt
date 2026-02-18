///|
fn assert_node_shape(
  graph : @model.MermaidGraph,
  node_id : String,
  expected : String,
) -> Unit raise {
  guard graph.nodes.get(node_id) is Some(node) else {
    fail("missing node \{node_id}")
  }
  assert_eq(node_shape_name(node.shape), expected)
}

///|
fn all_shapes_diagram() -> String {
  (
    #|graph LR
    #|A[Rectangle] --> B(Rounded)
    #|B --> C{Diamond}
    #|C --> D([Stadium])
    #|D --> E((Circle))
    #|E --> F[[Subroutine]]
    #|F --> G(((DoubleCircle)))
    #|G --> H{{Hexagon}}
    #|H --> I[(Cylinder)]
    #|I --> J>Flag]
    #|J --> K[/Trapezoid\]
    #|K --> L[\TrapAlt/]
  )
}

///|
test "Parser recognizes all flowchart shape syntaxes" {
  let graph = @parser_header_core.parse_mermaid(all_shapes_diagram())

  assert_eq(graph.nodes.length(), 12)
  assert_eq(graph.edges.length(), 11)

  assert_node_shape(graph, "A", "Rectangle")
  assert_node_shape(graph, "B", "Rounded")
  assert_node_shape(graph, "C", "Diamond")
  assert_node_shape(graph, "D", "Stadium")
  assert_node_shape(graph, "E", "Circle")
  assert_node_shape(graph, "F", "Subroutine")
  assert_node_shape(graph, "G", "DoubleCircle")
  assert_node_shape(graph, "H", "Hexagon")
  assert_node_shape(graph, "I", "Cylinder")
  assert_node_shape(graph, "J", "Asymmetric")
  assert_node_shape(graph, "K", "Trapezoid")
  assert_node_shape(graph, "L", "TrapezoidAlt")
}

///|
test "SVG renders all flowchart shape labels in a single diagram" (
  it : @test.Test,
) {
  let svg = @beautiful_mermaid.render_mermaid(all_shapes_diagram())
  it.write(svg)
  it.snapshot(filename="flowchart_shapes_all_labels.svg")

  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("</svg>"))
  assert_true(svg.contains(">Rectangle</text>"))
  assert_true(svg.contains(">Rounded</text>"))
  assert_true(svg.contains(">Diamond</text>"))
  assert_true(svg.contains(">Stadium</text>"))
  assert_true(svg.contains(">Circle</text>"))
  assert_true(svg.contains(">Subroutine</text>"))
  assert_true(svg.contains(">DoubleCircle</text>"))
  assert_true(svg.contains(">Hexagon</text>"))
  assert_true(svg.contains(">Cylinder</text>"))
  assert_true(svg.contains(">Flag</text>"))
  assert_true(svg.contains(">Trapezoid</text>"))
  assert_true(svg.contains(">TrapAlt</text>"))
}
