///|
test "Parser parity for all supported corpus cases" {
  for case_data in ts_supported_cases() {
    let graph = @parser_header_core.parse_mermaid(case_data.input)
    guard case_data.direction is Some(direction) else {
      fail("supported case missing direction: \{case_data.name}")
    }
    if direction_name(graph.direction) != direction {
      fail(
        "direction mismatch for \{case_data.name}: got \{direction_name(graph.direction)}, expected \{direction}",
      )
    }

    guard case_data.expected_node_count is Some(expected_nodes) else {
      fail("supported case missing expected node count: \{case_data.name}")
    }
    if graph.nodes.length() != expected_nodes {
      fail(
        "node count mismatch for \{case_data.name}: got \{graph.nodes.length()}, expected \{expected_nodes}",
      )
    }

    guard case_data.expected_edge_count is Some(expected_edges) else {
      fail("supported case missing expected edge count: \{case_data.name}")
    }
    if graph.edges.length() != expected_edges {
      fail(
        "edge count mismatch for \{case_data.name}: got \{graph.edges.length()}, expected \{expected_edges}",
      )
    }
  }
}
