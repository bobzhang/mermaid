///|
priv enum ElkLayeredRankSeedStrategy {
  LegacyLaneSeed
  NativeFeedback
}

///|
priv struct ElkLayeredRankSeedState {
  rank_by_node_id : Map[String, Int]
  max_rank : Int
  lane_by_node_id : Map[String, Int]
  order_index_by_node_id : Map[String, Int]
  successors_by_node_id : Map[String, Array[String]]
  predecessors_by_node_id : Map[String, Array[String]]
}

///|
fn select_elk_layered_rank_seed_strategy(
  graph : MermaidGraph,
) -> ElkLayeredRankSeedStrategy {
  if graph.nodes.length() > 16 || graph.edges.length() > 30 {
    LegacyLaneSeed
  } else {
    NativeFeedback
  }
}

///|
fn build_legacy_lane_rank_seed_state(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  subgraph_entry_by_id : Map[String, String],
  subgraph_exit_by_id : Map[String, String],
  nodes_in_order : Array[MermaidNode],
  node_ids_in_order : Array[String],
  base_order_index_by_node_id : Map[String, Int],
  horizontal : Bool,
  compact_fanin : Bool,
) -> ElkLayeredRankSeedState {
  let legacy_lane_state = @layout_engine_graph_lane_core.compute_legacy_lane_state(
    graph, nodes_in_order, false, false, horizontal, compact_fanin, false, false,
    false,
  )
  let rank_by_node_id = legacy_lane_state.flow_rank_by_node_id
  let max_rank = legacy_lane_state.flow_max_rank
  let lane_by_node_id = legacy_lane_state.flow_lane_by_node_id
  let order_index_by_node_id = base_order_index_by_node_id
  let (successors_by_node_id, predecessors_by_node_id) = build_layered_neighbor_state_from_rank_seed(
    graph, use_subgraph_redirects, subgraph_entry_by_id, subgraph_exit_by_id, node_ids_in_order,
    rank_by_node_id, order_index_by_node_id,
  )
  {
    rank_by_node_id,
    max_rank,
    lane_by_node_id,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  }
}

///|
fn build_native_feedback_rank_seed_state(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  subgraph_entry_by_id : Map[String, String],
  subgraph_exit_by_id : Map[String, String],
  nodes_in_order : Array[MermaidNode],
) -> ElkLayeredRankSeedState {
  let (
    rank_by_node_id,
    max_rank,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  ) = build_layered_rank_state(
    graph, use_subgraph_redirects, subgraph_entry_by_id, subgraph_exit_by_id, nodes_in_order,
  )
  {
    rank_by_node_id,
    max_rank,
    lane_by_node_id: order_index_by_node_id,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  }
}

///|
fn build_elk_layered_rank_seed_state(
  graph : MermaidGraph,
  rank_seed_strategy : ElkLayeredRankSeedStrategy,
  use_subgraph_redirects : Bool,
  subgraph_entry_by_id : Map[String, String],
  subgraph_exit_by_id : Map[String, String],
  nodes_in_order : Array[MermaidNode],
  node_ids_in_order : Array[String],
  base_order_index_by_node_id : Map[String, Int],
  horizontal : Bool,
  compact_fanin : Bool,
) -> ElkLayeredRankSeedState {
  match rank_seed_strategy {
    LegacyLaneSeed =>
      build_legacy_lane_rank_seed_state(
        graph, use_subgraph_redirects, subgraph_entry_by_id, subgraph_exit_by_id,
        nodes_in_order, node_ids_in_order, base_order_index_by_node_id, horizontal,
        compact_fanin,
      )
    NativeFeedback =>
      build_native_feedback_rank_seed_state(
        graph, use_subgraph_redirects, subgraph_entry_by_id, subgraph_exit_by_id,
        nodes_in_order,
      )
  }
}

///|
priv enum ElkLayeredRankOrderStrategy {
  SeedOrderOnly
  OptimizedSeedOrder
  OptimizedSeedWithVirtualCandidate
}

///|
priv struct ElkLayeredRankOrderDebugState {
  optimized_seed_rank_node_ids_by_rank : Map[Int, Array[String]]
  optimized_seed_crossing_score : Int
  virtual_candidate_rank_node_ids_by_rank : Map[Int, Array[String]]
  virtual_candidate_crossing_score : Int
  selected_rank_node_ids_by_rank : Map[Int, Array[String]]
  selected_crossing_score : Int
  selected_source : String
}

///|
fn select_elk_layered_rank_order_strategy(
  graph : MermaidGraph,
  rank_seed_strategy : ElkLayeredRankSeedStrategy,
) -> ElkLayeredRankOrderStrategy {
  if rank_seed_strategy is LegacyLaneSeed {
    SeedOrderOnly
  } else if graph.nodes.length() <= 16 && graph.edges.length() <= 30 {
    OptimizedSeedWithVirtualCandidate
  } else {
    OptimizedSeedOrder
  }
}

///|
priv enum ElkLayeredMinorPlacementStrategy {
  LaneSeeded
  RelaxedNeighbor
}

///|
fn select_elk_layered_minor_placement_strategy(
  rank_seed_strategy : ElkLayeredRankSeedStrategy,
) -> ElkLayeredMinorPlacementStrategy {
  if rank_seed_strategy is LegacyLaneSeed {
    LaneSeeded
  } else {
    RelaxedNeighbor
  }
}

