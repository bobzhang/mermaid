///|
/// Legacy graph layout request assembled by core orchestration.
pub(all) struct LegacyLayoutRequest {
  graph : MermaidGraph
  options : RenderOptions
  use_subgraph_redirects : Bool
  compact_fanin : Bool
  routing_profile : LegacyRoutingProfile
}

///|
/// Selects the legacy routing behavior profile.
pub(all) enum LegacyRoutingProfile {
  LegacyCompatible
  DagreParityCompatible
}

///|
fn routing_flags_for_profile(profile : LegacyRoutingProfile) -> (Bool, Bool) {
  match profile {
    LegacyCompatible => (false, false)
    DagreParityCompatible => (true, true)
  }
}

///|
/// Runs the legacy graph layout pipeline with a selected routing profile.
pub fn layout_graph_legacy(request : LegacyLayoutRequest) -> PositionedGraph {
  let graph = request.graph
  let options = request.options
  let use_subgraph_redirects = request.use_subgraph_redirects
  let compact_fanin = request.compact_fanin
  let (enable_target_boundary_ports, preserve_assigned_endpoint_ports) = routing_flags_for_profile(
    request.routing_profile,
  )

  let setup_state = @layout_engine_graph_legacy_setup_core.build_legacy_layout_setup({
      graph,
      options,
      use_subgraph_redirects,
      compact_fanin,
    },
  )
  let subgraph_entry_by_id = setup_state.subgraph_entry_by_id
  let subgraph_exit_by_id = setup_state.subgraph_exit_by_id
  let nodes_in_order = setup_state.nodes_in_order
  let padding = setup_state.padding
  let node_spacing = setup_state.node_spacing
  let layer_spacing = setup_state.layer_spacing
  let horizontal = setup_state.horizontal
  let reverse = setup_state.reverse
  let state_graph = setup_state.state_graph
  let flat_state_graph = setup_state.flat_state_graph
  let enhanced_horizontal_state_flow = setup_state.enhanced_horizontal_state_flow
  let lane_state = setup_state.lane_state

  let placement_state = @layout_engine_graph_placement_core.compute_legacy_node_placement_state({
      graph,
      nodes_in_order,
      reverse,
      horizontal,
      state_graph,
      flat_state_graph,
      compact_fanin,
      enhanced_horizontal_state_flow,
      refined_horizontal_non_state_flow: lane_state.refined_horizontal_non_state_flow,
      refined_horizontal_non_state_labeled_cycle_flow: lane_state.refined_horizontal_non_state_labeled_cycle_flow,
      horizontal_cycle_non_state_flow: lane_state.horizontal_cycle_non_state_flow,
      use_subgraph_redirects,
      subgraph_entry_by_id,
      subgraph_exit_by_id,
      flow_max_rank: lane_state.flow_max_rank,
      flow_rank_by_node_id: lane_state.flow_rank_by_node_id,
      flow_lane_by_node_id: lane_state.flow_lane_by_node_id,
      flow_label_y_offset_by_rank: lane_state.flow_label_y_offset_by_rank,
      state_lane_by_node_id: lane_state.state_lane_by_node_id,
      state_label_y_offset_by_node_id: lane_state.state_label_y_offset_by_node_id,
      padding,
      node_spacing,
      layer_spacing,
    },
  )
  @layout_engine_graph_legacy_post_core.finalize_legacy_layout_from_placement({
    graph,
    setup_state,
    placement_state,
    use_subgraph_redirects,
    enable_target_boundary_ports,
    preserve_assigned_endpoint_ports,
  })
}
