///|
fn assert_contains_id(ids : Array[String], expected : String) -> Unit raise {
  if !ids.any(id => id == expected) {
    fail("missing node id \{expected} in \{ids.to_string()}")
  }
}

///|
test "Parser parses a basic flowchart subgraph" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|graph TD
      #|subgraph Backend
      #|A --> B
      #|end
    ),
  )

  assert_eq(graph.subgraphs.length(), 1)
  let subgraph = graph.subgraphs[0]
  assert_eq(subgraph.id, "Backend")
  assert_eq(subgraph.label, "Backend")
  assert_contains_id(subgraph.node_ids, "A")
  assert_contains_id(subgraph.node_ids, "B")
  assert_eq(subgraph.children.length(), 0)
}

///|
test "Parser parses subgraph id and label in bracket form" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|graph TD
      #|subgraph us-east [US East Region]
      #|A --> B
      #|end
    ),
  )

  assert_eq(graph.subgraphs.length(), 1)
  let subgraph = graph.subgraphs[0]
  assert_eq(subgraph.id, "us-east")
  assert_eq(subgraph.label, "US East Region")
}

///|
test "Parser keeps nested subgraph nodes scoped to their direct owner" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|graph TD
      #|subgraph Outer
      #|subgraph Inner
      #|A --> B
      #|end
      #|C --> D
      #|end
    ),
  )

  assert_eq(graph.subgraphs.length(), 1)
  let outer = graph.subgraphs[0]
  assert_eq(outer.label, "Outer")
  assert_eq(outer.children.length(), 1)

  let inner = outer.children[0]
  assert_eq(inner.label, "Inner")
  assert_contains_id(inner.node_ids, "A")
  assert_contains_id(inner.node_ids, "B")
  assert_contains_id(outer.node_ids, "C")
  assert_contains_id(outer.node_ids, "D")
  assert_true(!outer.node_ids.any(id => id == "A"))
}

///|
test "Parser keeps subgraph membership at first node definition" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|graph TD
      #|subgraph Clients
      #|A --> B
      #|end
      #|subgraph Services
      #|B --> C
      #|end
    ),
  )

  assert_eq(graph.subgraphs.length(), 2)
  let clients = graph.subgraphs[0]
  let services = graph.subgraphs[1]

  assert_contains_id(clients.node_ids, "A")
  assert_contains_id(clients.node_ids, "B")
  assert_true(!services.node_ids.any(id => id == "B"))
  assert_contains_id(services.node_ids, "C")
}

///|
test "Parser captures direction override inside subgraph only" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|graph TD
      #|subgraph sub1 [Left Right Group]
      #|direction LR
      #|A --> B
      #|end
    ),
  )

  assert_eq(graph.direction.to_string(), "TD")
  assert_eq(graph.subgraphs.length(), 1)
  match graph.subgraphs[0].direction {
    Some(direction) => assert_eq(direction.to_string(), "LR")
    None => fail("expected subgraph direction override")
  }
}

///|
test "Parser ignores root flowchart direction lines after header" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|graph TD
      #|direction LR
      #|A --> B
    ),
  )

  assert_eq(graph.direction.to_string(), "TD")
  assert_eq(graph.subgraphs.length(), 0)
  assert_eq(graph.edges.length(), 1)
}

///|
test "Parser ignores invalid direction override inside subgraph" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|graph LR
      #|subgraph Sub
      #|direction XX
      #|A --> B
      #|end
    ),
  )

  assert_eq(graph.direction.to_string(), "LR")
  assert_eq(graph.subgraphs.length(), 1)
  match graph.subgraphs[0].direction {
    Some(_) => fail("expected invalid direction token to be ignored")
    None => ()
  }
}
