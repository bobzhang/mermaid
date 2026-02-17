///|
/// Legacy graph layout request assembled by core orchestration.
pub(all) struct LegacyLayoutRequest {
  graph : MermaidGraph
  options : RenderOptions
  use_subgraph_redirects : Bool
  compact_fanin : Bool
  enable_target_boundary_ports : Bool
  preserve_assigned_endpoint_ports : Bool
}

///|
/// Runs the legacy graph layout pipeline with explicit routing toggles.
pub fn layout_graph_legacy_with_subgraph_redirects(
  request : LegacyLayoutRequest,
) -> PositionedGraph {
  let graph = request.graph
  let options = request.options
  let use_subgraph_redirects = request.use_subgraph_redirects
  let compact_fanin = request.compact_fanin
  let enable_target_boundary_ports = request.enable_target_boundary_ports
  let preserve_assigned_endpoint_ports = request.preserve_assigned_endpoint_ports

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
  let class_or_er_graph = setup_state.class_or_er_graph
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
  let positioned_nodes = placement_state.positioned_nodes
  let positioned_by_id = placement_state.positioned_by_id
  let mut max_right = placement_state.max_right
  let mut max_bottom = placement_state.max_bottom

  let positioned_index_by_id : Map[String, Int] = {}
  for i, node in positioned_nodes {
    positioned_index_by_id[node.id] = i
  }
  let node_horizontal_by_id : Map[String, Bool] = {}
  if state_graph {
    @layout_engine_graph_group_core.apply_subgraph_direction_overrides({
      subgraphs: graph.subgraphs,
      inherited_horizontal: horizontal,
      inherited_reverse: reverse,
      inherited_override_active: false,
      global_horizontal: horizontal,
      global_reverse: reverse,
      node_spacing,
      layer_spacing,
      positioned_nodes,
      positioned_index_by_id,
      node_horizontal_by_id,
    })
  }

  max_right = padding
  max_bottom = padding
  for node in positioned_nodes {
    positioned_by_id[node.id] = node
    max_right = max_right.max(node.x + node.width / 2)
    max_bottom = max_bottom.max(node.y + node.height / 2)
  }

  let positioned_groups = @layout_engine_graph_group_core.build_legacy_positioned_groups({
      graph,
      padding,
      horizontal,
      reverse,
      state_graph,
      node_spacing,
      layer_spacing,
      positioned_nodes,
      positioned_by_id,
      positioned_index_by_id,
    },
  )

  let positioned_edges = @layout_engine_graph_routing_core.route_legacy_positioned_edges({
      graph,
      state_graph,
      class_or_er_graph,
      horizontal,
      layer_spacing,
      node_spacing,
      use_subgraph_redirects,
      subgraph_exit_by_id,
      subgraph_entry_by_id,
      positioned_nodes,
      positioned_by_id,
      node_horizontal_by_id,
      enable_target_boundary_ports,
      preserve_assigned_endpoint_ports,
      enhanced_horizontal_state_flow,
    },
  )

  @layout_engine_graph_finalize_core.finalize_positioned_graph(
    padding, max_right, max_bottom, positioned_nodes, positioned_edges, positioned_groups,
  )
}
