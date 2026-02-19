///|
/// Routing flags for backend-specific post-placement behavior.
pub(all) struct GraphBackendRoutingPolicy {
  enable_target_boundary_ports : Bool
  preserve_assigned_endpoint_ports : Bool
}

///|
fn bool_flag(value : Bool) -> Int {
  if value {
    1
  } else {
    0
  }
}

///|
fn option_int_or(value : Int?, fallback : Int) -> Int {
  match value {
    Some(v) => v
    None => fallback
  }
}

///|
fn diagram_kind_tag(graph : MermaidGraph) -> String {
  match graph.diagram_kind {
    Flowchart => "flowchart"
    State => "state"
    Sequence => "sequence"
    Class => "class"
    Er => "er"
  }
}

///|
fn direction_tag(graph : MermaidGraph) -> String {
  match graph.direction {
    TD => "TD"
    TB => "TB"
    LR => "LR"
    BT => "BT"
    RL => "RL"
  }
}

///|
fn phase_metrics(snapshot : GraphLayoutPhaseSnapshot) -> Map[String, Int] {
  {
    "node_count": snapshot.node_count,
    "edge_count": snapshot.edge_count,
    "group_count": snapshot.group_count,
    "rank_layer_count": snapshot.rank_layer_count,
    "width": snapshot.width,
    "height": snapshot.height,
  }
}

///|
fn encode_rank_layers(rank_layers : Array[Array[String]]) -> String {
  if rank_layers.length() == 0 {
    return "(none)"
  }
  let lines : Array[String] = []
  for rank, node_ids in rank_layers {
    let joined = node_ids.join(",")
    lines.push("r\{rank}:\{joined}")
  }
  lines.join("|")
}

///|
fn lane_span_by_node_id(lane_by_node_id : Map[String, Int]) -> Int {
  let mut has_value = false
  let mut min_lane = 0
  let mut max_lane = 0
  for _, lane in lane_by_node_id {
    if !has_value {
      has_value = true
      min_lane = lane
      max_lane = lane
      continue
    }
    if lane < min_lane {
      min_lane = lane
    }
    if lane > max_lane {
      max_lane = lane
    }
  }
  if has_value {
    max_lane - min_lane
  } else {
    0
  }
}

///|
fn collect_rank_layers_from_setup_state(
  setup_state : LegacyLayoutSetupState,
) -> Array[Array[String]] {
  let rank_layers : Array[Array[(Int, Int, String)]] = []
  let max_rank = setup_state.lane_state.flow_max_rank
  for _ in 0..<=max_rank {
    rank_layers.push([])
  }
  for order_index, node in setup_state.nodes_in_order {
    let rank = option_int_or(
      setup_state.lane_state.flow_rank_by_node_id.get(node.id),
      0,
    )
    let lane = option_int_or(
      setup_state.lane_state.flow_lane_by_node_id.get(node.id),
      0,
    )
    if rank < 0 {
      continue
    }
    if rank >= rank_layers.length() {
      for _ in rank_layers.length()..<=rank {
        rank_layers.push([])
      }
    }
    rank_layers[rank].push((lane, order_index, node.id))
  }
  let normalized : Array[Array[String]] = []
  for nodes in rank_layers {
    nodes.sort_by((left, right) => {
      let (left_lane, left_order, left_id) = left
      let (right_lane, right_order, right_id) = right
      if left_lane != right_lane {
        left_lane.compare(right_lane)
      } else if left_order != right_order {
        left_order.compare(right_order)
      } else {
        left_id.compare(right_id)
      }
    })
    let node_ids : Array[String] = []
    for node in nodes {
      let (_, _, node_id) = node
      node_ids.push(node_id)
    }
    normalized.push(node_ids)
  }
  normalized
}

///|
fn setup_phase_snapshot(
  request : GraphLayoutBackendRequest,
  setup_state : LegacyLayoutSetupState,
) -> GraphLayoutPhaseSnapshot {
  let rank_layer_count = if setup_state.nodes_in_order.length() == 0 {
    0
  } else {
    setup_state.lane_state.flow_max_rank + 1
  }
  {
    phase: "setup",
    node_count: setup_state.nodes_in_order.length(),
    edge_count: request.graph.edges.length(),
    group_count: request.graph.subgraphs.length(),
    rank_layer_count,
    width: 0,
    height: 0,
  }
}

///|
fn rank_phase_snapshot(
  request : GraphLayoutBackendRequest,
  setup_state : LegacyLayoutSetupState,
) -> GraphLayoutPhaseSnapshot {
  let rank_layer_count = if setup_state.nodes_in_order.length() == 0 {
    0
  } else {
    setup_state.lane_state.flow_max_rank + 1
  }
  {
    phase: "rank",
    node_count: setup_state.nodes_in_order.length(),
    edge_count: request.graph.edges.length(),
    group_count: request.graph.subgraphs.length(),
    rank_layer_count,
    width: 0,
    height: 0,
  }
}

