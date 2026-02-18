///|
/// Rank-phase trace payload for ELK layered layout.
pub(all) struct ElkLayeredRankTrace {
  rank_seed_strategy : String
  rank_seed_rank_by_node_id : Map[String, Int]
  rank_seed_order_index_by_node_id : Map[String, Int]
  rank_seed_oriented_edges : Array[(String, String)]
  rank_seed_layers : Array[Array[String]]
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
fn rank_seed_strategy_tag(
  rank_seed_strategy : ElkLayeredRankSeedStrategy,
) -> String {
  match rank_seed_strategy {
    LegacyLaneSeed => "legacy-lane-seed"
    NativeFeedback => "native-feedback"
  }
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
  let rank_phase_state = run_elk_layered_rank_phase(setup_state)
  let rank_seed_state = rank_phase_state.rank_seed_state
  let rank_seed_layers_by_rank = build_rank_node_ids_by_lane(
    setup_state.nodes_in_order,
    rank_seed_state.rank_by_node_id,
    rank_seed_state.lane_by_node_id,
    setup_state.base_order_index_by_node_id,
    rank_seed_state.max_rank,
  )
  Some({
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
    rank_layers: rank_layers_from_rank_map(
      rank_phase_state.rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
  })
}
