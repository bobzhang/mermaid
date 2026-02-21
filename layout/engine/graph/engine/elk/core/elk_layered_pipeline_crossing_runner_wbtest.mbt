///|
test "elk layered crossing execution trace matches phase result maps" {
  let input = build_crossing_phase_input(
    { 0: ["A", "B"], 1: ["C", "D"] },
    1,
    { "A": [], "B": [], "C": ["B"], "D": ["A"] },
    { "A": ["D"], "B": ["C"], "C": [], "D": [] },
    { "A": 0, "B": 1, "C": 2, "D": 3 },
    { "A": 0, "B": 0, "C": 1, "D": 1 },
    4,
    2,
  )
  let plan = default_crossing_execution_plan(LayerSweepWithLocalRefinement)
  let phase_result = run_crossing_phase_with_plan(input, plan)
  let execution_state = execute_crossing_phase_with_plan_with_trace(input, plan)
  assert_eq(
    match phase_result.post_sweep_rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    match execution_state.post_sweep_rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
  )
  assert_eq(
    match phase_result.optimized_rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    match execution_state.post_refinement_rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
  )
}

///|
test "elk layered optimized-rank helper matches explicit crossing phase run" {
  let base_rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C", "D"],
  }
  let max_rank = 1
  let predecessors_by_node_id : Map[String, Array[String]] = {
    "A": [],
    "B": [],
    "C": ["B"],
    "D": ["A"],
  }
  let successors_by_node_id : Map[String, Array[String]] = {
    "A": ["D"],
    "B": ["C"],
    "C": [],
    "D": [],
  }
  let order_index_by_node_id : Map[String, Int] = {
    "A": 0,
    "B": 1,
    "C": 2,
    "D": 3,
  }
  let rank_by_node_id : Map[String, Int] = { "A": 0, "B": 0, "C": 1, "D": 1 }
  let via_helper = build_optimized_rank_node_ids_by_rank_with_trace(
    base_rank_node_ids_by_rank, max_rank, predecessors_by_node_id, successors_by_node_id,
    order_index_by_node_id, rank_by_node_id, 4, 2,
  )
  let via_phase = run_crossing_phase_with_plan(
    build_crossing_phase_input(
      base_rank_node_ids_by_rank, max_rank, predecessors_by_node_id, successors_by_node_id,
      order_index_by_node_id, rank_by_node_id, 4, 2,
    ),
    default_crossing_execution_plan(LayerSweepWithLocalRefinement),
  )
  assert_eq(
    match via_helper.optimized_rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    match via_phase.optimized_rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
  )
}

///|
test "elk layered crossing phase result reports consistent objectives" {
  let input = build_crossing_phase_input(
    { 0: ["A", "B"], 1: ["C", "D"] },
    1,
    { "A": [], "B": [], "C": ["B"], "D": ["A"] },
    { "A": ["D"], "B": ["C"], "C": [], "D": [] },
    { "A": 0, "B": 1, "C": 2, "D": 3 },
    { "A": 0, "B": 0, "C": 1, "D": 1 },
    4,
    2,
  )
  let plan = default_crossing_execution_plan(LayerSweepWithLocalRefinement)
  let result = run_crossing_phase_with_plan(input, plan)
  let execution_state = execute_crossing_phase_with_plan_with_trace(input, plan)
  assert_eq(
    match result.optimized_rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    match execution_state.post_refinement_rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
  )
  let context = build_crossing_objective_context_from_phase_input(input)
  let optimized_objective = evaluate_crossing_objective(
    result.optimized_rank_node_ids_by_rank,
    context,
  )
  let post_sweep_objective = evaluate_crossing_objective(
    result.post_sweep_rank_node_ids_by_rank,
    context,
  )
  assert_eq(
    result.optimized_objective.layered_crossings,
    optimized_objective.layered_crossings,
  )
  assert_eq(
    result.optimized_objective.global_crossings,
    optimized_objective.global_crossings,
  )
  assert_eq(
    result.post_sweep_objective.layered_crossings,
    post_sweep_objective.layered_crossings,
  )
  assert_eq(
    result.post_sweep_objective.global_crossings,
    post_sweep_objective.global_crossings,
  )
  assert_true(
    result.post_sweep_objective.layered_crossings >=
    result.optimized_objective.layered_crossings,
  )
}

///|
test "elk layered crossing execution plan keeps default kernels ordered" {
  let plan = default_crossing_execution_plan(LayerSweepWithLocalRefinement)
  assert_true(plan.sweep_kernel is NeighborMeanBidirectional)
  assert_true(plan.local_refinement_kernels is [AdjacentSwap, RankPermutation])
}
