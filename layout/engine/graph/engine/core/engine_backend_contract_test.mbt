///|
fn stress_node(id : String) -> @model.MermaidNode {
  { id, label: id, shape: Rectangle }
}

///|
fn stress_edge(
  source : String,
  target : String,
  label : String?,
) -> @model.MermaidEdge {
  {
    source,
    target,
    label,
    style: Solid,
    has_arrow_start: false,
    has_arrow_end: true,
    relation_operator: Some("-->"),
  }
}

///|
fn stress_graph() -> @model.MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {
    "A": stress_node("A"),
    "B": stress_node("B"),
    "C": stress_node("C"),
    "D": stress_node("D"),
    "E": stress_node("E"),
    "F": stress_node("F"),
    "G": stress_node("G"),
    "H": stress_node("H"),
  }
  let edges = [
    stress_edge("A", "C", Some("ac")),
    stress_edge("A", "D", Some("ad")),
    stress_edge("B", "D", Some("bd")),
    stress_edge("B", "E", Some("be")),
    stress_edge("C", "F", Some("cf")),
    stress_edge("D", "F", Some("df")),
    stress_edge("D", "G", Some("dg")),
    stress_edge("E", "G", Some("eg")),
    stress_edge("F", "H", Some("fh")),
    stress_edge("G", "H", Some("gh")),
    stress_edge("H", "B", Some("hb")),
    stress_edge("G", "C", Some("gc")),
  ]
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
    edges,
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
fn run_backend_with_snapshots(
  graph : @model.MermaidGraph,
  options : @model.RenderOptions,
  engine : @model.LayoutEngine,
) -> @layout_engine_graph_contract_core.GraphLayoutBackendResult {
  @layout_engine_graph_engine_profile_core.run_graph_layout_engine_backend(
    { graph, options, use_subgraph_redirects: true, compact_fanin: false },
    engine,
  )
}

///|
fn assert_base_phase_traces(
  backend : @layout_engine_graph_contract_core.GraphLayoutBackendResult,
) -> Unit raise {
  let phase_traces = backend.phase_traces
  assert_eq(phase_traces.length(), 4)
  assert_eq(phase_traces[0].phase, "setup")
  assert_eq(phase_traces[1].phase, "rank")
  assert_eq(phase_traces[2].phase, "placement")
  assert_eq(phase_traces[3].phase, "final")
  assert_true(phase_traces[0].labels.contains("layout_family"))
  assert_true(phase_traces[1].labels.contains("rank_layers"))
  assert_true(phase_traces[1].metrics.contains("max_rank"))
  assert_true(phase_traces[2].metrics.contains("node_count"))
  assert_true(phase_traces[3].metrics.contains("width"))
  assert_true(phase_traces[3].metrics.contains("height"))
}

