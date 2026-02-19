///|
fn test_node(id : String) -> @model.MermaidNode {
  { id, label: id, shape: Rectangle }
}

///|
fn test_node_with_label(id : String, label : String) -> @model.MermaidNode {
  { id, label, shape: Rectangle }
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
    node_definition_order: nodes_in_order.map(node => node.id),
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
test "placement computes forward horizontal ordering from rank map" {
  let nodes = [test_node("A"), test_node("B")]
  let graph = test_graph(LR, nodes, [test_edge("A", "B")])
  let setup_state = @layout_engine_graph_legacy_setup_core.build_legacy_layout_setup(
    graph,
    @model.RenderOptions::default(),
    false,
    false,
  )
  let placement_state = run_legacy_placement_phase(
    graph, setup_state, false, false,
  )

  let positioned_by_id = placement_state.positioned_by_id
  let ax = positioned_by_id["A"].x
  let bx = positioned_by_id["B"].x
  assert_true(bx > ax)
  assert_eq(placement_state.positioned_nodes.length(), 2)
}

///|
test "placement reverse mode flips horizontal rank ordering" {
  let nodes = [test_node("A"), test_node("B")]
  let graph = test_graph(RL, nodes, [test_edge("A", "B")])
  let setup_state = @layout_engine_graph_legacy_setup_core.build_legacy_layout_setup(
    graph,
    @model.RenderOptions::default(),
    false,
    false,
  )
  let placement_state = run_legacy_placement_phase(
    graph, setup_state, false, false,
  )

  let positioned_by_id = placement_state.positioned_by_id
  let ax = positioned_by_id["A"].x
  let bx = positioned_by_id["B"].x
  assert_true(ax > bx)
}

///|
test "placement keeps same-rank horizontal nodes aligned on rank center" {
  let nodes = [
    test_node_with_label("A", "A"),
    test_node_with_label("LONG", "This is a much wider label"),
    test_node_with_label("B", "B"),
  ]
  let graph = test_graph(LR, nodes, [
    test_edge("A", "B"),
    test_edge("LONG", "B"),
  ])
  let setup_state = @layout_engine_graph_legacy_setup_core.build_legacy_layout_setup(
    graph,
    @model.RenderOptions::default(),
    false,
    false,
  )
  let placement_state = run_legacy_placement_phase(
    graph, setup_state, false, false,
  )

  let positioned_by_id = placement_state.positioned_by_id
  assert_eq(positioned_by_id["A"].x, positioned_by_id["LONG"].x)
}

///|
test "placement dagre parity horizontal axis uses rank width plus ranksep spacing" {
  let nodes = [
    test_node("A"),
    test_node("B"),
    test_node("M"),
    test_node("X"),
    test_node("Y"),
    test_node("__lane_dummy_f_4_1"),
    test_node("__lane_dummy_f_5_1"),
  ]
  let graph = test_graph(LR, nodes, [
    test_edge("A", "M"),
    test_edge("B", "M"),
    test_edge("M", "X"),
    test_edge("M", "Y"),
    test_edge("A", "__lane_dummy_f_4_1"),
    test_edge("__lane_dummy_f_4_1", "Y"),
    test_edge("B", "__lane_dummy_f_5_1"),
    test_edge("__lane_dummy_f_5_1", "X"),
  ])
  let setup_state = @layout_engine_graph_legacy_setup_core.build_legacy_layout_setup(
    graph,
    { ..@model.RenderOptions::default(), layout_engine: Some(DagreParity) },
    true,
    false,
  )
  let placement_state = run_legacy_placement_phase(
    graph, setup_state, true, false,
  )
  let positioned_by_id = placement_state.positioned_by_id

  assert_eq(positioned_by_id["A"].x, 75)
  assert_eq(positioned_by_id["M"].x, 284)
  assert_eq(positioned_by_id["X"].x, 493)
  assert_eq(positioned_by_id["__lane_dummy_f_4_1"].x, 284)
  assert_eq(positioned_by_id["__lane_dummy_f_5_1"].x, 284)
  assert_eq(positioned_by_id["M"].x - positioned_by_id["A"].x, 209)
  assert_eq(positioned_by_id["X"].x - positioned_by_id["M"].x, 209)
}

///|
test "placement dagre parity minor axis compacts sparse dummy lanes" {
  let nodes = [
    test_node("A"),
    test_node("B"),
    test_node("C"),
    test_node("D"),
    test_node("E"),
    test_node("F"),
  ]
  let graph = test_graph(LR, nodes, [
    test_edge("A", "D"),
    test_edge("B", "C"),
    test_edge("A", "E"),
    test_edge("B", "F"),
    test_edge("C", "F"),
    test_edge("D", "E"),
    test_edge("A", "F"),
    test_edge("B", "E"),
  ])
  let setup_state = @layout_engine_graph_legacy_setup_core.build_legacy_layout_setup(
    graph,
    { ..@model.RenderOptions::default(), layout_engine: Some(DagreParity) },
    true,
    false,
  )
  let placement_state = run_legacy_placement_phase(
    graph, setup_state, true, false,
  )
  let positioned_by_id = placement_state.positioned_by_id
  let ys = [
    positioned_by_id["A"].y,
    positioned_by_id["B"].y,
    positioned_by_id["C"].y,
    positioned_by_id["D"].y,
    positioned_by_id["E"].y,
    positioned_by_id["F"].y,
  ]
  let mut min_y = ys[0]
  let mut max_y = ys[0]
  for y in ys {
    min_y = min_y.min(y)
    max_y = max_y.max(y)
  }
  // Legacy parity lane indexes keep dummy channels, so the coordinate phase
  // must compact them to avoid stretched output.
  assert_true(max_y - min_y <= setup_state.node_spacing * 3 + 10)
  let dy = {
    let raw = positioned_by_id["D"].y - positioned_by_id["E"].y
    if raw < 0 {
      -raw
    } else {
      raw
    }
  }
  assert_true(dy <= setup_state.node_spacing / 2)
}
