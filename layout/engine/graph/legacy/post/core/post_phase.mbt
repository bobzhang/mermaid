///|
/// Runs legacy post-placement phases: subgraph overrides, grouping, routing, and finalization.
pub fn finalize_legacy_layout_from_placement(
  graph : MermaidGraph,
  setup_state : LegacyLayoutSetupState,
  placement_state : LegacyPlacementState,
  use_subgraph_redirects : Bool,
  enable_target_boundary_ports : Bool,
  preserve_assigned_endpoint_ports : Bool,
) -> PositionedGraph {
  let subgraph_entry_by_id = setup_state.subgraph_entry_by_id()
  let subgraph_exit_by_id = setup_state.subgraph_exit_by_id()
  let padding = setup_state.padding()
  let node_spacing = setup_state.node_spacing()
  let layer_spacing = setup_state.layer_spacing()
  let horizontal = setup_state.horizontal()
  let reverse = setup_state.reverse()
  let state_graph = setup_state.state_graph()
  let class_or_er_graph = setup_state.class_or_er_graph()
  let enhanced_horizontal_state_flow = setup_state.enhanced_horizontal_state_flow()

  let positioned_nodes = placement_state.positioned_nodes()
  let positioned_by_id = placement_state.positioned_by_id()

  let positioned_index_by_id : Map[String, Int] = {}
  for i, node in positioned_nodes {
    positioned_index_by_id[node.id] = i
  }

  let node_horizontal_by_id : Map[String, Bool] = {}
  if state_graph {
    @layout_engine_graph_group_core.apply_subgraph_direction_overrides(
      graph.subgraphs,
      horizontal,
      reverse,
      false,
      horizontal,
      reverse,
      node_spacing,
      layer_spacing,
      positioned_nodes,
      positioned_index_by_id,
      node_horizontal_by_id,
    )
  }

  let mut max_right = padding
  let mut max_bottom = padding
  for node in positioned_nodes {
    positioned_by_id[node.id] = node
    max_right = max_right.max(node.x + node.width / 2)
    max_bottom = max_bottom.max(node.y + node.height / 2)
  }

  let positioned_groups = @layout_engine_graph_group_core.build_legacy_positioned_groups(
    graph, padding, horizontal, reverse, state_graph, node_spacing, layer_spacing,
    positioned_nodes, positioned_by_id, positioned_index_by_id,
  )

  let positioned_edges = @layout_engine_graph_routing_core.route_legacy_positioned_edges(
    graph, state_graph, class_or_er_graph, horizontal, layer_spacing, node_spacing,
    use_subgraph_redirects, subgraph_exit_by_id, subgraph_entry_by_id, positioned_nodes,
    positioned_by_id, node_horizontal_by_id, enable_target_boundary_ports, preserve_assigned_endpoint_ports,
    enhanced_horizontal_state_flow,
  )

  @layout_engine_graph_finalize_core.finalize_positioned_graph(
    padding, max_right, max_bottom, positioned_nodes, positioned_edges, positioned_groups,
  )
}
