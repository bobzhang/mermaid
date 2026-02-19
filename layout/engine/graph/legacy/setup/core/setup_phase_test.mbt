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
  let setup_state = build_legacy_layout_setup(
    graph,
    @model.RenderOptions::default(),
    true,
    false,
  )

  assert_eq(setup_state.padding, 40)
  assert_eq(setup_state.node_spacing, 130)
  assert_eq(setup_state.layer_spacing, 90)
  assert_eq(setup_state.horizontal, true)
  assert_eq(setup_state.reverse, false)
  assert_eq(setup_state.state_graph, false)
  assert_eq(setup_state.nodes_in_order.length(), 2)
  assert_eq(setup_state.lane_state.flow_max_rank, 1)
}

///|
test "legacy setup enables dagre simplex only when dagre-parity is selected" {
  let graph = test_graph(
    LR,
    [
      test_node("A"),
      test_node("B"),
      test_node("C"),
      test_node("D"),
      test_node("E"),
      test_node("F"),
    ],
    [
      test_edge("A", "B"),
      test_edge("A", "E"),
      test_edge("A", "F"),
      test_edge("B", "D"),
      test_edge("C", "D"),
    ],
  )
  let legacy_setup = build_legacy_layout_setup(
    graph,
    @model.RenderOptions::default(),
    true,
    false,
  )
  let dagre_setup = build_legacy_layout_setup(
    graph,
    { ..@model.RenderOptions::default(), layout_engine: Some(DagreParity) },
    true,
    false,
  )

  assert_eq(
    @layout_engine_graph_internal_core.option_int_or(
      legacy_setup.lane_state.flow_rank_by_node_id.get("C"),
      -1,
    ),
    0,
  )
  assert_eq(
    @layout_engine_graph_internal_core.option_int_or(
      dagre_setup.lane_state.flow_rank_by_node_id.get("C"),
      -1,
    ),
    2,
  )
}
