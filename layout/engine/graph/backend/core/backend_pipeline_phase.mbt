///|
/// Routing flags for backend-specific post-placement behavior.
pub(all) struct GraphBackendRoutingPolicy {
  enable_target_boundary_ports : Bool
  preserve_assigned_endpoint_ports : Bool
}

///|
fn setup_phase_snapshot(
  request : GraphLayoutBackendRequest,
  setup_state : LegacyLayoutSetupState,
) -> GraphLayoutPhaseSnapshot {
  {
    phase: "setup",
    node_count: setup_state.nodes_in_order().length(),
    edge_count: request.graph.edges.length(),
    group_count: request.graph.subgraphs.length(),
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
    node_count: placement_state.positioned_nodes().length(),
    edge_count: request.graph.edges.length(),
    group_count: request.graph.subgraphs.length(),
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
    width: positioned_graph.width,
    height: positioned_graph.height,
  }
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
  let phase_snapshots = [
    setup_phase_snapshot(request, setup_state),
    placement_phase_snapshot(request, placement_state),
    final_phase_snapshot(positioned_graph),
  ]
  { positioned_graph, phase_snapshots }
}
