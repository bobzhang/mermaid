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
test "lane graph_has_cycle detects cycles and ignores simple chains" {
  let nodes = [test_node("A"), test_node("B"), test_node("C")]
  let cyclic_edges = [
    test_edge("A", "B"),
    test_edge("B", "C"),
    test_edge("C", "A"),
  ]
  let acyclic_edges = [test_edge("A", "B"), test_edge("B", "C")]

  assert_true(graph_has_cycle(nodes, cyclic_edges))
  assert_true(!graph_has_cycle(nodes, acyclic_edges))
}

///|
test "lane rank and lane assignment are stable on simple DAG" {
  let nodes = [test_node("A"), test_node("B"), test_node("C")]
  let edges = [test_edge("A", "B"), test_edge("A", "C"), test_edge("B", "C")]
  let (ranks, max_rank) = collect_non_state_flow_ranks(
    nodes, edges, false, false, false, false, false, false, false,
  )
  assert_eq(max_rank, 2)
  assert_eq(ranks.get("A"), Some(0))
  assert_eq(ranks.get("B"), Some(1))
  assert_eq(ranks.get("C"), Some(2))

  let lanes = collect_non_state_flow_lanes(
    nodes, ranks, max_rank, edges, false, false, true,
  )
  assert_eq(lanes.get("A"), Some(0))
  assert_eq(lanes.get("B"), Some(0))
  assert_eq(lanes.get("C"), Some(0))
}

///|
test "lane compute_legacy_lane_state returns expected flow rank envelope" {
  let nodes = [test_node("A"), test_node("B"), test_node("C")]
  let graph = test_graph(LR, nodes, [test_edge("A", "B"), test_edge("B", "C")])

  let state = compute_legacy_lane_state(
    graph, nodes, false, false, true, false, false, false,
  )
  assert_eq(state.flow_max_rank, 2)
  assert_eq(state.flow_rank_by_node_id.get("A"), Some(0))
  assert_eq(state.flow_rank_by_node_id.get("B"), Some(1))
  assert_eq(state.flow_rank_by_node_id.get("C"), Some(2))
}
