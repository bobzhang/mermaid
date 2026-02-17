///|
fn diagram_kind_equal(
  actual : @model.DiagramKind,
  expected : @model.DiagramKind,
) -> Bool {
  match (actual, expected) {
    (Flowchart, Flowchart) => true
    (State, State) => true
    (Sequence, Sequence) => true
    (Class, Class) => true
    (Er, Er) => true
    _ => false
  }
}

///|
fn assert_diagram_kind(
  graph : MermaidGraph,
  expected : @model.DiagramKind,
) -> Unit raise {
  assert_true(diagram_kind_equal(graph.diagram_kind, expected))
}

///|
test "parse_mermaid sets Flowchart kind for graph header" {
  let graph = parse_mermaid(
    (
      #|graph LR
      #|A --> B
      #|
    )
    .trim_end()
    .to_string(),
  )
  assert_diagram_kind(graph, Flowchart)
}

///|
test "parse_mermaid sets State kind for stateDiagram-v2 header" {
  let graph = parse_mermaid(
    (
      #|stateDiagram-v2
      #|[*] --> Idle
      #|
    )
    .trim_end()
    .to_string(),
  )
  assert_diagram_kind(graph, State)
}

///|
test "parse_mermaid sets Sequence kind for sequenceDiagram header" {
  let graph = parse_mermaid(
    (
      #|sequenceDiagram
      #|Alice ->> Bob: hello
      #|
    )
    .trim_end()
    .to_string(),
  )
  assert_diagram_kind(graph, Sequence)
}

///|
test "parse_mermaid sets Class kind for classDiagram header" {
  let graph = parse_mermaid(
    (
      #|classDiagram
      #|A --|> B
      #|
    )
    .trim_end()
    .to_string(),
  )
  assert_diagram_kind(graph, Class)
}

///|
test "parse_mermaid sets Er kind for erDiagram header" {
  let graph = parse_mermaid(
    (
      #|erDiagram
      #|A ||--|| B : owns
      #|
    )
    .trim_end()
    .to_string(),
  )
  assert_diagram_kind(graph, Er)
}
