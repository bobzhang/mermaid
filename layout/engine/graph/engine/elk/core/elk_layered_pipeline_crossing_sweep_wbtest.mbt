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
fn wb_optimize_rank_order_with_sweep_passes_and_kernel(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
  preserve_current_order_on_tie : Bool,
  sweep_pass_count : Int,
  sweep_kernel : ElkLayeredCrossingSweepKernel,
) -> Unit {
  wb_optimize_rank_order_with_sweep_passes_from_input_and_start_direction(
    build_crossing_sweep_input(
      rank_node_ids_by_rank,
      max_rank,
      predecessors_by_node_id,
      successors_by_node_id,
      order_index_by_node_id,
      preserve_current_order_on_tie,
      false,
      0.07,
      build_crossing_neighbor_mean_random_state_by_seed(1),
    ),
    sweep_pass_count,
    sweep_kernel,
    true,
  )
}

///|
fn wb_optimize_rank_order_with_sweep_passes_from_input_and_start_direction(
  sweep_input : ElkLayeredCrossingSweepInput,
  sweep_pass_count : Int,
  sweep_kernel : ElkLayeredCrossingSweepKernel,
  initial_forward_sweep : Bool,
) -> Unit {
  if sweep_input.max_rank <= 0 {
    return
  }
  let mut pass = 0
  let mut forward_sweep = initial_forward_sweep
  while pass < sweep_pass_count {
    let changed = sweep_rank_order_once_from_input_with_kernel(
      sweep_input,
      sweep_kernel,
      forward_sweep,
      pass == 0,
    )
    if !changed {
      break
    }
    forward_sweep = !forward_sweep
    pass = pass + 1
  }
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
  wb_optimize_rank_order_with_sweep_passes_and_kernel(
    via_wrapper,
    2,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    false,
    3,
    default_crossing_sweep_kernel(),
  )
  wb_optimize_rank_order_with_sweep_passes_and_kernel(
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
test "elk layered edge-slot sweep kernel is deterministic and preserves rank composition" {
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
  let run_one = clone_rank_node_ids_by_rank(seed_rank_node_ids_by_rank, 2)
  let run_two = clone_rank_node_ids_by_rank(seed_rank_node_ids_by_rank, 2)
  wb_optimize_rank_order_with_sweep_passes_and_kernel(
    run_one,
    2,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    false,
    3,
    NeighborMeanEdgeSlotBidirectional,
  )
  wb_optimize_rank_order_with_sweep_passes_and_kernel(
    run_two,
    2,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    false,
    3,
    NeighborMeanEdgeSlotBidirectional,
  )
  assert_eq(run_one, run_two)
  for rank in 0..<=2 {
    let baseline_nodes = match seed_rank_node_ids_by_rank.get(rank) {
      Some(node_ids) => node_ids.copy()
      None => []
    }
    let optimized_nodes = match run_one.get(rank) {
      Some(node_ids) => node_ids.copy()
      None => []
    }
    baseline_nodes.sort()
    optimized_nodes.sort()
    assert_eq(optimized_nodes, baseline_nodes)
  }
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
  wb_optimize_rank_order_with_sweep_passes_and_kernel(
    via_parameters,
    2,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    false,
    3,
    NeighborMeanBidirectional,
  )
  wb_optimize_rank_order_with_sweep_passes_from_input_and_start_direction(
    build_crossing_sweep_input(
      via_input,
      2,
      predecessors_by_node_id,
      successors_by_node_id,
      order_index_by_node_id,
      false,
      false,
      0.07,
      build_crossing_neighbor_mean_random_state_by_seed(1),
    ),
    3,
    NeighborMeanBidirectional,
    true,
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
  wb_optimize_rank_order_with_sweep_passes_and_kernel(
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
  wb_optimize_rank_order_with_sweep_passes_and_kernel(
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
  let _ = sort_rank_nodes_by_neighbors(
    node_ids,
    neighbor_by_node_id,
    rank_position_by_node_id,
    order_index_by_node_id,
    true,
    false,
    build_crossing_neighbor_mean_random_state_by_seed(1),
    0.07,
    true,
  )
  assert_eq(node_ids, ["B", "A"])
}

///|
test "elk layered neighbor sort propagates in-layer edges through recursive barycenters" {
  let node_ids = ["A", "C", "B"]
  let neighbor_by_node_id : Map[String, Array[String]] = {
    "A": ["B"],
    "B": ["X"],
    "C": ["Y"],
  }
  let rank_position_by_node_id : Map[String, Int] = {
    "A": 0,
    "C": 1,
    "B": 2,
    "X": 0,
    "Y": 1,
  }
  let order_index_by_node_id : Map[String, Int] = { "A": 0, "C": 1, "B": 2 }
  let _ = sort_rank_nodes_by_neighbors(
    node_ids,
    neighbor_by_node_id,
    rank_position_by_node_id,
    order_index_by_node_id,
    true,
    false,
    build_crossing_neighbor_mean_random_state_by_seed(1),
    0.07,
    true,
  )
  assert_eq(node_ids, ["A", "B", "C"])
}

///|
test "elk layered neighbor sort fills unknown barycenters in pre-ordered mode" {
  let node_ids = ["A", "B", "C"]
  let neighbor_by_node_id : Map[String, Array[String]] = {
    "A": ["X"],
    "B": [],
    "C": ["Y"],
  }
  let rank_position_by_node_id : Map[String, Int] = { "X": 0, "Y": 2 }
  let order_index_by_node_id : Map[String, Int] = { "A": 0, "B": 1, "C": 2 }
  let _ = sort_rank_nodes_by_neighbors(
    node_ids,
    neighbor_by_node_id,
    rank_position_by_node_id,
    order_index_by_node_id,
    true,
    false,
    build_crossing_neighbor_mean_random_state_by_seed(1),
    0.07,
    true,
  )
  assert_eq(node_ids, ["A", "B", "C"])
}

///|
test "elk layered neighbor-mean perturbation uses deterministic java-random sequence" {
  let state_one = build_crossing_neighbor_mean_random_state_by_seed(9)
  let state_two = build_crossing_neighbor_mean_random_state_by_seed(9)
  let one_a = next_crossing_neighbor_mean_barycenter_perturbation(
    state_one, 0.07,
  )
  let one_b = next_crossing_neighbor_mean_barycenter_perturbation(
    state_one, 0.07,
  )
  let two_a = next_crossing_neighbor_mean_barycenter_perturbation(
    state_two, 0.07,
  )
  let two_b = next_crossing_neighbor_mean_barycenter_perturbation(
    state_two, 0.07,
  )
  assert_eq(one_a, two_a)
  assert_eq(one_b, two_b)
  assert_true(one_a >= -0.035 && one_a <= 0.035)
  assert_true(one_b >= -0.035 && one_b <= 0.035)
}

///|
test "elk layered neighbor-mean perturbation keeps tie-break deterministic by seed" {
  let neighbor_by_node_id : Map[String, Array[String]] = {
    "A": ["X", "Y"],
    "B": ["X", "Y"],
    "C": ["X", "Y"],
  }
  let rank_position_by_node_id : Map[String, Int] = { "X": 0, "Y": 1 }
  let order_index_by_node_id : Map[String, Int] = { "A": 0, "B": 1, "C": 2 }
  let run_one = ["A", "B", "C"]
  let run_two = ["A", "B", "C"]
  let _ = sort_rank_nodes_by_neighbors(
    run_one,
    neighbor_by_node_id,
    rank_position_by_node_id,
    order_index_by_node_id,
    true,
    true,
    build_crossing_neighbor_mean_random_state_by_seed(1),
    0.07,
    true,
  )
  let _ = sort_rank_nodes_by_neighbors(
    run_two,
    neighbor_by_node_id,
    rank_position_by_node_id,
    order_index_by_node_id,
    true,
    true,
    build_crossing_neighbor_mean_random_state_by_seed(1),
    0.07,
    true,
  )
  assert_eq(run_one, run_two)
}

///|
test "elk layered fixed-layer connection order tracks free-layer positions" {
  let fixed_node_ids = ["S"]
  let free_node_ids = ["B", "A", "C"]
  let connected_node_ids_by_fixed_node_id : Map[String, Array[String]] = {
    "S": ["A", "C", "B"],
  }
  update_fixed_layer_connected_order_by_free_rank_positions(
    fixed_node_ids, free_node_ids, connected_node_ids_by_fixed_node_id, false,
  )
  assert_eq(
    match connected_node_ids_by_fixed_node_id.get("S") {
      Some(node_ids) => node_ids
      None => []
    },
    ["B", "A", "C"],
  )
}

///|
test "elk layered fixed-layer connection order supports descending mode" {
  let fixed_node_ids = ["S"]
  let free_node_ids = ["B", "A", "C"]
  let connected_node_ids_by_fixed_node_id : Map[String, Array[String]] = {
    "S": ["A", "C", "B"],
  }
  update_fixed_layer_connected_order_by_free_rank_positions(
    fixed_node_ids, free_node_ids, connected_node_ids_by_fixed_node_id, true,
  )
  assert_eq(
    match connected_node_ids_by_fixed_node_id.get("S") {
      Some(node_ids) => node_ids
      None => []
    },
    ["C", "A", "B"],
  )
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
  let optimized_base_rank_node_ids_by_rank = build_optimized_rank_node_ids_by_rank_with_plan_and_trace(
      default_crossing_execution_plan(LayerSweepWithLocalRefinement),
      base_rank_node_ids_by_rank,
      max_rank,
      predecessors_by_node_id,
      successors_by_node_id,
      order_index_by_node_id,
      rank_by_node_id,
      rank_by_node_id.length(),
      graph.edges.length(),
    ).optimized_rank_node_ids_by_rank
  let virtual_ordering_state = build_virtual_ordering_state(
    base_rank_node_ids_by_rank, rank_by_node_id, max_rank, order_index_by_node_id,
    successors_by_node_id,
  )
  let optimized_virtual_rank_node_ids_by_rank = build_optimized_rank_node_ids_by_rank_with_plan_and_trace(
      default_crossing_execution_plan(LayerSweepWithLocalRefinement),
      virtual_ordering_state.rank_node_ids_by_rank,
      max_rank,
      virtual_ordering_state.predecessors_by_node_id,
      virtual_ordering_state.successors_by_node_id,
      virtual_ordering_state.order_index_by_node_id,
      virtual_ordering_state.rank_by_node_id,
      virtual_ordering_state.rank_by_node_id.length(),
      graph.edges.length(),
    ).optimized_rank_node_ids_by_rank
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
  let sorted_base_rank_two = base_rank_two.copy()
  sorted_base_rank_two.sort()
  let sorted_virtual_rank_two = virtual_rank_two.copy()
  sorted_virtual_rank_two.sort()
  assert_eq(sorted_base_rank_two, ["N2", "N5"])
  assert_eq(sorted_virtual_rank_two, ["N2", "N5"])
}

///|
fn stress_005_source() -> String {
  (
    #|graph LR
    #|S[S]
    #|T[T]
    #|A1[A1]
    #|A2[A2]
    #|A3[A3]
    #|B1[B1]
    #|B2[B2]
    #|B3[B3]
    #|C1[C1]
    #|C2[C2]
    #|C3[C3]
    #|D1[D1]
    #|D2[D2]
    #|D3[D3]
    #|E1[E1]
    #|E2[E2]
    #|E3[E3]
    #|
    #|S --> A1
    #|S --> A2
    #|S --> A3
    #|
    #|A1 --> B1
    #|A2 --> B2
    #|A3 --> B3
    #|
    #|B1 --> C1
    #|B2 --> C2
    #|B3 --> C3
    #|
    #|C1 --> D1
    #|C2 --> D2
    #|C3 --> D3
    #|
    #|D1 --> E1
    #|D2 --> E2
    #|D3 --> E3
    #|
    #|E1 --> T
    #|E2 --> T
    #|E3 --> T
    #|
    #|A1 --> D2
    #|A2 --> D3
    #|A3 --> D1
    #|B1 --> E2
    #|B2 --> E3
    #|B3 --> E1
    #|A1 --> E3
    #|A3 --> E2
    #|S --> C2
    #|S --> D3
    #|
    #|E3 --> B1
    #|E2 --> B3
    #|D3 --> A2
    #|C3 --> A1
    #|D1 --> C2
    #|T --> C1
    #|
  )
  .trim_end()
  .to_string()
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
  let optimized_rank_node_ids_by_rank = build_optimized_rank_node_ids_by_rank_with_plan_and_trace(
      default_crossing_execution_plan(LayerSweepWithLocalRefinement),
      base_rank_node_ids_by_rank,
      max_rank,
      predecessors_by_node_id,
      successors_by_node_id,
      order_index_by_node_id,
      rank_by_node_id,
      rank_by_node_id.length(),
      graph.edges.length(),
    ).optimized_rank_node_ids_by_rank
  let base_global_crossings = wb_global_crossing_count(
    base_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  let optimized_global_crossings = wb_global_crossing_count(
    optimized_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  assert_true(optimized_global_crossings < base_global_crossings)
}
