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
test "legacy setup derives flow defaults and lane state for a simple graph" {
  let graph = test_graph(LR, [test_node("A"), test_node("B")], [
    test_edge("A", "B"),
  ])
  let setup_state = build_legacy_layout_setup({
    graph,
    options: @model.RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  })

  assert_eq(setup_state.padding, 40)
  assert_eq(setup_state.node_spacing, 130)
  assert_eq(setup_state.layer_spacing, 90)
  assert_eq(setup_state.horizontal, true)
  assert_eq(setup_state.reverse, false)
  assert_eq(setup_state.state_graph, false)
  assert_eq(setup_state.nodes_in_order.length(), 2)
  assert_eq(setup_state.lane_state.flow_max_rank, 1)
}
