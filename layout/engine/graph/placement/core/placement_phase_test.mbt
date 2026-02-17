///|
fn test_node(id : String) -> @model.MermaidNode {
  { id, label: id, shape: Rectangle }
}

///|
fn test_edge(source : String, target : String) -> @model.MermaidEdge {
  {
    source,
    target,
    label: None,
    style: Solid,
    has_arrow_start: false,
    has_arrow_end: true,
    relation_operator: Some("-->"),
  }
}

///|
fn test_graph(
  direction : @model.Direction,
  nodes_in_order : Array[@model.MermaidNode],
  edges : Array[@model.MermaidEdge],
) -> @model.MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {}
  for node in nodes_in_order {
    nodes[node.id] = node
  }
  {
    diagram_kind: Flowchart,
    direction,
    nodes,
    edges,
    subgraphs: [],
    class_defs: {},
    class_assignments: {},
    node_styles: {},
    sequence_actor_order: [],
    sequence_actor_kinds: {},
    sequence_blocks: [],
    sequence_notes: [],
    sequence_activation_commands: [],
  }
}

///|
fn two_node_rank_map() -> Map[String, Int] {
  { "A": 0, "B": 1 }
}

///|
fn two_node_lane_map() -> Map[String, Int] {
  { "A": 0, "B": 0 }
}

///|
test "placement computes forward horizontal ordering from rank map" {
  let nodes = [test_node("A"), test_node("B")]
  let graph = test_graph(LR, nodes, [test_edge("A", "B")])
  let state = compute_legacy_node_placement_state(
    graph,
    nodes,
    false,
    true,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    {},
    {},
    1,
    two_node_rank_map(),
    two_node_lane_map(),
    {},
    {},
    {},
    40,
    130,
    90,
  )

  let ax = state.positioned_by_id["A"].x
  let bx = state.positioned_by_id["B"].x
  assert_true(bx > ax)
  assert_eq(state.positioned_nodes.length(), 2)
}

///|
test "placement reverse mode flips horizontal rank ordering" {
  let nodes = [test_node("A"), test_node("B")]
  let graph = test_graph(RL, nodes, [test_edge("A", "B")])
  let state = compute_legacy_node_placement_state(
    graph,
    nodes,
    true,
    true,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    false,
    {},
    {},
    1,
    two_node_rank_map(),
    two_node_lane_map(),
    {},
    {},
    {},
    40,
    130,
    90,
  )

  let ax = state.positioned_by_id["A"].x
  let bx = state.positioned_by_id["B"].x
  assert_true(ax > bx)
}
