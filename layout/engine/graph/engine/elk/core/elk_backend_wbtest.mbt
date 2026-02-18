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
fn positioned_sequence_lifeline_equal(
  left : @model.PositionedSequenceLifeline,
  right : @model.PositionedSequenceLifeline,
) -> Bool {
  left.actor_id == right.actor_id &&
  left.x == right.x &&
  left.top_y == right.top_y &&
  left.bottom_y == right.bottom_y
}

///|
fn positioned_sequence_activation_equal(
  left : @model.PositionedSequenceActivation,
  right : @model.PositionedSequenceActivation,
) -> Bool {
  left.actor_id == right.actor_id &&
  left.x == right.x &&
  left.top_y == right.top_y &&
  left.bottom_y == right.bottom_y &&
  left.width == right.width
}

///|
fn positioned_sequence_block_divider_equal(
  left : @model.PositionedSequenceBlockDivider,
  right : @model.PositionedSequenceBlockDivider,
) -> Bool {
  left.y == right.y && left.label == right.label
}

///|
fn positioned_sequence_block_equal(
  left : @model.PositionedSequenceBlock,
  right : @model.PositionedSequenceBlock,
) -> Bool {
  if left.block_type != right.block_type ||
    left.label != right.label ||
    left.x != right.x ||
    left.y != right.y ||
    left.width != right.width ||
    left.height != right.height {
    return false
  }
  if left.dividers.length() != right.dividers.length() {
    return false
  }
  for i in 0..<left.dividers.length() {
    if !positioned_sequence_block_divider_equal(
        left.dividers[i],
        right.dividers[i],
      ) {
      return false
    }
  }
  true
}

///|
fn positioned_point_equal(left : @model.Point, right : @model.Point) -> Bool {
  left.x == right.x && left.y == right.y
}

///|
fn positioned_point_option_equal(
  left : @model.Point?,
  right : @model.Point?,
) -> Bool {
  match (left, right) {
    (Some(left_point), Some(right_point)) =>
      positioned_point_equal(left_point, right_point)
    (None, None) => true
    _ => false
  }
}

///|
fn positioned_point_array_equal(
  left : Array[@model.Point],
  right : Array[@model.Point],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if !positioned_point_equal(left[i], right[i]) {
      return false
    }
  }
  true
}

///|
fn positioned_node_equal(
  left : @model.PositionedNode,
  right : @model.PositionedNode,
) -> Bool {
  left.id == right.id &&
  left.label == right.label &&
  left.shape == right.shape &&
  left.x == right.x &&
  left.y == right.y &&
  left.width == right.width &&
  left.height == right.height &&
  left.inline_style == right.inline_style
}

///|
fn positioned_node_array_equal(
  left : Array[@model.PositionedNode],
  right : Array[@model.PositionedNode],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if !positioned_node_equal(left[i], right[i]) {
      return false
    }
  }
  true
}

///|
fn positioned_edge_equal(
  left : @model.PositionedEdge,
  right : @model.PositionedEdge,
) -> Bool {
  left.source == right.source &&
  left.target == right.target &&
  left.label == right.label &&
  left.style == right.style &&
  left.has_arrow_start == right.has_arrow_start &&
  left.has_arrow_end == right.has_arrow_end &&
  left.relation_operator == right.relation_operator &&
  positioned_point_array_equal(left.points, right.points) &&
  positioned_point_option_equal(left.label_position, right.label_position)
}

///|
fn positioned_edge_array_equal(
  left : Array[@model.PositionedEdge],
  right : Array[@model.PositionedEdge],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if !positioned_edge_equal(left[i], right[i]) {
      return false
    }
  }
  true
}

///|
fn positioned_group_equal(
  left : @model.PositionedGroup,
  right : @model.PositionedGroup,
) -> Bool {
  left.id == right.id &&
  left.label == right.label &&
  left.x == right.x &&
  left.y == right.y &&
  left.width == right.width &&
  left.height == right.height &&
  positioned_group_array_equal(left.children, right.children)
}

///|
fn positioned_group_array_equal(
  left : Array[@model.PositionedGroup],
  right : Array[@model.PositionedGroup],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if !positioned_group_equal(left[i], right[i]) {
      return false
    }
  }
  true
}

///|
fn positioned_sequence_note_equal(
  left : @model.PositionedSequenceNote,
  right : @model.PositionedSequenceNote,
) -> Bool {
  left.text == right.text &&
  left.x == right.x &&
  left.y == right.y &&
  left.width == right.width &&
  left.height == right.height
}

///|
fn positioned_graph_equal(
  left : @model.PositionedGraph,
  right : @model.PositionedGraph,
) -> Bool {
  if left.width != right.width || left.height != right.height {
    return false
  }
  if !positioned_node_array_equal(left.nodes, right.nodes) ||
    !positioned_edge_array_equal(left.edges, right.edges) ||
    !positioned_group_array_equal(left.groups, right.groups) {
    return false
  }
  if left.sequence_lifelines.length() != right.sequence_lifelines.length() {
    return false
  }
  for i in 0..<left.sequence_lifelines.length() {
    if !positioned_sequence_lifeline_equal(
        left.sequence_lifelines[i],
        right.sequence_lifelines[i],
      ) {
      return false
    }
  }
  if left.sequence_activations.length() != right.sequence_activations.length() {
    return false
  }
  for i in 0..<left.sequence_activations.length() {
    if !positioned_sequence_activation_equal(
        left.sequence_activations[i],
        right.sequence_activations[i],
      ) {
      return false
    }
  }
  if left.sequence_blocks.length() != right.sequence_blocks.length() {
    return false
  }
  for i in 0..<left.sequence_blocks.length() {
    if !positioned_sequence_block_equal(
        left.sequence_blocks[i],
        right.sequence_blocks[i],
      ) {
      return false
    }
  }
  if left.sequence_notes.length() != right.sequence_notes.length() {
    return false
  }
  for i in 0..<left.sequence_notes.length() {
    if !positioned_sequence_note_equal(
        left.sequence_notes[i],
        right.sequence_notes[i],
      ) {
      return false
    }
  }
  true
}

///|
fn backend_result_equal(
  left : @layout_engine_graph_contract_core.GraphLayoutBackendResult,
  right : @layout_engine_graph_contract_core.GraphLayoutBackendResult,
) -> Bool {
  if !positioned_graph_equal(left.positioned_graph, right.positioned_graph) {
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
    @layout_engine_graph_internal_core.option_int_or(defaults.node_spacing, 130),
  )
  assert_true(
    @layout_engine_graph_internal_core.option_int_or(tuned.layer_spacing, 0) >
    @layout_engine_graph_internal_core.option_int_or(defaults.layer_spacing, 90),
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
      options: request.options,
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
