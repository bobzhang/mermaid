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
test "legacy post phase routes edges and finalizes output bounds" {
  let graph = test_graph(LR, [test_node("A"), test_node("B")], [
    test_edge("A", "B"),
  ])
  let setup_state = @layout_engine_graph_legacy_setup_core.build_legacy_layout_setup(
    graph,
    @model.RenderOptions::default(),
    true,
    false,
  )
  let placement_state = @layout_engine_graph_legacy_placement_core.run_legacy_placement_phase(
    graph, setup_state, true, false,
  )
  let positioned = finalize_legacy_layout_from_placement(
    graph, setup_state, placement_state, true, false, false,
  )

  assert_eq(positioned.nodes.length(), 2)
  assert_eq(positioned.edges.length(), 1)
  assert_true(positioned.width > 0)
  assert_true(positioned.height > 0)
}
