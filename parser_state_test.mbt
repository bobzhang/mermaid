///|
fn assert_state_label(
  graph : @beautiful_mermaid.MermaidGraph,
  node_id : String,
  expected_label : String,
) -> Unit raise {
  match graph.nodes.get(node_id) {
    Some(node) => assert_eq(node.label, expected_label)
    None => fail("missing state node \{node_id}")
  }
}

///|
fn assert_state_shape(
  graph : @beautiful_mermaid.MermaidGraph,
  node_id : String,
  expected_shape : String,
) -> Unit raise {
  match graph.nodes.get(node_id) {
    Some(node) => assert_eq(node.shape.to_string(), expected_shape)
    None => fail("missing state node \{node_id}")
  }
}

///|
test "Parser detects state diagram headers and default direction" {
  let v2 = try! @beautiful_mermaid.parse_mermaid(
    (
      #|stateDiagram-v2
      #|s1 --> s2
    ),
  )
  assert_eq(v2.direction.to_string(), "TD")

  let legacy = try! @beautiful_mermaid.parse_mermaid(
    (
      #|stateDiagram
      #|s1 --> s2
    ),
  )
  assert_eq(legacy.direction.to_string(), "TD")
}

///|
test "Parser parses state transitions and transition labels" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    (
      #|stateDiagram-v2
      #|Idle --> Active
      #|Active --> Done : complete
    ),
  )

  assert_eq(graph.edges.length(), 2)
  assert_eq(graph.edges[0].source, "Idle")
  assert_eq(graph.edges[0].target, "Active")
  assert_eq(graph.edges[0].label, None)
  assert_eq(graph.edges[1].source, "Active")
  assert_eq(graph.edges[1].target, "Done")
  assert_eq(graph.edges[1].label, Some("complete"))
  assert_state_shape(graph, "Idle", "Rounded")
  assert_state_shape(graph, "Active", "Rounded")
  assert_state_shape(graph, "Done", "Rounded")
}

///|
test "Parser parses start and end state pseudostates with unique ids" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    (
      #|stateDiagram-v2
      #|[*] --> A
      #|[*] --> B
      #|A --> [*]
      #|B --> [*]
    ),
  )

  assert_true(graph.nodes.get("state_start_1") is Some(_))
  assert_true(graph.nodes.get("state_start_2") is Some(_))
  assert_true(graph.nodes.get("state_end_1") is Some(_))
  assert_true(graph.nodes.get("state_end_2") is Some(_))

  match graph.nodes.get("state_start_1") {
    Some(node) => assert_eq(node.shape.to_string(), "StateStart")
    None => fail("missing state_start_1")
  }
  match graph.nodes.get("state_end_1") {
    Some(node) => assert_eq(node.shape.to_string(), "StateEnd")
    None => fail("missing state_end_1")
  }
}

///|
test "Parser parses state alias declarations" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    (
      #|stateDiagram-v2
      #|state "Waiting for input" as waiting
      #|waiting --> active
    ),
  )

  assert_state_label(graph, "waiting", "Waiting for input")
  assert_state_shape(graph, "waiting", "Rounded")
  assert_true(graph.nodes.get("active") is Some(_))
  assert_eq(graph.edges.length(), 1)
}

///|
test "Parser applies state direction override" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    (
      #|stateDiagram-v2
      #|direction LR
      #|s1 --> s2
    ),
  )
  assert_eq(graph.direction.to_string(), "LR")
}

///|
test "Parser ignores invalid state direction token" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    (
      #|stateDiagram-v2
      #|direction LR
      #|direction XX
      #|s1 --> s2
    ),
  )
  assert_eq(graph.direction.to_string(), "LR")
}

///|
test "Parser supports state description lines" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    (
      #|stateDiagram-v2
      #|s1 : Idle State
      #|s1 --> s2
    ),
  )

  assert_state_label(graph, "s1", "Idle State")
  assert_state_shape(graph, "s1", "Rounded")
  assert_eq(graph.edges.length(), 1)
  assert_eq(graph.edges[0].source, "s1")
  assert_eq(graph.edges[0].target, "s2")
}

///|
test "Parser captures state composite blocks as subgraphs" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    (
      #|stateDiagram-v2
      #|state Processing {
      #|  parse --> validate
      #|  validate --> execute
      #|}
    ),
  )

  assert_eq(graph.subgraphs.length(), 1)
  let composite = graph.subgraphs[0]
  assert_eq(composite.id, "Processing")
  assert_eq(composite.label, "Processing")
  assert_true(composite.node_ids.any(id => id == "parse"))
  assert_true(composite.node_ids.any(id => id == "validate"))
  assert_true(composite.node_ids.any(id => id == "execute"))
}

///|
test "Parser captures state composite alias blocks as subgraphs" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    (
      #|stateDiagram-v2
      #|state "Active Processing" as AP {
      #|  inner1 --> inner2
      #|}
    ),
  )

  assert_eq(graph.subgraphs.length(), 1)
  let composite = graph.subgraphs[0]
  assert_eq(composite.id, "AP")
  assert_eq(composite.label, "Active Processing")
  assert_true(composite.node_ids.any(id => id == "inner1"))
  assert_true(composite.node_ids.any(id => id == "inner2"))
}

///|
test "Parser captures direction override inside state composite" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    (
      #|stateDiagram-v2
      #|state Processing {
      #|  direction LR
      #|  parse --> validate
      #|}
    ),
  )

  assert_eq(graph.direction.to_string(), "TD")
  assert_eq(graph.subgraphs.length(), 1)
  match graph.subgraphs[0].direction {
    Some(direction) => assert_eq(direction.to_string(), "LR")
    None => fail("expected composite direction override")
  }
}

///|
test "Parser handles state diagrams with composite declaration and outer transitions" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    (
      #|stateDiagram-v2
      #|[*] --> Idle
      #|Idle --> Processing : submit
      #|state Processing {
      #|  parse --> validate
      #|  validate --> execute
      #|}
      #|Processing --> Complete : done
      #|Complete --> [*]
    ),
  )

  assert_true(graph.nodes.get("Idle") is Some(_))
  assert_true(graph.nodes.get("Processing") is Some(_))
  assert_true(graph.nodes.get("Complete") is Some(_))
  assert_true(graph.nodes.get("parse") is Some(_))
  assert_true(graph.nodes.get("validate") is Some(_))
  assert_true(graph.nodes.get("execute") is Some(_))
  assert_true(graph.nodes.get("state_start_1") is Some(_))
  assert_true(graph.nodes.get("state_end_1") is Some(_))
  assert_eq(graph.edges.length(), 6)
  assert_eq(graph.subgraphs.length(), 1)
  assert_eq(graph.subgraphs[0].id, "Processing")
}
