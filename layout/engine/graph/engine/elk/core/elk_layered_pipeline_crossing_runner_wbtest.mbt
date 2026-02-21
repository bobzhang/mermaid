///|
test "elk layered crossing strategy wrapper matches explicit default strategy" {
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
  let via_default = optimize_rank_node_ids_by_crossing_phase(input)
  let via_explicit = optimize_rank_node_ids_by_crossing_phase_with_strategy(
    input,
    LayerSweepWithLocalRefinement,
  )
  assert_eq(
    match via_default.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    match via_explicit.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
  )
}

///|
test "elk layered crossing plan wrapper matches strategy wrapper" {
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
  let via_strategy = optimize_rank_node_ids_by_crossing_phase_with_strategy(
    input,
    LayerSweepWithLocalRefinement,
  )
  let via_plan = optimize_rank_node_ids_by_crossing_phase_with_plan(
    input,
    default_crossing_execution_plan(LayerSweepWithLocalRefinement),
  )
  assert_eq(
    match via_strategy.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    match via_plan.get(1) {
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
  let via_plan = optimize_rank_node_ids_by_crossing_phase_with_plan(input, plan)
  assert_eq(
    match result.optimized_rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    match via_plan.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
  )
  let context = build_crossing_objective_context_from_phase_input(input)
  let base_objective = evaluate_crossing_objective(
    input.rank_node_ids_by_rank,
    context,
  )
  let optimized_objective = evaluate_crossing_objective(
    result.optimized_rank_node_ids_by_rank,
    context,
  )
  assert_eq(
    result.base_objective.layered_crossings,
    base_objective.layered_crossings,
  )
  assert_eq(
    result.base_objective.global_crossings,
    base_objective.global_crossings,
  )
  assert_eq(
    result.optimized_objective.layered_crossings,
    optimized_objective.layered_crossings,
  )
  assert_eq(
    result.optimized_objective.global_crossings,
    optimized_objective.global_crossings,
  )
}

///|
test "elk layered crossing execution plan keeps default kernels ordered" {
  let plan = default_crossing_execution_plan(LayerSweepWithLocalRefinement)
  assert_true(plan.sweep_kernel is NeighborMeanBidirectional)
  assert_true(plan.local_refinement_kernels is [AdjacentSwap, RankPermutation])
}
