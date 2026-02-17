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
fn fanout_graph() -> @model.MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {
    "A": flow_node("A"),
    "B": flow_node("B"),
    "C": flow_node("C"),
    "D": flow_node("D"),
    "E": flow_node("E"),
  }
  let edges : Array[@model.MermaidEdge] = [
    flow_edge("A", "B"),
    {
      source: "A",
      target: "C",
      label: Some("compile"),
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "A",
      target: "D",
      label: Some("integration-tests"),
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "A",
      target: "E",
      label: Some("publish-artifact"),
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "E",
      target: "A",
      label: Some("feedback-loop"),
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
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
fn large_flow_graph() -> @model.MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {}
  for i in 0..<17 {
    let node_id = "N\{i}"
    nodes[node_id] = flow_node(node_id)
  }
  let edges : Array[@model.MermaidEdge] = []
  for i in 0..<16 {
    edges.push(flow_edge("N\{i}", "N\{i + 1}"))
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
fn simple_state_graph() -> @model.MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {
    "start": { id: "start", label: "start", shape: StateStart },
    "A": { id: "A", label: "A", shape: Circle },
    "end": { id: "end", label: "end", shape: StateEnd },
  }
  let edges : Array[@model.MermaidEdge] = [
    flow_edge("start", "A"),
    flow_edge("A", "end"),
  ]
  let class_defs : Map[String, Map[String, String]] = {}
  let class_assignments : Map[String, String] = {}
  let node_styles : Map[String, Map[String, String]] = {}
  let sequence_actor_kinds : Map[String, @model.SequenceParticipantKind] = {}
  let sequence_blocks : Array[@model.SequenceBlock] = []
  let sequence_notes : Array[@model.SequenceNote] = []
  let sequence_activation_commands : Array[@model.SequenceActivationCommand] = []
  {
    diagram_kind: State,
    direction: LR,
    nodes,
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
fn backend_snapshot_equal(
  left : @layout_engine_graph_contract_core.GraphLayoutPhaseSnapshot,
  right : @layout_engine_graph_contract_core.GraphLayoutPhaseSnapshot,
) -> Bool {
  left.phase == right.phase &&
  left.node_count == right.node_count &&
  left.edge_count == right.edge_count &&
  left.group_count == right.group_count &&
  left.width == right.width &&
  left.height == right.height
}

///|
fn backend_result_equal(
  left : @layout_engine_graph_contract_core.GraphLayoutBackendResult,
  right : @layout_engine_graph_contract_core.GraphLayoutBackendResult,
) -> Bool {
  if left.positioned_graph != right.positioned_graph {
    return false
  }
  let left_snapshots = left.phase_snapshots
  let right_snapshots = right.phase_snapshots
  if left_snapshots.length() != right_snapshots.length() {
    return false
  }
  for i in 0..<left_snapshots.length() {
    if !backend_snapshot_equal(left_snapshots[i], right_snapshots[i]) {
      return false
    }
  }
  true
}

///|
test "elk setup phase derives structure-aware spacing and preserves explicit spacing" {
  let graph = fanout_graph()
  let defaults = @model.RenderOptions::default()
  let tuned = derive_elk_render_options(graph, defaults)
  assert_true(
    @layout_engine_graph_internal_core.option_int_or(tuned.node_spacing, 0) >
    @layout_engine_graph_internal_core.resolve_node_spacing(defaults),
  )
  assert_true(
    @layout_engine_graph_internal_core.option_int_or(tuned.layer_spacing, 0) >
    @layout_engine_graph_internal_core.resolve_layer_spacing(defaults),
  )

  let explicit_options : @model.RenderOptions = {
    bg: None,
    fg: None,
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: None,
    padding: None,
    node_spacing: Some(88),
    layer_spacing: Some(66),
    transparent: None,
    layout_engine: Some(Elk),
  }
  let tuned_explicit = derive_elk_render_options(graph, explicit_options)
  assert_eq(tuned_explicit.node_spacing, Some(88))
  assert_eq(tuned_explicit.layer_spacing, Some(66))
}

///|
test "elk setup phase keeps state-graph spacing unset for state-specific placement rules" {
  let tuned = derive_elk_render_options(
    simple_state_graph(),
    @model.RenderOptions::default(),
  )
  assert_eq(tuned.node_spacing, None)
  assert_eq(tuned.layer_spacing, None)
}

///|
test "elk layered pipeline applies only to non-state flowcharts" {
  assert_eq(elk_graph_supports_layered_pipeline(flow_graph()), true)
  assert_eq(elk_graph_supports_layered_pipeline(large_flow_graph()), true)
  assert_eq(elk_graph_supports_layered_pipeline(simple_state_graph()), false)
}

///|
test "elk backend produces a valid positioned graph" {
  let elk_layout = layout_graph_elk_backend({
      graph: flow_graph(),
      options: @model.RenderOptions::default(),
      use_subgraph_redirects: true,
      compact_fanin: false,
    }).positioned_graph
  assert_eq(elk_layout.nodes.length(), 2)
  assert_eq(elk_layout.edges.length(), 1)
  assert_true(elk_layout.width > 0)
  assert_true(elk_layout.height > 0)
}

///|
test "elk backend differs from legacy on fanout-heavy graph when spacing is auto" {
  let graph = fanout_graph()
  let request : @layout_engine_graph_contract_core.GraphLayoutBackendRequest = {
    graph,
    options: @model.RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  }
  let legacy_backend = @layout_engine_graph_backend_core.run_graph_backend_pipeline(
    request,
    {
      enable_target_boundary_ports: false,
      preserve_assigned_endpoint_ports: false,
    },
  )
  let elk_backend = layout_graph_elk_backend(request)
  assert_true(!backend_result_equal(elk_backend, legacy_backend))
}

///|
test "elk backend falls back to shared backend pipeline on state graphs" {
  let graph = simple_state_graph()
  let request : @layout_engine_graph_contract_core.GraphLayoutBackendRequest = {
    graph,
    options: @model.RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  }
  let elk_backend = layout_graph_elk_backend(request)
  let fallback_backend = @layout_engine_graph_backend_core.run_graph_backend_pipeline(
    {
      graph,
      options: derive_elk_render_options(graph, @model.RenderOptions::default()),
      use_subgraph_redirects: true,
      compact_fanin: false,
    },
    {
      enable_target_boundary_ports: true,
      preserve_assigned_endpoint_ports: false,
    },
  )
  assert_true(backend_result_equal(elk_backend, fallback_backend))
}

///|
test "elk backend uses layered pipeline on large flowcharts" {
  let graph = large_flow_graph()
  let request : @layout_engine_graph_contract_core.GraphLayoutBackendRequest = {
    graph,
    options: @model.RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  }
  let elk_backend = layout_graph_elk_backend(request)
  let layered_backend = run_elk_layered_flow_backend(
    {
      graph,
      options: derive_elk_render_options(graph, @model.RenderOptions::default()),
      use_subgraph_redirects: true,
      compact_fanin: false,
    },
    {
      enable_target_boundary_ports: true,
      preserve_assigned_endpoint_ports: false,
    },
  )
  assert_true(backend_result_equal(elk_backend, layered_backend))
}

///|
test "elk layered backend forces layered pipeline for large flowcharts" {
  let graph = large_flow_graph()
  let request : @layout_engine_graph_contract_core.GraphLayoutBackendRequest = {
    graph,
    options: @model.RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  }
  let forced_backend = layout_graph_elk_layered_backend(request)
  let default_backend = layout_graph_elk_backend(request)
  assert_true(backend_result_equal(forced_backend, default_backend))
}

///|
test "elk layered backend still falls back on unsupported graph kinds" {
  let graph = simple_state_graph()
  let request : @layout_engine_graph_contract_core.GraphLayoutBackendRequest = {
    graph,
    options: @model.RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  }
  let forced_backend = layout_graph_elk_layered_backend(request)
  let fallback_backend = @layout_engine_graph_backend_core.run_graph_backend_pipeline(
    {
      graph,
      options: derive_elk_render_options(graph, @model.RenderOptions::default()),
      use_subgraph_redirects: true,
      compact_fanin: false,
    },
    {
      enable_target_boundary_ports: true,
      preserve_assigned_endpoint_ports: false,
    },
  )
  assert_true(backend_result_equal(forced_backend, fallback_backend))
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
