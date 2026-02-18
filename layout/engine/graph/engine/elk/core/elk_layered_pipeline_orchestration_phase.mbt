///|
priv struct ElkLayeredRankPhaseState {
  rank_seed_strategy : ElkLayeredRankSeedStrategy
  rank_seed_state : ElkLayeredRankSeedState
  rank_node_ids_by_rank : Map[Int, Array[String]]
}

///|
fn run_elk_layered_rank_phase(
  setup_state : ElkLayeredSetupState,
) -> ElkLayeredRankPhaseState {
  let graph = setup_state.graph
  let use_subgraph_redirects = setup_state.use_subgraph_redirects
  let subgraph_entry_by_id = setup_state.subgraph_entry_by_id
  let subgraph_exit_by_id = setup_state.subgraph_exit_by_id
  let nodes_in_order = setup_state.nodes_in_order
  let base_order_index_by_node_id = setup_state.base_order_index_by_node_id
  let node_ids_in_order = setup_state.node_ids_in_order
  let horizontal = setup_state.horizontal
  let default_rank_seed_strategy = select_elk_layered_rank_seed_strategy(graph)
  let (rank_seed_strategy, rank_seed_state) = if default_rank_seed_strategy
    is LegacyLaneSeed {
    let legacy_state = build_elk_layered_rank_seed_state(
      graph,
      LegacyLaneSeed,
      use_subgraph_redirects,
      subgraph_entry_by_id,
      subgraph_exit_by_id,
      nodes_in_order,
      node_ids_in_order,
      base_order_index_by_node_id,
      horizontal,
      setup_state.compact_fanin,
    )
    let native_state = build_elk_layered_rank_seed_state(
      graph,
      NativeFeedback,
      use_subgraph_redirects,
      subgraph_entry_by_id,
      subgraph_exit_by_id,
      nodes_in_order,
      node_ids_in_order,
      base_order_index_by_node_id,
      horizontal,
      setup_state.compact_fanin,
    )
    select_large_graph_rank_seed_state_by_score(
      graph, legacy_state, native_state, nodes_in_order, base_order_index_by_node_id,
    )
  } else {
    (
      NativeFeedback,
      build_elk_layered_rank_seed_state(
        graph,
        NativeFeedback,
        use_subgraph_redirects,
        subgraph_entry_by_id,
        subgraph_exit_by_id,
        nodes_in_order,
        node_ids_in_order,
        base_order_index_by_node_id,
        horizontal,
        setup_state.compact_fanin,
      ),
    )
  }
  let rank_order_strategy = select_elk_layered_rank_order_strategy(
    graph, rank_seed_strategy,
  )
  let base_rank_node_ids_by_rank = build_rank_node_ids_by_lane(
    nodes_in_order,
    rank_seed_state.rank_by_node_id,
    rank_seed_state.lane_by_node_id,
    base_order_index_by_node_id,
    rank_seed_state.max_rank,
  )
  let rank_node_ids_by_rank = build_rank_node_ids_by_rank_for_order_strategy(
    rank_order_strategy,
    graph,
    base_rank_node_ids_by_rank,
    rank_seed_state.rank_by_node_id,
    rank_seed_state.max_rank,
    rank_seed_state.order_index_by_node_id,
    rank_seed_state.successors_by_node_id,
    rank_seed_state.predecessors_by_node_id,
  )
  { rank_seed_strategy, rank_seed_state, rank_node_ids_by_rank }
}

///|
priv struct ElkLayeredPlacementState {
  positioned_nodes : Array[PositionedNode]
  positioned_by_id : Map[String, PositionedNode]
  node_horizontal_by_id : Map[String, Bool]
  max_right : Int
  max_bottom : Int
}

///|
fn run_elk_layered_legacy_compatible_placement_phase(
  setup_state : ElkLayeredSetupState,
) -> ElkLayeredPlacementState {
  let legacy_setup_state = @layout_engine_graph_legacy_setup_core.build_legacy_layout_setup(
    setup_state.graph,
    setup_state.options,
    setup_state.use_subgraph_redirects,
    setup_state.compact_fanin,
  )
  let legacy_placement_state = @layout_engine_graph_placement_core.run_legacy_placement_phase(
    setup_state.graph,
    legacy_setup_state,
    setup_state.use_subgraph_redirects,
    setup_state.compact_fanin,
  )
  let positioned_nodes = legacy_placement_state.positioned_nodes
  let positioned_by_id = legacy_placement_state.positioned_by_id
  let node_horizontal_by_id = build_node_horizontal_by_id(
    positioned_nodes,
    setup_state.horizontal,
  )
  let (max_right, max_bottom) = positioned_nodes_layout_extent(
    positioned_nodes,
    legacy_setup_state.padding,
  )
  {
    positioned_nodes,
    positioned_by_id,
    node_horizontal_by_id,
    max_right,
    max_bottom,
  }
}

