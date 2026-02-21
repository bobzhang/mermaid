///|
fn wb_rank_crossings_between(
  left_rank_node_ids : Array[String],
  right_rank_node_ids : Array[String],
  successors_by_node_id : Map[String, Array[String]],
) -> Int {
  let right_position_by_node_id : Map[String, Int] = {}
  let in_right_rank : Map[String, Bool] = {}
  for position, node_id in right_rank_node_ids {
    right_position_by_node_id[node_id] = position
    in_right_rank[node_id] = true
  }
  let mut crossings = 0
  for left_index in 0..<left_rank_node_ids.length() {
    let left_source = left_rank_node_ids[left_index]
    let left_targets : Array[String] = []
    match successors_by_node_id.get(left_source) {
      Some(successors) =>
        for successor_id in successors {
          if in_right_rank.contains(successor_id) {
            left_targets.push(successor_id)
          }
        }
      None => ()
    }
    for right_index in (left_index + 1)..<left_rank_node_ids.length() {
      let right_source = left_rank_node_ids[right_index]
      let right_targets : Array[String] = []
      match successors_by_node_id.get(right_source) {
        Some(successors) =>
          for successor_id in successors {
            if in_right_rank.contains(successor_id) {
              right_targets.push(successor_id)
            }
          }
        None => ()
      }
      for left_target in left_targets {
        for right_target in right_targets {
          let left_pos = option_int_or(
            right_position_by_node_id.get(left_target),
            -1,
          )
          let right_pos = option_int_or(
            right_position_by_node_id.get(right_target),
            -1,
          )
          if left_pos > right_pos {
            crossings += 1
          }
        }
      }
    }
  }
  crossings
}

///|
fn wb_collect_rank_order_edge_segments(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Array[RankOrderEdgeSegment] {
  let rank_position_by_node_id = rank_position_by_node_id(
    rank_node_ids_by_rank, max_rank,
  )
  collect_rank_order_edge_segments_from_rank_positions(
    rank_position_by_node_id, rank_by_node_id, successors_by_node_id,
  )
}

///|
fn wb_global_crossing_count(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Int {
  global_crossing_count_from_segments(
    wb_collect_rank_order_edge_segments(
      rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
    ),
  )
}

///|
test "elk layered default sweep kernel matches explicit kernel" {
  let seed_rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C", "D"],
    2: ["E", "F"],
  }
  let predecessors_by_node_id : Map[String, Array[String]] = {
    "A": [],
    "B": [],
    "C": ["A"],
    "D": ["B"],
    "E": ["D"],
    "F": ["C"],
  }
  let successors_by_node_id : Map[String, Array[String]] = {
    "A": ["C"],
    "B": ["D"],
    "C": ["F"],
    "D": ["E"],
    "E": [],
    "F": [],
  }
  let order_index_by_node_id : Map[String, Int] = {
    "A": 0,
    "B": 1,
    "C": 2,
    "D": 3,
    "E": 4,
    "F": 5,
  }
  let via_wrapper = clone_rank_node_ids_by_rank(seed_rank_node_ids_by_rank, 2)
  let via_explicit = clone_rank_node_ids_by_rank(seed_rank_node_ids_by_rank, 2)
  optimize_rank_order_with_sweep_passes_and_kernel(
    via_wrapper,
    2,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    false,
    3,
    default_crossing_sweep_kernel(),
  )
  optimize_rank_order_with_sweep_passes_and_kernel(
    via_explicit,
    2,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    false,
    3,
    NeighborMeanBidirectional,
  )
  assert_eq(via_wrapper, via_explicit)
}

///|
test "elk layered sweep input entry matches explicit parameter entry" {
  let seed_rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C", "D"],
    2: ["E", "F"],
  }
  let predecessors_by_node_id : Map[String, Array[String]] = {
    "A": [],
    "B": [],
    "C": ["A"],
    "D": ["B"],
    "E": ["D"],
    "F": ["C"],
  }
  let successors_by_node_id : Map[String, Array[String]] = {
    "A": ["C"],
    "B": ["D"],
    "C": ["F"],
    "D": ["E"],
    "E": [],
    "F": [],
  }
  let order_index_by_node_id : Map[String, Int] = {
    "A": 0,
    "B": 1,
    "C": 2,
    "D": 3,
    "E": 4,
    "F": 5,
  }
  let via_parameters = clone_rank_node_ids_by_rank(
    seed_rank_node_ids_by_rank, 2,
  )
  let via_input = clone_rank_node_ids_by_rank(seed_rank_node_ids_by_rank, 2)
  optimize_rank_order_with_sweep_passes_and_kernel(
    via_parameters,
    2,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    false,
    3,
    NeighborMeanBidirectional,
  )
  optimize_rank_order_with_sweep_passes_from_input(
    build_crossing_sweep_input(
      via_input, 2, predecessors_by_node_id, successors_by_node_id, order_index_by_node_id,
      false,
    ),
    3,
    NeighborMeanBidirectional,
  )
  assert_eq(via_parameters, via_input)
}