///|
fn build_minor_coord_by_strategy(
  strategy : ElkLayeredMinorPlacementStrategy,
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  lane_by_node_id : Map[String, Int],
  padding : Int,
  minor_step : Int,
  max_rank_minor_span : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Map[String, Int] {
  match strategy {
    LaneSeeded =>
      build_minor_coord_by_lane_seed(
        rank_node_ids_by_rank, max_rank, lane_by_node_id, padding, minor_step,
      )
    RelaxedNeighbor =>
      build_minor_coord_by_node_id(
        rank_node_ids_by_rank, max_rank, padding, minor_step, max_rank_minor_span,
        predecessors_by_node_id, successors_by_node_id, horizontal, width_by_node_id,
        height_by_node_id,
      )
  }
}

///|
fn build_rank_node_ids_by_rank_for_order_strategy_with_debug(
  strategy : ElkLayeredRankOrderStrategy,
  graph : MermaidGraph,
  base_rank_node_ids_by_rank : Map[Int, Array[String]],
  rank_by_node_id : Map[String, Int],
  max_rank : Int,
  order_index_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
  predecessors_by_node_id : Map[String, Array[String]],
) -> (Map[Int, Array[String]], ElkLayeredRankOrderDebugState) {
  let optimized_base_rank_node_ids_by_rank = build_optimized_rank_node_ids_by_rank(
    base_rank_node_ids_by_rank,
    max_rank,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    rank_by_node_id,
    rank_by_node_id.length(),
    graph.edges.length(),
  )
  let optimized_seed_crossing_score = rank_order_crossing_score(
    optimized_base_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  match strategy {
    SeedOrderOnly => {
      let selected_crossing_score = rank_order_crossing_score(
        base_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
      )
      (
        base_rank_node_ids_by_rank,
        {
          optimized_seed_rank_node_ids_by_rank: optimized_base_rank_node_ids_by_rank,
          optimized_seed_crossing_score,
          virtual_candidate_rank_node_ids_by_rank: optimized_base_rank_node_ids_by_rank,
          virtual_candidate_crossing_score: optimized_seed_crossing_score,
          selected_rank_node_ids_by_rank: base_rank_node_ids_by_rank,
          selected_crossing_score,
          selected_source: "seed-order",
        },
      )
    }
    OptimizedSeedOrder =>
      (
        optimized_base_rank_node_ids_by_rank,
        {
          optimized_seed_rank_node_ids_by_rank: optimized_base_rank_node_ids_by_rank,
          optimized_seed_crossing_score,
          virtual_candidate_rank_node_ids_by_rank: optimized_base_rank_node_ids_by_rank,
          virtual_candidate_crossing_score: optimized_seed_crossing_score,
          selected_rank_node_ids_by_rank: optimized_base_rank_node_ids_by_rank,
          selected_crossing_score: optimized_seed_crossing_score,
          selected_source: "optimized-seed",
        },
      )
    OptimizedSeedWithVirtualCandidate => {
      let virtual_ordering_state = build_virtual_ordering_state(
        base_rank_node_ids_by_rank, rank_by_node_id, max_rank, order_index_by_node_id,
        successors_by_node_id,
      )
      let optimized_virtual_rank_node_ids_by_rank = build_optimized_rank_node_ids_by_rank(
        virtual_ordering_state.rank_node_ids_by_rank,
        max_rank,
        virtual_ordering_state.predecessors_by_node_id,
        virtual_ordering_state.successors_by_node_id,
        virtual_ordering_state.order_index_by_node_id,
        virtual_ordering_state.rank_by_node_id,
        virtual_ordering_state.rank_by_node_id.length(),
        graph.edges.length(),
      )
      let real_virtual_rank_node_ids_by_rank = filter_real_rank_node_ids_by_rank(
        optimized_virtual_rank_node_ids_by_rank,
        max_rank,
        virtual_ordering_state.virtual_by_node_id,
      )
      let virtual_candidate_crossing_score = rank_order_crossing_score(
        real_virtual_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
      )
      let selected_rank_node_ids_by_rank = select_lower_crossing_rank_order(
        optimized_base_rank_node_ids_by_rank, real_virtual_rank_node_ids_by_rank,
        max_rank, rank_by_node_id, successors_by_node_id,
      )
      let select_virtual_candidate = virtual_candidate_crossing_score <=
        optimized_seed_crossing_score
      (
        selected_rank_node_ids_by_rank,
        {
          optimized_seed_rank_node_ids_by_rank: optimized_base_rank_node_ids_by_rank,
          optimized_seed_crossing_score,
          virtual_candidate_rank_node_ids_by_rank: real_virtual_rank_node_ids_by_rank,
          virtual_candidate_crossing_score,
          selected_rank_node_ids_by_rank,
          selected_crossing_score: if select_virtual_candidate {
            virtual_candidate_crossing_score
          } else {
            optimized_seed_crossing_score
          },
          selected_source: if select_virtual_candidate {
            "virtual"
          } else {
            "optimized-seed"
          },
        },
      )
    }
  }
}

///|
fn select_large_graph_rank_seed_state_by_score(
  graph : MermaidGraph,
  legacy_state : ElkLayeredRankSeedState,
  native_state : ElkLayeredRankSeedState,
  nodes_in_order : Array[MermaidNode],
  base_order_index_by_node_id : Map[String, Int],
) -> (ElkLayeredRankSeedStrategy, ElkLayeredRankSeedState) {
  // Large-graph native seeding is currently less stable than legacy lane
  // seeding on parity stress fixtures; keep large graphs on legacy ranks
  // until native ranking has feature-complete parity.
  let _ = graph
  let _ = native_state
  let _ = nodes_in_order
  let _ = base_order_index_by_node_id
  (LegacyLaneSeed, legacy_state)
}