///|
fn run_elk_layered_node_placement_phase(
  setup_state : ElkLayeredSetupState,
  rank_phase_state : ElkLayeredRankPhaseState,
  node_size_state : ElkLayeredNodeSizeState,
  spacing_state : ElkLayeredSpacingState,
) -> ElkLayeredPlacementState {
  let rank_seed_strategy = rank_phase_state.rank_seed_strategy
  if rank_seed_strategy is LegacyLaneSeed {
    return run_elk_layered_legacy_compatible_placement_phase(setup_state)
  }

  let graph = setup_state.graph
  let nodes_in_order = setup_state.nodes_in_order
  let horizontal = setup_state.horizontal
  let reverse = setup_state.reverse
  let use_subgraph_redirects = setup_state.use_subgraph_redirects
  let subgraph_entry_by_id = setup_state.subgraph_entry_by_id
  let subgraph_exit_by_id = setup_state.subgraph_exit_by_id
  let rank_seed_state = rank_phase_state.rank_seed_state
  let rank_node_ids_by_rank = rank_phase_state.rank_node_ids_by_rank
  let rank_by_node_id = rank_seed_state.rank_by_node_id
  let max_rank = rank_seed_state.max_rank
  let lane_by_node_id = rank_seed_state.lane_by_node_id
  let successors_by_node_id = rank_seed_state.successors_by_node_id
  let predecessors_by_node_id = rank_seed_state.predecessors_by_node_id
  let padding = spacing_state.padding
  let minor_step = spacing_state.minor_step
  let max_rank_minor_span = spacing_state.max_rank_minor_span
  let base_major_step = spacing_state.major_step
  let width_by_node_id = node_size_state.width_by_node_id
  let height_by_node_id = node_size_state.height_by_node_id
  let minor_placement_strategy = select_elk_layered_minor_placement_strategy(
    rank_seed_strategy,
  )
  let minor_coord_by_node_id = build_minor_coord_by_strategy(
    minor_placement_strategy, rank_node_ids_by_rank, max_rank, lane_by_node_id, padding,
    minor_step, max_rank_minor_span, predecessors_by_node_id, successors_by_node_id,
    horizontal, width_by_node_id, height_by_node_id,
  )
  let rank_pair_label_major_gap = build_rank_pair_label_major_gap(
    graph, use_subgraph_redirects, subgraph_entry_by_id, subgraph_exit_by_id, rank_by_node_id,
    horizontal,
  )
  let major_center_by_rank = build_major_center_by_rank(
    max_rank, reverse, padding, base_major_step, rank_pair_label_major_gap,
  )
  let (x_by_node_id, y_by_node_id) = build_axis_coords_by_node_id(
    rank_node_ids_by_rank, max_rank, major_center_by_rank, minor_coord_by_node_id,
    padding, horizontal,
  )
  let (positioned_nodes, positioned_by_id) = build_positioned_nodes_from_axis_coords(
    graph, nodes_in_order, width_by_node_id, height_by_node_id, x_by_node_id, y_by_node_id,
    padding,
  )
  let node_horizontal_by_id = build_node_horizontal_by_id(
    positioned_nodes, horizontal,
  )
  let (max_right, max_bottom) = positioned_nodes_layout_extent(
    positioned_nodes, padding,
  )
  {
    positioned_nodes,
    positioned_by_id,
    node_horizontal_by_id,
    max_right,
    max_bottom,
  }
}

///|
fn run_elk_layered_finalize_phase(
  setup_state : ElkLayeredSetupState,
  spacing_state : ElkLayeredSpacingState,
  placement_state : ElkLayeredPlacementState,
  routing_policy : GraphBackendRoutingPolicy,
) -> PositionedGraph {
  finalize_elk_layered_positioned_graph(
    setup_state.graph,
    spacing_state.padding,
    setup_state.horizontal,
    setup_state.reverse,
    spacing_state.node_spacing,
    spacing_state.layer_spacing,
    setup_state.use_subgraph_redirects,
    setup_state.subgraph_exit_by_id,
    setup_state.subgraph_entry_by_id,
    routing_policy,
    placement_state.positioned_nodes,
    placement_state.positioned_by_id,
    placement_state.node_horizontal_by_id,
    placement_state.max_right,
    placement_state.max_bottom,
  )
}

///|
fn rank_phase_snapshot(
  request : GraphLayoutBackendRequest,
  nodes_in_order : Array[MermaidNode],
  max_rank : Int,
) -> GraphLayoutPhaseSnapshot {
  let rank_layer_count = if nodes_in_order.length() == 0 {
    0
  } else {
    max_rank + 1
  }
  {
    phase: "rank",
    node_count: nodes_in_order.length(),
    edge_count: request.graph.edges.length(),
    group_count: request.graph.subgraphs.length(),
    rank_layer_count,
    width: 0,
    height: 0,
  }
}

///|
/// Runs the ELK layered flow pipeline for non-state flowcharts.
fn run_elk_layered_flow_backend(
  request : GraphLayoutBackendRequest,
  routing_policy : GraphBackendRoutingPolicy,
) -> GraphLayoutBackendResult {
  let setup_state = run_elk_layered_setup_phase(request)
  let options = setup_state.options
  let nodes_in_order = setup_state.nodes_in_order
  let rank_phase_state = run_elk_layered_rank_phase(setup_state)
  let rank_seed_state = rank_phase_state.rank_seed_state
  let max_rank = rank_seed_state.max_rank
  let rank_node_ids_by_rank = rank_phase_state.rank_node_ids_by_rank

  let node_size_state = build_elk_layered_node_size_state(nodes_in_order)
  let max_rank_size = compute_max_rank_size(rank_node_ids_by_rank, max_rank)
  let spacing_state = run_elk_layered_spacing_phase(
    options,
    setup_state.horizontal,
    max_rank_size,
    node_size_state,
  )
  let placement_state = run_elk_layered_node_placement_phase(
    setup_state, rank_phase_state, node_size_state, spacing_state,
  )
  let positioned_graph = run_elk_layered_finalize_phase(
    setup_state, spacing_state, placement_state, routing_policy,
  )
  let phase_snapshots = [
    setup_phase_snapshot(request, nodes_in_order),
    rank_phase_snapshot(request, nodes_in_order, max_rank),
    placement_phase_snapshot(request, placement_state.positioned_nodes),
    final_phase_snapshot(positioned_graph),
  ]
  { positioned_graph, phase_snapshots }
}