///|
fn placement_phase_snapshot(
  request : GraphLayoutBackendRequest,
  placement_state : LegacyPlacementState,
) -> GraphLayoutPhaseSnapshot {
  {
    phase: "placement",
    node_count: placement_state.positioned_nodes.length(),
    edge_count: request.graph.edges.length(),
    group_count: request.graph.subgraphs.length(),
    rank_layer_count: 0,
    width: 0,
    height: 0,
  }
}

///|
fn final_phase_snapshot(
  positioned_graph : PositionedGraph,
) -> GraphLayoutPhaseSnapshot {
  {
    phase: "final",
    node_count: positioned_graph.nodes.length(),
    edge_count: positioned_graph.edges.length(),
    group_count: positioned_graph.groups.length(),
    rank_layer_count: 0,
    width: positioned_graph.width,
    height: positioned_graph.height,
  }
}

///|
fn setup_phase_trace(
  request : GraphLayoutBackendRequest,
  setup_state : LegacyLayoutSetupState,
  snapshot : GraphLayoutPhaseSnapshot,
) -> GraphLayoutPhaseTrace {
  let metrics = phase_metrics(snapshot)
  metrics["padding"] = setup_state.padding
  metrics["node_spacing"] = setup_state.node_spacing
  metrics["layer_spacing"] = setup_state.layer_spacing
  metrics["max_rank"] = setup_state.lane_state.flow_max_rank
  metrics["horizontal"] = bool_flag(setup_state.horizontal)
  metrics["reverse"] = bool_flag(setup_state.reverse)
  metrics["state_graph"] = bool_flag(setup_state.state_graph)
  metrics["class_or_er_graph"] = bool_flag(setup_state.class_or_er_graph)
  metrics["dagre_parity_mode"] = bool_flag(setup_state.dagre_parity_mode)
  metrics["flat_state_graph"] = bool_flag(setup_state.flat_state_graph)
  metrics["enhanced_horizontal_state_flow"] = bool_flag(
    setup_state.enhanced_horizontal_state_flow,
  )
  let labels : Map[String, String] = {}
  labels["diagram_kind"] = diagram_kind_tag(request.graph)
  labels["direction"] = direction_tag(request.graph)
  labels["layout_family"] = "legacy"
  { phase: snapshot.phase, metrics, labels }
}

///|
fn rank_phase_trace(
  setup_state : LegacyLayoutSetupState,
  snapshot : GraphLayoutPhaseSnapshot,
) -> GraphLayoutPhaseTrace {
  let metrics = phase_metrics(snapshot)
  metrics["max_rank"] = setup_state.lane_state.flow_max_rank
  metrics["lane_span"] = lane_span_by_node_id(
    setup_state.lane_state.flow_lane_by_node_id,
  )
  metrics["dagre_parity_mode"] = bool_flag(setup_state.dagre_parity_mode)
  let labels : Map[String, String] = {}
  labels["rank_layers"] = encode_rank_layers(
    collect_rank_layers_from_setup_state(setup_state),
  )
  labels["layout_family"] = "legacy"
  { phase: snapshot.phase, metrics, labels }
}

///|
fn default_phase_trace(
  snapshot : GraphLayoutPhaseSnapshot,
) -> GraphLayoutPhaseTrace {
  { phase: snapshot.phase, metrics: phase_metrics(snapshot), labels: {} }
}

///|
/// Executes the shared graph-layout backend pipeline with backend-specific routing policy.
pub fn run_graph_backend_pipeline(
  request : GraphLayoutBackendRequest,
  routing_policy : GraphBackendRoutingPolicy,
) -> GraphLayoutBackendResult {
  let graph = request.graph
  let options = request.options
  let use_subgraph_redirects = request.use_subgraph_redirects
  let compact_fanin = request.compact_fanin

  let setup_state = @layout_engine_graph_legacy_setup_core.build_legacy_layout_setup(
    graph, options, use_subgraph_redirects, compact_fanin,
  )
  let placement_state = @layout_engine_graph_placement_core.run_legacy_placement_phase(
    graph, setup_state, use_subgraph_redirects, compact_fanin,
  )
  let positioned_graph = @layout_engine_graph_legacy_post_core.finalize_legacy_layout_from_placement(
    graph,
    setup_state,
    placement_state,
    use_subgraph_redirects,
    routing_policy.enable_target_boundary_ports,
    routing_policy.preserve_assigned_endpoint_ports,
  )
  let setup_snapshot = setup_phase_snapshot(request, setup_state)
  let rank_snapshot = rank_phase_snapshot(request, setup_state)
  let placement_snapshot = placement_phase_snapshot(request, placement_state)
  let final_snapshot = final_phase_snapshot(positioned_graph)
  let phase_snapshots = [
    setup_snapshot, rank_snapshot, placement_snapshot, final_snapshot,
  ]
  let phase_traces = [
    setup_phase_trace(request, setup_state, setup_snapshot),
    rank_phase_trace(setup_state, rank_snapshot),
    default_phase_trace(placement_snapshot),
    default_phase_trace(final_snapshot),
  ]
  { positioned_graph, phase_snapshots, phase_traces }
}