///|
test "elk layered local refinement wrapper matches explicit kernel sequence" {
  let seed_rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C", "D"],
    2: ["E", "F"],
  }
  let rank_by_node_id : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "C": 1,
    "D": 1,
    "E": 2,
    "F": 2,
  }
  let successors_by_node_id : Map[String, Array[String]] = {
    "A": ["D", "E"],
    "B": ["C", "F"],
    "C": [],
    "D": [],
    "E": [],
    "F": [],
  }
  let config = default_crossing_optimization_config()
  let via_wrapper = clone_rank_node_ids_by_rank(seed_rank_node_ids_by_rank, 2)
  let via_explicit = clone_rank_node_ids_by_rank(seed_rank_node_ids_by_rank, 2)
  apply_crossing_local_refinement_kernels(
    build_crossing_refinement_input(
      via_wrapper, 2, rank_by_node_id, successors_by_node_id, 6, 4,
    ),
    config,
    default_crossing_local_refinement_kernels(),
  )
  apply_crossing_local_refinement_with_kernel(
    build_crossing_refinement_input(
      via_explicit, 2, rank_by_node_id, successors_by_node_id, 6, 4,
    ),
    config,
    AdjacentSwap,
  )
  apply_crossing_local_refinement_with_kernel(
    build_crossing_refinement_input(
      via_explicit, 2, rank_by_node_id, successors_by_node_id, 6, 4,
    ),
    config,
    RankPermutation,
  )
  assert_eq(via_wrapper, via_explicit)
}

///|
test "elk layered order optimization reduces crossing count on bipartite rank pair" {
  let graph = wb_graph(["A", "B", "C", "D"], [
    ("A", "D"),
    ("B", "C"),
    ("A", "C"),
    ("B", "D"),
  ])
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, false,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order,
    graph.edges,
  )
  let base_order_index_by_node_id = build_order_index_by_node_id(nodes_in_order)
  let (
    rank_by_node_id,
    max_rank,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  ) = build_layered_rank_state(
    graph,
    false,
    prep_state.subgraph_entry_by_id,
    prep_state.subgraph_exit_by_id,
    nodes_in_order,
  )
  let rank_node_ids_by_rank = build_rank_node_ids_by_lane(
    nodes_in_order, rank_by_node_id, order_index_by_node_id, base_order_index_by_node_id,
    max_rank,
  )
  let crossings_before = wb_rank_crossings_between(
    match rank_node_ids_by_rank.get(0) {
      Some(node_ids) => node_ids
      None => []
    },
    match rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    successors_by_node_id,
  )
  optimize_rank_order_with_sweep_passes_and_kernel(
    rank_node_ids_by_rank,
    max_rank,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    false,
    4,
    NeighborMeanBidirectional,
  )
  let crossings_after = wb_rank_crossings_between(
    match rank_node_ids_by_rank.get(0) {
      Some(node_ids) => node_ids
      None => []
    },
    match rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    successors_by_node_id,
  )
  assert_true(crossings_after <= crossings_before)
}

