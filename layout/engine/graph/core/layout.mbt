///|
fn layout_graph_legacy_with_subgraph_redirects(
  graph : MermaidGraph,
  options : RenderOptions,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
  layout_engine : LayoutEngine,
) -> PositionedGraph {
  if is_sequence_graph(graph) {
    return @layout_engine_sequence_core.layout_sequence_graph(graph, options)
  }

  let base_padding = resolve_padding(options)
  let base_node_spacing = resolve_node_spacing(options)
  let base_layer_spacing = resolve_layer_spacing(options)
  let enable_target_boundary_ports = layout_engine is DagreParity
  let preserve_assigned_endpoint_ports = layout_engine is DagreParity
  let horizontal = layout_direction_is_horizontal(graph.direction)
  let reverse = layout_direction_is_reverse(graph.direction)
  let state_graph = is_state_graph(graph)
  let class_or_er_graph = is_class_or_er_graph(graph)
  let flat_state_graph = state_graph &&
    !horizontal &&
    graph.subgraphs.length() == 0

  let graph_inputs = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, use_subgraph_redirects,
  )
  let subgraph_entry_by_id = graph_inputs.subgraph_entry_by_id
  let subgraph_exit_by_id = graph_inputs.subgraph_exit_by_id
  let nodes_in_order = reorder_nodes_for_flow_layout(
    graph_inputs.nodes_in_order,
    graph.edges,
  )
  let enhanced_horizontal_state_flow = state_graph &&
    horizontal &&
    !compact_fanin &&
    use_enhanced_horizontal_state_flow_lanes(nodes_in_order)
  let padding = match options.padding {
    Some(_) => base_padding
    None => if enhanced_horizontal_state_flow { 10 } else { base_padding }
  }
  let node_spacing = if state_graph && horizontal && !compact_fanin {
    resolve_horizontal_state_node_spacing(
      options, nodes_in_order, base_node_spacing,
    )
  } else {
    base_node_spacing
  }
  let layer_spacing = base_layer_spacing
  let lane_state = compute_legacy_lane_state(
    graph, nodes_in_order, state_graph, class_or_er_graph, horizontal, compact_fanin,
    enhanced_horizontal_state_flow, flat_state_graph,
  )
  let state_lane_by_node_id = lane_state.state_lane_by_node_id
  let state_label_y_offset_by_node_id = lane_state.state_label_y_offset_by_node_id
  let flow_rank_by_node_id = lane_state.flow_rank_by_node_id
  let flow_lane_by_node_id = lane_state.flow_lane_by_node_id
  let flow_label_y_offset_by_rank = lane_state.flow_label_y_offset_by_rank
  let refined_horizontal_non_state_flow = lane_state.refined_horizontal_non_state_flow
  let refined_horizontal_non_state_labeled_cycle_flow = lane_state.refined_horizontal_non_state_labeled_cycle_flow
  let horizontal_cycle_non_state_flow = lane_state.horizontal_cycle_non_state_flow
  let flow_max_rank = lane_state.flow_max_rank

  let placement_state = compute_legacy_node_placement_state(
    graph, nodes_in_order, reverse, horizontal, state_graph, flat_state_graph, compact_fanin,
    enhanced_horizontal_state_flow, refined_horizontal_non_state_flow, refined_horizontal_non_state_labeled_cycle_flow,
    horizontal_cycle_non_state_flow, use_subgraph_redirects, subgraph_entry_by_id,
    subgraph_exit_by_id, flow_max_rank, flow_rank_by_node_id, flow_lane_by_node_id,
    flow_label_y_offset_by_rank, state_lane_by_node_id, state_label_y_offset_by_node_id,
    padding, node_spacing, layer_spacing,
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
    apply_subgraph_direction_overrides(
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

  max_right = padding
  max_bottom = padding
  for node in positioned_nodes {
    positioned_by_id[node.id] = node
    max_right = max_right.max(node.x + node.width / 2)
    max_bottom = max_bottom.max(node.y + node.height / 2)
  }

  let positioned_groups = build_legacy_positioned_groups(
    graph, padding, horizontal, reverse, state_graph, node_spacing, layer_spacing,
    positioned_nodes, positioned_by_id, positioned_index_by_id,
  )

  let positioned_edges = route_legacy_positioned_edges(
    graph, state_graph, class_or_er_graph, horizontal, layer_spacing, node_spacing,
    use_subgraph_redirects, subgraph_exit_by_id, subgraph_entry_by_id, positioned_nodes,
    positioned_by_id, node_horizontal_by_id, enable_target_boundary_ports, preserve_assigned_endpoint_ports,
    enhanced_horizontal_state_flow,
  )

  finalize_positioned_graph(
    padding, max_right, max_bottom, positioned_nodes, positioned_edges, positioned_groups,
  )
}
