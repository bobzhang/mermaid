///|
fn flow_node(id : String) -> @model.MermaidNode {
  { id, label: id, shape: Rectangle }
}

///|
fn flow_edge(source : String, target : String) -> @model.MermaidEdge {
  {
    source,
    target,
    label: Some("\{source}->\{target}"),
    style: Solid,
    has_arrow_start: false,
    has_arrow_end: true,
    relation_operator: Some("-->"),
  }
}

///|
fn flow_graph() -> @model.MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {
    "A": flow_node("A"),
    "B": flow_node("B"),
  }
  let class_defs : Map[String, Map[String, String]] = {}
  let class_assignments : Map[String, String] = {}
  let node_styles : Map[String, Map[String, String]] = {}
  let sequence_actor_kinds : Map[String, @model.SequenceParticipantKind] = {}
  let sequence_blocks : Array[@model.SequenceBlock] = []
  let sequence_notes : Array[@model.SequenceNote] = []
  let sequence_activation_commands : Array[@model.SequenceActivationCommand] = []
  {
    diagram_kind: Flowchart,
    direction: LR,
    nodes,
    edges: [flow_edge("A", "B")],
    subgraphs: [],
    class_defs,
    class_assignments,
    node_styles,
    sequence_actor_order: [],
    sequence_actor_kinds,
    sequence_blocks,
    sequence_notes,
    sequence_activation_commands,
  }
}

///|
test "elk backend produces a valid positioned graph" {
  let graph = flow_graph()
  let elk_layout = layout_graph_elk(
    graph,
    @model.RenderOptions::default(),
    true,
    false,
  )
  assert_eq(elk_layout.nodes.length(), 2)
  assert_eq(elk_layout.edges.length(), 1)
  assert_true(elk_layout.width > 0)
  assert_true(elk_layout.height > 0)
}

///|
test "elk backend exposes stable phase snapshots and counts" {
  let graph = flow_graph()
  let request : @layout_engine_graph_contract_core.GraphLayoutBackendRequest = {
    graph,
    options: @model.RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  }
  let elk_backend = layout_graph_elk_backend(request)
  let snapshots = elk_backend.phase_snapshots
  assert_eq(snapshots.length(), 3)
  assert_eq(snapshots[0].phase, "setup")
  assert_eq(snapshots[1].phase, "placement")
  assert_eq(snapshots[2].phase, "final")
  assert_eq(snapshots[2].node_count, 2)
  assert_eq(snapshots[2].edge_count, 1)
  assert_true(snapshots[2].width > 0)
  assert_true(snapshots[2].height > 0)
  assert_eq(elk_backend.positioned_graph.nodes.length(), 2)
  assert_eq(elk_backend.positioned_graph.edges.length(), 1)
}