///|
test "elk layered order optimization keeps multi-rank sweep neighbor state coherent" {
  let graph = wb_graph(["A", "B", "C", "D", "E", "F"], [
    ("A", "D"),
    ("B", "C"),
    ("C", "F"),
    ("D", "E"),
  ])
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, false,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order,
    graph.edges,
  )
  let base_order_index_by_node_id = build_order_index_by_node_id(nodes_in_order)
  let (
    rank_by_node_id,
    max_rank,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  ) = build_layered_rank_state(
    graph,
    false,
    prep_state.subgraph_entry_by_id,
    prep_state.subgraph_exit_by_id,
    nodes_in_order,
  )
  let rank_node_ids_by_rank = build_rank_node_ids_by_lane(
    nodes_in_order, rank_by_node_id, order_index_by_node_id, base_order_index_by_node_id,
    max_rank,
  )
  let crossings_before = rank_order_crossing_score(
    rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  optimize_rank_order_with_sweep_passes_and_kernel(
    rank_node_ids_by_rank,
    max_rank,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    false,
    4,
    NeighborMeanBidirectional,
  )
  let crossings_after = rank_order_crossing_score(
    rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  assert_true(crossings_after < crossings_before)
  assert_eq(crossings_after, 0)
  assert_eq(
    match rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    ["D", "C"],
  )
  assert_eq(
    match rank_node_ids_by_rank.get(2) {
      Some(node_ids) => node_ids
      None => []
    },
    ["E", "F"],
  )
}

///|
test "elk layered neighbor sort keeps current rank order on full ties" {
  let node_ids = ["B", "A"]
  let neighbor_by_node_id : Map[String, Array[String]] = {}
  let rank_position_by_node_id : Map[String, Int] = { "B": 0, "A": 1 }
  let order_index_by_node_id : Map[String, Int] = { "A": 0, "B": 1 }
  sort_rank_nodes_by_neighbors(
    node_ids, neighbor_by_node_id, rank_position_by_node_id, order_index_by_node_id,
    true,
  )
  assert_eq(node_ids, ["B", "A"])
}

///|
test "elk layered long-span rank-order candidates stay score-tied" {
  let graph = wb_graph(["N0", "N1", "N2", "N3", "N4", "N5", "N6"], [
    ("N0", "N1"),
    ("N1", "N2"),
    ("N2", "N3"),
    ("N3", "N4"),
    ("N4", "N5"),
    ("N5", "N6"),
    ("N0", "N4"),
    ("N1", "N5"),
    ("N2", "N6"),
    ("N6", "N3"),
  ])
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, false,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order,
    graph.edges,
  )
  let base_order_index_by_node_id = build_order_index_by_node_id(nodes_in_order)
  let (
    rank_by_node_id,
    max_rank,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  ) = build_layered_rank_state(
    graph,
    false,
    prep_state.subgraph_entry_by_id,
    prep_state.subgraph_exit_by_id,
    nodes_in_order,
  )
  let base_rank_node_ids_by_rank = build_rank_node_ids_by_lane(
    nodes_in_order, rank_by_node_id, order_index_by_node_id, base_order_index_by_node_id,
    max_rank,
  )
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
  let base_score = rank_order_crossing_score(
    optimized_base_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  let virtual_score = rank_order_crossing_score(
    real_virtual_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  assert_eq(base_score, virtual_score)
  let base_rank_two = match optimized_base_rank_node_ids_by_rank.get(2) {
    Some(node_ids) => node_ids
    None => []
  }
  let virtual_rank_two = match real_virtual_rank_node_ids_by_rank.get(2) {
    Some(node_ids) => node_ids
    None => []
  }
  assert_eq(base_rank_two, ["N2", "N5"])
  assert_eq(virtual_rank_two, ["N2", "N5"])
}

///|
test "elk layered crossing optimizer reduces global crossings on long-span backjump fixture" {
  let graph = @parser_header_core.parse_mermaid(stress_005_source())
  let setup_state = run_elk_layered_setup_phase({
    graph,
    options: RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  })
  let (
    rank_by_node_id,
    max_rank,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  ) = build_layered_rank_state(
    graph,
    setup_state.use_subgraph_redirects,
    setup_state.subgraph_entry_by_id,
    setup_state.subgraph_exit_by_id,
    setup_state.nodes_in_order,
  )
  let base_rank_node_ids_by_rank = build_rank_node_ids_by_lane(
    setup_state.nodes_in_order,
    rank_by_node_id,
    order_index_by_node_id,
    setup_state.base_order_index_by_node_id,
    max_rank,
  )
  let optimized_rank_node_ids_by_rank = build_optimized_rank_node_ids_by_rank(
    base_rank_node_ids_by_rank,
    max_rank,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    rank_by_node_id,
    rank_by_node_id.length(),
    graph.edges.length(),
  )
  let base_global_crossings = wb_global_crossing_count(
    base_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  let optimized_global_crossings = wb_global_crossing_count(
    optimized_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  assert_true(optimized_global_crossings < base_global_crossings)
}
