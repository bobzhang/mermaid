///|
/// Rank-phase trace payload for ELK layered layout.
pub(all) struct ElkLayeredRankTrace {
  rank_input_node_ids_in_order : Array[String]
  rank_input_resolved_edges : Array[(String, String)]
  rank_feedback_oriented_edges : Array[(String, String)]
  rank_seed_strategy : String
  rank_seed_rank_by_node_id : Map[String, Int]
  rank_seed_order_index_by_node_id : Map[String, Int]
  rank_seed_oriented_edges : Array[(String, String)]
  rank_seed_layers : Array[Array[String]]
  rank_seed_virtual_node_ids : Array[String]
  rank_seed_virtual_edges : Array[(String, String)]
  rank_seed_virtual_ports : Array[(String, Int, String)]
  rank_seed_virtual_layers : Array[Array[String]]
  rank_order_strategy : String
  rank_order_optimized_seed_layers : Array[Array[String]]
  rank_order_optimized_seed_crossings : Int
  rank_order_optimized_reversed_seed_layers : Array[Array[String]]
  rank_order_optimized_reversed_seed_crossings : Int
  rank_order_virtual_candidate_layers : Array[Array[String]]
  rank_order_virtual_candidate_crossings : Int
  rank_order_selected_virtual_node_ids : Array[String]
  rank_order_selected_virtual_edges : Array[(String, String)]
  rank_order_selected_virtual_ports : Array[(String, Int, String)]
  rank_order_selected_virtual_layers : Array[Array[String]]
  rank_order_selected_layers : Array[Array[String]]
  rank_order_selected_crossings : Int
  rank_order_selected_source : String
  rank_layers : Array[Array[String]]
}

///|
fn rank_layers_from_rank_map(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
) -> Array[Array[String]] {
  let layers : Array[Array[String]] = []
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) => layers.push(node_ids.copy())
      None => layers.push([])
    }
  }
  layers
}

///|
fn oriented_edges_from_successors(
  successors_by_node_id : Map[String, Array[String]],
) -> Array[(String, String)] {
  let oriented_edges : Array[(String, String)] = []
  for source_id, successors in successors_by_node_id {
    for target_id in successors {
      oriented_edges.push((source_id, target_id))
    }
  }
  oriented_edges
}

///|
fn ordered_ports_from_rank_layers(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  successors_by_node_id : Map[String, Array[String]],
) -> Array[(String, Int, String)] {
  let ordered_ports : Array[(String, Int, String)] = []
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for source_id in node_ids {
          match successors_by_node_id.get(source_id) {
            Some(target_ids) =>
              for slot, target_id in target_ids {
                ordered_ports.push((source_id, slot, target_id))
              }
            None => ()
          }
        }
      None => ()
    }
  }
  ordered_ports
}

///|
fn rank_seed_strategy_tag(
  rank_seed_strategy : ElkLayeredRankSeedStrategy,
) -> String {
  match rank_seed_strategy {
    LegacyLaneSeed => "legacy-lane-seed"
    NativeFeedback => "native-feedback"
  }
}

///|
fn rank_order_strategy_tag(
  rank_order_strategy : ElkLayeredRankOrderStrategy,
) -> String {
  match rank_order_strategy {
    SeedOrderOnly => "seed-order-only"
    OptimizedSeedOrder => "optimized-seed-order"
    OptimizedSeedWithVirtualCandidate => "optimized-seed-with-virtual-candidate"
  }
}

///|
fn collect_sorted_virtual_node_ids(
  virtual_by_node_id : Map[String, Bool],
) -> Array[String] {
  let virtual_node_ids : Array[String] = []
  for node_id, is_virtual in virtual_by_node_id {
    if is_virtual {
      virtual_node_ids.push(node_id)
    }
  }
  virtual_node_ids.sort()
  virtual_node_ids
}

