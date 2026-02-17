///|
/// Runs the legacy placement phase from setup state.
pub fn run_legacy_placement_phase(
  graph : MermaidGraph,
  setup_state : LegacyLayoutSetupState,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
) -> LegacyPlacementState {
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

  @layout_engine_graph_placement_core.compute_legacy_node_placement_state({
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
  })
}
