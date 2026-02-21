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
    node_definition_order: [],
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
test "engine dispatch returns valid layouts for legacy dagre and elk backends" {
  let graph = flow_graph()
  let options = @model.RenderOptions::default()
  let dagre_parity_layout = dispatch_graph_layout_engine_backend(
      graph,
      options,
      true,
      false,
      DagreParity,
    ).positioned_graph
  let elk_layout = dispatch_graph_layout_engine_backend(
      graph,
      options,
      true,
      false,
      Elk,
    ).positioned_graph
  let elk_layered_layout = dispatch_graph_layout_engine_backend(
      graph,
      options,
      true,
      false,
      ElkLayered,
    ).positioned_graph
  let legacy_layout = dispatch_graph_layout_engine_backend(
      graph,
      options,
      true,
      false,
      Legacy,
    ).positioned_graph

  assert_eq(dagre_parity_layout.nodes.length(), 2)
  assert_eq(dagre_parity_layout.edges.length(), 1)
  assert_eq(elk_layout.nodes.length(), 2)
  assert_eq(elk_layout.edges.length(), 1)
  assert_eq(elk_layered_layout.nodes.length(), 2)
  assert_eq(elk_layered_layout.edges.length(), 1)
  assert_eq(legacy_layout.nodes.length(), 2)
  assert_eq(legacy_layout.edges.length(), 1)
}

///|
test "engine backend dispatch exposes phase snapshots" {
  let graph = flow_graph()
  let backend = @layout_engine_graph_engine_profile_core.run_graph_layout_engine_backend(
    {
      graph,
      options: @model.RenderOptions::default(),
      use_subgraph_redirects: true,
      compact_fanin: false,
    },
    DagreParity,
  )
  assert_eq(backend.phase_snapshots.length(), 4)
  assert_eq(backend.phase_snapshots[0].phase, "setup")
  assert_eq(backend.phase_snapshots[1].phase, "rank")
  assert_eq(backend.phase_snapshots[2].phase, "placement")
  assert_eq(backend.phase_snapshots[3].phase, "final")
  assert_true(backend.phase_snapshots[1].rank_layer_count > 0)
  assert_true(backend.phase_snapshots[3].width > 0)
  assert_true(backend.phase_snapshots[3].height > 0)
}
