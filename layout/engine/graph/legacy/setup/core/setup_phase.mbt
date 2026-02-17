///|
/// Derived setup state consumed by legacy placement, grouping, and routing phases.
pub(all) struct LegacyLayoutSetupState {
  subgraph_entry_by_id : Map[String, String]
  subgraph_exit_by_id : Map[String, String]
  nodes_in_order : Array[MermaidNode]
  padding : Int
  node_spacing : Int
  layer_spacing : Int
  horizontal : Bool
  reverse : Bool
  state_graph : Bool
  class_or_er_graph : Bool
  flat_state_graph : Bool
  enhanced_horizontal_state_flow : Bool
  lane_state : LegacyLaneState
}

///|
/// Computes shared setup state for the legacy graph layout pipeline.
pub fn build_legacy_layout_setup(
  graph : MermaidGraph,
  options : RenderOptions,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
) -> LegacyLayoutSetupState {
  let base_padding = @layout_engine_graph_internal_core.resolve_padding(options)
  let base_node_spacing = @layout_engine_graph_internal_core.resolve_node_spacing(
    options,
  )
  let layer_spacing = @layout_engine_graph_internal_core.resolve_layer_spacing(
    options,
  )
  let horizontal = @layout_engine_graph_internal_core.layout_direction_is_horizontal(
    graph.direction,
  )
  let reverse = @layout_engine_graph_internal_core.layout_direction_is_reverse(
    graph.direction,
  )
  let state_graph = @layout_engine_graph_internal_core.is_state_graph(graph)
  let class_or_er_graph = @layout_engine_graph_internal_core.is_class_or_er_graph(
    graph,
  )
  let flat_state_graph = state_graph &&
    !horizontal &&
    graph.subgraphs.length() == 0

  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, use_subgraph_redirects,
  )
  let subgraph_entry_by_id = prep_state.subgraph_entry_by_id()
  let subgraph_exit_by_id = prep_state.subgraph_exit_by_id()
  let prepped_nodes_in_order = prep_state.nodes_in_order()
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prepped_nodes_in_order,
    graph.edges,
  )
  let enhanced_horizontal_state_flow = state_graph &&
    horizontal &&
    !compact_fanin &&
    @layout_engine_graph_internal_core.use_enhanced_horizontal_state_flow_lanes(
      nodes_in_order,
    )
  let padding = match options.padding {
    Some(_) => base_padding
    None => if enhanced_horizontal_state_flow { 10 } else { base_padding }
  }
  let node_spacing = if state_graph && horizontal && !compact_fanin {
    @layout_engine_graph_internal_core.resolve_horizontal_state_node_spacing(
      options, nodes_in_order, base_node_spacing,
    )
  } else {
    base_node_spacing
  }
  let lane_state = @layout_engine_graph_lane_core.compute_legacy_lane_state(
    graph, nodes_in_order, state_graph, class_or_er_graph, horizontal, compact_fanin,
    enhanced_horizontal_state_flow, flat_state_graph,
  )

  {
    subgraph_entry_by_id,
    subgraph_exit_by_id,
    nodes_in_order,
    padding,
    node_spacing,
    layer_spacing,
    horizontal,
    reverse,
    state_graph,
    class_or_er_graph,
    flat_state_graph,
    enhanced_horizontal_state_flow,
    lane_state,
  }
}
