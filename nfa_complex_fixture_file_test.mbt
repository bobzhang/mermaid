///|
#cfg(target="native")
async fn nfa_fixture_source(name : String) -> String {
  @fs.read_file("fixtures/\{name}.mmd").text()
}

///|
fn nfa_ascii_options() -> @beautiful_mermaid.AsciiRenderOptions {
  { use_ascii: true, padding_x: 5, padding_y: 5, box_border_padding: 1 }
}

///|
fn assert_has_edge(
  graph : @beautiful_mermaid.MermaidGraph,
  source : String,
  target : String,
  label : String?,
) -> Unit raise {
  let found = graph.edges.any(edge => {
    edge.source == source && edge.target == target && edge.label == label
  })
  assert_true(found)
}

///|
#cfg(target="native")
async test "NFA fixture 004 parses and renders expected structure" {
  let source = nfa_fixture_source("nfa_004")
  let graph = @parser_header_core.parse_mermaid(source)

  assert_eq(graph.direction.to_string(), "LR")
  assert_eq(graph.nodes.length(), 8)
  assert_eq(graph.edges.length(), 10)

  match graph.nodes.get("s") {
    Some(node) => assert_eq(node.shape.to_string(), "StateStart")
    None => fail("missing start node s")
  }
  match graph.nodes.get("q0") {
    Some(node) => assert_eq(node.shape.to_string(), "Circle")
    None => fail("missing node q0")
  }
  match graph.nodes.get("a0") {
    Some(node) => assert_eq(node.shape.to_string(), "DoubleCircle")
    None => fail("missing accepting node a0")
  }

  assert_has_edge(graph, "q1", "q2", Some("a"))
  assert_has_edge(graph, "q2", "q2", Some("b"))
  assert_has_edge(graph, "q2", "a0", None)

  let ascii = @beautiful_mermaid.render_mermaid_ascii(
    source,
    options=nfa_ascii_options(),
  )
  let svg = @beautiful_mermaid.render_mermaid(source)
  assert_true(ascii.contains("q0"))
  assert_true(svg.has_prefix("<svg "))
  assert_true(svg.contains("a0"))
}

///|
#cfg(target="native")
async test "NFA fixture 005 parses and renders expected structure" {
  let source = nfa_fixture_source("nfa_005")
  let graph = @parser_header_core.parse_mermaid(source)

  assert_eq(graph.direction.to_string(), "LR")
  assert_eq(graph.nodes.length(), 8)
  assert_eq(graph.edges.length(), 11)

  match graph.nodes.get("start") {
    Some(node) => assert_eq(node.shape.to_string(), "StateStart")
    None => fail("missing start node")
  }
  match graph.nodes.get("i5") {
    Some(node) => assert_eq(node.shape.to_string(), "Circle")
    None => fail("missing node i5")
  }
  match graph.nodes.get("acc") {
    Some(node) => assert_eq(node.shape.to_string(), "DoubleCircle")
    None => fail("missing accepting node")
  }

  assert_has_edge(graph, "i2", "i5", Some("z"))
  assert_has_edge(graph, "i4", "i5", Some("z"))
  assert_has_edge(graph, "i5", "i5", Some("0-9"))
  assert_has_edge(graph, "i5", "acc", None)

  let ascii = @beautiful_mermaid.render_mermaid_ascii(
    source,
    options=nfa_ascii_options(),
  )
  let svg = @beautiful_mermaid.render_mermaid(source)
  assert_true(ascii.contains("i5"))
  assert_true(svg.has_prefix("<svg "))
  assert_true(svg.contains("acc"))
}
