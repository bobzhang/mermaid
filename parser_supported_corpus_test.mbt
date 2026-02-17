///|
test "Parser parity for all supported corpus cases" {
  for case_data in ts_supported_cases() {
    let graph = @parser_header_core.parse_mermaid(case_data.input)
    match case_data.direction {
      Some(direction) =>
        if direction_name(graph.direction) != direction {
          fail(
            "direction mismatch for \{case_data.name}: got \{direction_name(graph.direction)}, expected \{direction}",
          )
        }
      None => fail("supported case missing direction: \{case_data.name}")
    }

    match case_data.expected_node_count {
      Some(expected_nodes) =>
        if graph.nodes.length() != expected_nodes {
          fail(
            "node count mismatch for \{case_data.name}: got \{graph.nodes.length()}, expected \{expected_nodes}",
          )
        }
      None =>
        fail("supported case missing expected node count: \{case_data.name}")
    }

    match case_data.expected_edge_count {
      Some(expected_edges) =>
        if graph.edges.length() != expected_edges {
          fail(
            "edge count mismatch for \{case_data.name}: got \{graph.edges.length()}, expected \{expected_edges}",
          )
        }
      None =>
        fail("supported case missing expected edge count: \{case_data.name}")
    }
  }
}
