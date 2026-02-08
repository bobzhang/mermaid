///|
test "Parser parity gate cases" {
  for case_data in @test_support.gate_cases() {
    let graph = try! @beautiful_mermaid.parse_mermaid(case_data.input)
    assert_eq(graph.direction.to_string(), case_data.direction)
    assert_eq(graph.nodes.length(), case_data.expected_node_count)
    assert_eq(graph.edges.length(), case_data.expected_edge_count)
  }
}

///|
test "Parser rejects unsupported header" {
  let result : Result[
    @beautiful_mermaid.MermaidGraph,
    @beautiful_mermaid.MermaidError,
  ] = try? @beautiful_mermaid.parse_mermaid("pie\nA : 1")
  assert_true(result is Err(_))
}

///|
test "Parser rejects flowchart header without direction" {
  let result : Result[
    @beautiful_mermaid.MermaidGraph,
    @beautiful_mermaid.MermaidError,
  ] = try? @beautiful_mermaid.parse_mermaid("graph\nA --> B")
  assert_true(result is Err(_))
}

///|
test "Parser rejects flowchart header with invalid direction token" {
  let result : Result[
    @beautiful_mermaid.MermaidGraph,
    @beautiful_mermaid.MermaidError,
  ] = try? @beautiful_mermaid.parse_mermaid("graph XX\nA --> B")
  assert_true(result is Err(_))
}

///|
test "Parser keeps first node definition for shape and label" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "graph TD\nA[Start]\nA{Decision}\nA --> B",
  )
  match graph.nodes.get("A") {
    Some(node) => {
      assert_eq(node.label, "Start")
      assert_eq(node.shape.to_string(), "Rectangle")
    }
    None => fail("missing node A")
  }
}

///|
test "Parser supports hyphenated node IDs" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "graph TD\nstart-node --> end-node",
  )

  assert_true(graph.nodes.get("start-node") is Some(_))
  assert_true(graph.nodes.get("end-node") is Some(_))
  assert_eq(graph.edges.length(), 1)
  assert_eq(graph.edges[0].source, "start-node")
  assert_eq(graph.edges[0].target, "end-node")
}

///|
test "Parser accepts case-insensitive flowchart header keywords" {
  let graph = try! @beautiful_mermaid.parse_mermaid("Graph td\nA --> B")
  assert_eq(graph.direction.to_string(), "TD")
  assert_eq(graph.edges.length(), 1)

  let flowchart = try! @beautiful_mermaid.parse_mermaid("FLOWCHART lr\nX --> Y")
  assert_eq(flowchart.direction.to_string(), "LR")
  assert_eq(flowchart.edges.length(), 1)
}

///|
test "Parser accepts tab-separated flowchart header tokens" {
  let graph = try! @beautiful_mermaid.parse_mermaid("graph\tTD\nA --> B")
  assert_eq(graph.direction.to_string(), "TD")
  assert_eq(graph.edges.length(), 1)
}

///|
test "Parser preserves node definition order in map iteration" {
  let graph = try! @beautiful_mermaid.parse_mermaid("graph TD\nC\nA\nB")
  let ids = graph.nodes.to_array().map(entry => entry.0)

  assert_eq(ids.length(), 3)
  assert_eq(ids[0], "C")
  assert_eq(ids[1], "A")
  assert_eq(ids[2], "B")
}

///|
test "Parser parses no-arrow edge with label" {
  let graph = try! @beautiful_mermaid.parse_mermaid("graph TD\nA ---|text| B")
  assert_eq(graph.edges.length(), 1)
  let edge = graph.edges[0]
  assert_eq(edge.source, "A")
  assert_eq(edge.target, "B")
  assert_eq(edge.label, Some("text"))
  assert_eq(edge.style.to_string(), "Solid")
  assert_true(!edge.has_arrow_start)
  assert_true(!edge.has_arrow_end)
}

///|
test "Parser parses dotted bidirectional edge operator" {
  let graph = try! @beautiful_mermaid.parse_mermaid("graph TD\nA <-.-> B")
  assert_eq(graph.edges.length(), 1)
  let edge = graph.edges[0]
  assert_eq(edge.style.to_string(), "Dotted")
  assert_true(edge.has_arrow_start)
  assert_true(edge.has_arrow_end)
}

///|
test "Parser handles extra whitespace and empty lines" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "  graph   TD  \n\n  A   -->   B  \n\n  B -->   C  ",
  )
  assert_eq(graph.direction.to_string(), "TD")
  assert_eq(graph.nodes.length(), 3)
  assert_eq(graph.edges.length(), 2)
}

///|
test "Parser handles diagram with only standalone nodes" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "graph TD\nA\nB[Beta]\nC{Choice}",
  )
  assert_eq(graph.edges.length(), 0)
  assert_true(graph.nodes.get("A") is Some(_))
  assert_true(graph.nodes.get("B") is Some(_))
  assert_true(graph.nodes.get("C") is Some(_))
}

///|
test "Parser rejects flowchart header with extra trailing tokens" {
  let result : Result[
    @beautiful_mermaid.MermaidGraph,
    @beautiful_mermaid.MermaidError,
  ] = try? @beautiful_mermaid.parse_mermaid("graph TD extra\nA --> B")
  assert_true(result is Err(_))
}

///|
test "Parser ignores comment lines including indented comments" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "graph TD\n%% comment\n  %% another comment\nA --> B",
  )
  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.edges.length(), 1)
  assert_eq(graph.edges[0].source, "A")
  assert_eq(graph.edges[0].target, "B")
}

///|
test "Parser rejects stateDiagram header with extra trailing tokens" {
  let result : Result[
    @beautiful_mermaid.MermaidGraph,
    @beautiful_mermaid.MermaidError,
  ] = try? @beautiful_mermaid.parse_mermaid("stateDiagram-v2 extra\nA --> B")
  assert_true(result is Err(_))
}

///|
test "Full corpus inventory is imported" {
  let all = @test_support.corpus_cases()
  assert_eq(all.length(), 60)
  let supported = all.filter(case_data => case_data.supported_by_moonbit)
  assert_eq(supported.length(), 60)
}