///|
/// Collects ELK layered rank-phase trace for flowchart graphs.
pub fn collect_elk_layered_rank_trace(
  request : GraphLayoutBackendRequest,
) -> ElkLayeredRankTrace? {
  if !elk_graph_supports_layered_pipeline(request.graph) {
    return None
  }
  let use_legacy_seed_placement = select_elk_layered_rank_seed_strategy(
      request.graph,
    )
    is LegacyLaneSeed
  let tuned_request : GraphLayoutBackendRequest = {
    graph: request.graph,
    options: if use_legacy_seed_placement {
      request.options
    } else {
      derive_elk_render_options(request.graph, request.options)
    },
    use_subgraph_redirects: request.use_subgraph_redirects,
    compact_fanin: request.compact_fanin,
  }
  let setup_state = run_elk_layered_setup_phase(tuned_request)
  let rank_input_resolved_edges = collect_visible_resolved_edges(
    setup_state.graph,
    setup_state.use_subgraph_redirects,
    setup_state.subgraph_entry_by_id,
    setup_state.subgraph_exit_by_id,
    setup_state.node_ids_in_order,
  )
  let feedback_orientation_state = compute_feedback_order_orientation_state(
    setup_state.node_ids_in_order,
    rank_input_resolved_edges,
    setup_state.base_order_index_by_node_id,
  )
  let rank_phase_state = run_elk_layered_rank_phase(setup_state)
  let rank_seed_state = rank_phase_state.rank_seed_state
  let rank_order_debug_state = rank_phase_state.rank_order_debug_state
  let selected_virtual_ordering_state = build_virtual_ordering_state(
    rank_order_debug_state.selected_rank_node_ids_by_rank,
    rank_seed_state.rank_by_node_id,
    rank_seed_state.max_rank,
    rank_seed_state.order_index_by_node_id,
    rank_seed_state.successors_by_node_id,
  )
  let rank_seed_layers_by_rank = build_rank_node_ids_by_lane(
    setup_state.nodes_in_order,
    rank_seed_state.rank_by_node_id,
    rank_seed_state.lane_by_node_id,
    setup_state.base_order_index_by_node_id,
    rank_seed_state.max_rank,
  )
  let seed_virtual_ordering_state = build_virtual_ordering_state(
    rank_seed_layers_by_rank,
    rank_seed_state.rank_by_node_id,
    rank_seed_state.max_rank,
    rank_seed_state.order_index_by_node_id,
    rank_seed_state.successors_by_node_id,
  )
  Some({
    rank_input_node_ids_in_order: setup_state.node_ids_in_order.copy(),
    rank_input_resolved_edges,
    rank_feedback_oriented_edges: feedback_orientation_state.oriented_edges.copy(),
    rank_seed_strategy: rank_seed_strategy_tag(
      rank_phase_state.rank_seed_strategy,
    ),
    rank_seed_rank_by_node_id: rank_seed_state.rank_by_node_id,
    rank_seed_order_index_by_node_id: rank_seed_state.order_index_by_node_id,
    rank_seed_oriented_edges: oriented_edges_from_successors(
      rank_seed_state.successors_by_node_id,
    ),
    rank_seed_layers: rank_layers_from_rank_map(
      rank_seed_layers_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_seed_virtual_node_ids: collect_sorted_virtual_node_ids(
      seed_virtual_ordering_state.virtual_by_node_id,
    ),
    rank_seed_virtual_edges: oriented_edges_from_successors(
      seed_virtual_ordering_state.successors_by_node_id,
    ),
    rank_seed_virtual_ports: ordered_ports_from_rank_layers(
      seed_virtual_ordering_state.rank_node_ids_by_rank,
      rank_seed_state.max_rank,
      seed_virtual_ordering_state.successors_by_node_id,
    ),
    rank_seed_virtual_layers: rank_layers_from_rank_map(
      seed_virtual_ordering_state.rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_order_strategy: rank_order_strategy_tag(
      rank_phase_state.rank_order_strategy,
    ),
    rank_order_optimized_seed_layers: rank_layers_from_rank_map(
      rank_order_debug_state.optimized_seed_rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_order_optimized_seed_crossings: rank_order_debug_state.optimized_seed_crossing_score,
    rank_order_optimized_reversed_seed_layers: rank_layers_from_rank_map(
      rank_order_debug_state.optimized_reversed_seed_rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_order_optimized_reversed_seed_crossings: rank_order_debug_state.optimized_reversed_seed_crossing_score,
    rank_order_virtual_candidate_layers: rank_layers_from_rank_map(
      rank_order_debug_state.virtual_candidate_rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_order_virtual_candidate_crossings: rank_order_debug_state.virtual_candidate_crossing_score,
    rank_order_selected_virtual_node_ids: collect_sorted_virtual_node_ids(
      selected_virtual_ordering_state.virtual_by_node_id,
    ),
    rank_order_selected_virtual_edges: oriented_edges_from_successors(
      selected_virtual_ordering_state.successors_by_node_id,
    ),
    rank_order_selected_virtual_ports: ordered_ports_from_rank_layers(
      selected_virtual_ordering_state.rank_node_ids_by_rank,
      rank_seed_state.max_rank,
      selected_virtual_ordering_state.successors_by_node_id,
    ),
    rank_order_selected_virtual_layers: rank_layers_from_rank_map(
      selected_virtual_ordering_state.rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_order_selected_layers: rank_layers_from_rank_map(
      rank_order_debug_state.selected_rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_order_selected_crossings: rank_order_debug_state.selected_crossing_score,
    rank_order_selected_source: rank_order_debug_state.selected_source,
    rank_layers: rank_layers_from_rank_map(
      rank_phase_state.rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
  })
}