///|
test "engine backends keep phase snapshot invariants on stress graph" {
  let graph = stress_graph()
  let expected_nodes = graph.nodes.length()
  let expected_edges = graph.edges.length()
  let options = @model.RenderOptions::default()

  let legacy_backend = run_backend_with_snapshots(graph, options, Legacy)
  let legacy_snapshots = legacy_backend.phase_snapshots
  assert_eq(legacy_snapshots.length(), 4)
  assert_eq(legacy_snapshots[0].phase, "setup")
  assert_eq(legacy_snapshots[1].phase, "rank")
  assert_eq(legacy_snapshots[2].phase, "placement")
  assert_eq(legacy_snapshots[3].phase, "final")
  assert_eq(legacy_snapshots[0].node_count, expected_nodes)
  assert_eq(legacy_snapshots[1].node_count, expected_nodes)
  assert_eq(legacy_snapshots[2].node_count, expected_nodes)
  assert_eq(legacy_snapshots[3].node_count, expected_nodes)
  assert_eq(legacy_snapshots[3].edge_count, expected_edges)
  assert_true(legacy_snapshots[1].rank_layer_count > 0)
  assert_true(legacy_snapshots[3].width > 0)
  assert_true(legacy_snapshots[3].height > 0)
  assert_eq(legacy_backend.positioned_graph.nodes.length(), expected_nodes)
  assert_eq(legacy_backend.positioned_graph.edges.length(), expected_edges)
  assert_base_phase_traces(legacy_backend)

  let dagre_backend = run_backend_with_snapshots(graph, options, DagreParity)
  let dagre_snapshots = dagre_backend.phase_snapshots
  assert_eq(dagre_snapshots.length(), 4)
  assert_eq(dagre_snapshots[0].phase, "setup")
  assert_eq(dagre_snapshots[1].phase, "rank")
  assert_eq(dagre_snapshots[2].phase, "placement")
  assert_eq(dagre_snapshots[3].phase, "final")
  assert_eq(dagre_snapshots[0].node_count, expected_nodes)
  assert_eq(dagre_snapshots[1].node_count, expected_nodes)
  assert_eq(dagre_snapshots[2].node_count, expected_nodes)
  assert_eq(dagre_snapshots[3].node_count, expected_nodes)
  assert_eq(dagre_snapshots[3].edge_count, expected_edges)
  assert_true(dagre_snapshots[1].rank_layer_count > 0)
  assert_true(dagre_snapshots[3].width > 0)
  assert_true(dagre_snapshots[3].height > 0)
  assert_eq(dagre_backend.positioned_graph.nodes.length(), expected_nodes)
  assert_eq(dagre_backend.positioned_graph.edges.length(), expected_edges)
  assert_base_phase_traces(dagre_backend)

  let elk_backend = run_backend_with_snapshots(graph, options, Elk)
  let elk_snapshots = elk_backend.phase_snapshots
  assert_eq(elk_snapshots.length(), 4)
  assert_eq(elk_snapshots[0].phase, "setup")
  assert_eq(elk_snapshots[1].phase, "rank")
  assert_eq(elk_snapshots[2].phase, "placement")
  assert_eq(elk_snapshots[3].phase, "final")
  assert_eq(elk_snapshots[0].node_count, expected_nodes)
  assert_eq(elk_snapshots[1].node_count, expected_nodes)
  assert_eq(elk_snapshots[2].node_count, expected_nodes)
  assert_eq(elk_snapshots[3].node_count, expected_nodes)
  assert_eq(elk_snapshots[3].edge_count, expected_edges)
  assert_true(elk_snapshots[1].rank_layer_count > 0)
  assert_true(elk_snapshots[3].width > 0)
  assert_true(elk_snapshots[3].height > 0)
  assert_eq(elk_backend.positioned_graph.nodes.length(), expected_nodes)
  assert_eq(elk_backend.positioned_graph.edges.length(), expected_edges)
  assert_base_phase_traces(elk_backend)
  assert_true(elk_backend.phase_traces[1].labels.contains("rank_seed_strategy"))
  assert_true(
    elk_backend.phase_traces[1].labels.contains("rank_order_strategy"),
  )
  assert_true(
    elk_backend.phase_traces[1].labels.contains("rank_order_selected_source"),
  )
  assert_true(
    elk_backend.phase_traces[2].labels.contains("minor_placement_strategy"),
  )

  let elk_layered_backend = run_backend_with_snapshots(
    graph,
    options,
    ElkLayered,
  )
  let elk_layered_snapshots = elk_layered_backend.phase_snapshots
  assert_eq(elk_layered_snapshots.length(), 4)
  assert_eq(elk_layered_snapshots[0].phase, "setup")
  assert_eq(elk_layered_snapshots[1].phase, "rank")
  assert_eq(elk_layered_snapshots[2].phase, "placement")
  assert_eq(elk_layered_snapshots[3].phase, "final")
  assert_eq(elk_layered_snapshots[0].node_count, expected_nodes)
  assert_eq(elk_layered_snapshots[1].node_count, expected_nodes)
  assert_eq(elk_layered_snapshots[2].node_count, expected_nodes)
  assert_eq(elk_layered_snapshots[3].node_count, expected_nodes)
  assert_eq(elk_layered_snapshots[3].edge_count, expected_edges)
  assert_true(elk_layered_snapshots[1].rank_layer_count > 0)
  assert_true(elk_layered_snapshots[3].width > 0)
  assert_true(elk_layered_snapshots[3].height > 0)
  assert_eq(elk_layered_backend.positioned_graph.nodes.length(), expected_nodes)
  assert_eq(elk_layered_backend.positioned_graph.edges.length(), expected_edges)
  assert_base_phase_traces(elk_layered_backend)
  assert_true(
    elk_layered_backend.phase_traces[1].labels.contains("rank_seed_strategy"),
  )
  assert_true(
    elk_layered_backend.phase_traces[1].labels.contains("rank_order_strategy"),
  )
  assert_true(
    elk_layered_backend.phase_traces[2].labels.contains(
      "minor_placement_strategy",
    ),
  )
}
