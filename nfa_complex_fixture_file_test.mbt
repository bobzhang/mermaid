///|
fn nfa_ascii_options() -> @model.AsciiRenderOptions {
  { use_ascii: true, padding_x: 5, padding_y: 5, box_border_padding: 1 }
}

///|
fn assert_has_edge(
  graph : @model.MermaidGraph,
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
fn assert_nfa_node_shape(
  graph : @model.MermaidGraph,
  node_id : String,
  expected_shape : String,
) -> Unit raise {
  match graph.nodes.get(node_id) {
    Some(node) => assert_eq(node_shape_name(node.shape), expected_shape)
    None => fail("missing node \{node_id}")
  }
}

///|
fn assert_render_smoke(source : String, token : String) -> Unit raise {
  let ascii = @beautiful_mermaid.render_mermaid_ascii(
    source,
    options=nfa_ascii_options(),
  )
  let svg = @beautiful_mermaid.render_mermaid(source)
  assert_true(ascii.contains(token))
  assert_true(svg.has_prefix("<svg "))
  assert_true(svg.contains(token))
}

///|
#cfg(target="native")
async test "NFA fixture 004 parses and renders expected structure" {
  let source = @fs.read_file("fixtures/nfa_004.mmd").text()
  let graph = @parser_header_core.parse_mermaid(source)

  assert_eq(direction_name(graph.direction), "LR")
  assert_eq(graph.nodes.length(), 8)
  assert_eq(graph.edges.length(), 10)

  assert_nfa_node_shape(graph, "s", "StateStart")
  assert_nfa_node_shape(graph, "q0", "Circle")
  assert_nfa_node_shape(graph, "a0", "DoubleCircle")

  assert_has_edge(graph, "q1", "q2", Some("a"))
  assert_has_edge(graph, "q2", "q2", Some("b"))
  assert_has_edge(graph, "q2", "a0", None)
  assert_render_smoke(source, "a0")
}

///|
#cfg(target="native")
async test "NFA fixture 005 parses and renders expected structure" {
  let source = @fs.read_file("fixtures/nfa_005.mmd").text()
  let graph = @parser_header_core.parse_mermaid(source)

  assert_eq(direction_name(graph.direction), "LR")
  assert_eq(graph.nodes.length(), 8)
  assert_eq(graph.edges.length(), 11)

  assert_nfa_node_shape(graph, "start", "StateStart")
  assert_nfa_node_shape(graph, "i5", "Circle")
  assert_nfa_node_shape(graph, "acc", "DoubleCircle")

  assert_has_edge(graph, "i2", "i5", Some("z"))
  assert_has_edge(graph, "i4", "i5", Some("z"))
  assert_has_edge(graph, "i5", "i5", Some("0-9"))
  assert_has_edge(graph, "i5", "acc", None)
  assert_render_smoke(source, "acc")
}

///|
#cfg(target="native")
async test "NFA fixture 006 parses branch-loop-merge topology" {
  let source = @fs.read_file("fixtures/nfa_006.mmd").text()
  let graph = @parser_header_core.parse_mermaid(source)

  assert_eq(direction_name(graph.direction), "LR")
  assert_eq(graph.nodes.length(), 9)
  assert_eq(graph.edges.length(), 10)

  assert_nfa_node_shape(graph, "s", "StateStart")
  assert_nfa_node_shape(graph, "p0", "Circle")
  assert_nfa_node_shape(graph, "f", "DoubleCircle")

  assert_has_edge(graph, "p1", "p2", Some("a"))
  assert_has_edge(graph, "p2", "p3", Some("b"))
  assert_has_edge(graph, "p5", "p6", Some("c"))
  assert_has_edge(graph, "p7", "f", Some("d"))
  assert_has_edge(graph, "p6", "p0", None)
  assert_has_edge(graph, "p6", "p7", None)
  assert_render_smoke(source, "p7")
}

///|
#cfg(target="native")
async test "NFA fixture 007 parses parallel-source labels and epsilon exits" {
  let source = @fs.read_file("fixtures/nfa_007.mmd").text()
  let graph = @parser_header_core.parse_mermaid(source)

  assert_eq(direction_name(graph.direction), "LR")
  assert_eq(graph.nodes.length(), 10)
  assert_eq(graph.edges.length(), 12)

  assert_nfa_node_shape(graph, "start", "StateStart")
  assert_nfa_node_shape(graph, "n5", "Circle")
  assert_nfa_node_shape(graph, "acc0", "DoubleCircle")
  assert_nfa_node_shape(graph, "acc1", "DoubleCircle")

  assert_has_edge(graph, "n2", "n5", Some("y"))
  assert_has_edge(graph, "n4", "n5", Some("y"))
  assert_has_edge(graph, "n5", "n5", Some("w"))
  assert_has_edge(graph, "n5", "n6", Some("z"))
  assert_has_edge(graph, "n6", "acc0", None)
  assert_has_edge(graph, "n6", "acc1", None)
  assert_render_smoke(source, "acc1")
}

///|
#cfg(target="native")
async test "NFA fixture 008 parses dual branches with synchronized join" {
  let source = @fs.read_file("fixtures/nfa_008.mmd").text()
  let graph = @parser_header_core.parse_mermaid(source)

  assert_eq(direction_name(graph.direction), "LR")
  assert_eq(graph.nodes.length(), 11)
  assert_eq(graph.edges.length(), 14)

  assert_nfa_node_shape(graph, "start", "StateStart")
  assert_nfa_node_shape(graph, "q7", "Circle")
  assert_nfa_node_shape(graph, "acc0", "DoubleCircle")
  assert_nfa_node_shape(graph, "acc1", "DoubleCircle")

  assert_has_edge(graph, "q1", "q2", Some("a"))
  assert_has_edge(graph, "q2", "q3", Some("b"))
  assert_has_edge(graph, "q4", "q5", Some("a"))
  assert_has_edge(graph, "q5", "q6", Some("c"))
  assert_has_edge(graph, "q2", "q7", Some("x"))
  assert_has_edge(graph, "q5", "q7", Some("x"))
  assert_has_edge(graph, "q7", "acc0", Some("d"))
  assert_has_edge(graph, "q7", "acc1", Some("e"))
  assert_has_edge(graph, "q6", "q0", None)
  assert_render_smoke(source, "acc1")
}

///|
#cfg(target="native")
async test "NFA fixture 009 parses multi-accept converging machine" {
  let source = @fs.read_file("fixtures/nfa_009.mmd").text()
  let graph = @parser_header_core.parse_mermaid(source)

  assert_eq(direction_name(graph.direction), "LR")
  assert_eq(graph.nodes.length(), 13)
  assert_eq(graph.edges.length(), 17)

  assert_nfa_node_shape(graph, "s", "StateStart")
  assert_nfa_node_shape(graph, "n7", "Circle")
  assert_nfa_node_shape(graph, "f0", "DoubleCircle")
  assert_nfa_node_shape(graph, "f1", "DoubleCircle")
  assert_nfa_node_shape(graph, "f2", "DoubleCircle")

  assert_has_edge(graph, "n1", "n2", Some("0"))
  assert_has_edge(graph, "n2", "n3", Some("1"))
  assert_has_edge(graph, "n4", "n5", Some("1"))
  assert_has_edge(graph, "n5", "n6", Some("0"))
  assert_has_edge(graph, "n8", "n7", Some("eps"))
  assert_has_edge(graph, "n7", "n7", Some("0-1"))
  assert_has_edge(graph, "n2", "n8", Some("k"))
  assert_has_edge(graph, "n5", "n8", Some("k"))
  assert_has_edge(graph, "n7", "f0", None)
  assert_has_edge(graph, "n7", "f1", None)
  assert_has_edge(graph, "n3", "f2", None)
  assert_has_edge(graph, "n6", "f2", None)
  assert_render_smoke(source, "f2")
}

///|
#cfg(target="native")
async test "All NFA fixtures parse and render smoke" {
  let fixture_names = [
    "nfa_001", "nfa_002", "nfa_003", "nfa_004", "nfa_005", "nfa_006", "nfa_007",
    "nfa_008", "nfa_009",
  ]
  for name in fixture_names {
    let source = @fs.read_file("fixtures/\{name}.mmd").text()
    if source.trim().to_string() == "" {
      continue
    }
    let graph = @parser_header_core.parse_mermaid(source)
    assert_true(graph.nodes.length() > 0)
    assert_true(graph.edges.length() > 0)
    let ascii = @beautiful_mermaid.render_mermaid_ascii(
      source,
      options=nfa_ascii_options(),
    )
    let svg = @beautiful_mermaid.render_mermaid(source)
    assert_true(ascii.length() > 0)
    assert_true(svg.has_prefix("<svg "))
  }
}
