///|
fn wb_crossing_objective_not_worse(
  left : ElkLayeredCrossingObjective,
  right : ElkLayeredCrossingObjective,
) -> Bool {
  left.layered_crossings <= right.layered_crossings
}

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
  let execution_state = execute_crossing_phase_with_plan_with_trial_trace(
      input, plan,
    ).execution_state
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
test "elk layered crossing selected trial retains best post-sweep objective across passes" {
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
  let default_plan = default_crossing_execution_plan(
    LayerSweepWithLocalRefinement,
  )
  let plan : ElkLayeredCrossingExecutionPlan = {
    strategy: default_plan.strategy,
    config: {
      preserve_order_node_threshold: default_plan.config.preserve_order_node_threshold,
      preserve_order_edge_threshold: default_plan.config.preserve_order_edge_threshold,
      sweep_pass_count: default_plan.config.sweep_pass_count,
      trial_count: 2,
      trial_random_seed: default_plan.config.trial_random_seed,
      trial_continuation_policy: default_plan.config.trial_continuation_policy,
      trial_model_order_inversion_influence: default_plan.config.trial_model_order_inversion_influence,
      swap_refine_node_limit: default_plan.config.swap_refine_node_limit,
      swap_refine_edge_limit: default_plan.config.swap_refine_edge_limit,
      permutation_refine_node_limit: default_plan.config.permutation_refine_node_limit,
      permutation_refine_edge_limit: default_plan.config.permutation_refine_edge_limit,
      permutation_rank_size_limit: default_plan.config.permutation_rank_size_limit,
    },
    sweep_kernel: default_plan.sweep_kernel,
    local_refinement_kernels: default_plan.local_refinement_kernels,
  }
  let result = run_crossing_phase_with_plan(
    build_crossing_phase_input(
      base_rank_node_ids_by_rank,
      max_rank,
      predecessors_by_node_id,
      successors_by_node_id,
      order_index_by_node_id,
      rank_by_node_id,
      rank_by_node_id.length(),
      graph.edges.length(),
    ),
    plan,
  )
  guard result.trial_summaries.get(result.selected_trial_index)
    is Some(selected_trial) else {
    fail("expected selected trial summary to exist")
  }
  assert_true(selected_trial.sweep_pass_summaries.length() > 0)
  for pass_summary in selected_trial.sweep_pass_summaries {
    assert_true(
      wb_crossing_objective_not_worse(
        selected_trial.post_sweep_objective,
        pass_summary.objective,
      ),
    )
  }
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
  let via_helper = build_optimized_rank_node_ids_by_rank_with_plan_and_trace(
    default_crossing_execution_plan(LayerSweepWithLocalRefinement),
    base_rank_node_ids_by_rank,
    max_rank,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    rank_by_node_id,
    4,
    2,
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
  let execution_state = execute_crossing_phase_with_plan_with_trial_trace(
      input, plan,
    ).execution_state
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
  assert_true(result.selected_trial_index >= 0)
  assert_eq(
    result.trial_summaries.length(),
    default_crossing_optimization_config().trial_count,
  )
  assert_true(
    match result.trial_summaries.get(result.selected_trial_index) {
      Some(_) => true
      None => false
    },
  )
}

///|
test "elk layered crossing execution plan keeps default kernels ordered" {
  let plan = default_crossing_execution_plan(LayerSweepWithLocalRefinement)
  assert_true(plan.sweep_kernel is NeighborMeanBidirectional)
  assert_true(plan.local_refinement_kernels is [AdjacentSwap, RankPermutation])
  assert_eq(
    plan.config.trial_count,
    default_crossing_optimization_config().trial_count,
  )
  assert_eq(plan.config.trial_random_seed, 1)
  assert_eq(plan.config.trial_model_order_inversion_influence, 0.0)
}

///|
test "elk layered crossing sweep kernel registry includes default and edge-slot variants" {
  let kernels = available_crossing_sweep_kernels()
  assert_true(
    kernels is [NeighborMeanBidirectional, NeighborMeanEdgeSlotBidirectional],
  )
}

///|
test "elk layered crossing trial continuation policy registry includes improvement policy" {
  let policies = available_crossing_trial_continuation_policies()
  assert_true(
    policies is [ContinueWhilePassChanges, ContinueWhileObjectiveImproves],
  )
}

///|
test "elk layered crossing trial count normalization keeps at least one trial" {
  assert_eq(normalized_crossing_trial_count(-3), 1)
  assert_eq(normalized_crossing_trial_count(0), 1)
  assert_eq(normalized_crossing_trial_count(2), 2)
}

///|
test "elk layered crossing trial seed builder is deterministic and rank-local" {
  let base_rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B", "C", "G"],
    1: ["D", "E", "F", "H"],
  }
  let backward_initial_seed = build_crossing_trial_seed_rank_node_ids_by_rank(
    base_rank_node_ids_by_rank, 1, 1, 1,
  )
  let backward_initial_seed_again = build_crossing_trial_seed_rank_node_ids_by_rank(
    base_rank_node_ids_by_rank, 1, 1, 1,
  )
  assert_eq(backward_initial_seed, backward_initial_seed_again)
  assert_eq(
    match backward_initial_seed.get(0) {
      Some(node_ids) => node_ids
      None => []
    },
    ["A", "B", "C", "G"],
  )
  assert_eq(
    match backward_initial_seed.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    ["D", "E", "F", "H"],
  )

  let randomized_forward_seed = build_crossing_trial_seed_rank_node_ids_by_rank(
    base_rank_node_ids_by_rank, 1, 2, 1,
  )
  let randomized_forward_seed_again = build_crossing_trial_seed_rank_node_ids_by_rank(
    base_rank_node_ids_by_rank, 1, 2, 1,
  )
  assert_eq(randomized_forward_seed, randomized_forward_seed_again)
  assert_eq(
    match randomized_forward_seed.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    ["D", "E", "F", "H"],
  )
  let randomized_forward_target_rank = match randomized_forward_seed.get(0) {
    Some(node_ids) => node_ids.copy()
    None => []
  }
  randomized_forward_target_rank.sort()
  assert_eq(randomized_forward_target_rank, ["A", "B", "C", "G"])

  let randomized_backward_seed = build_crossing_trial_seed_rank_node_ids_by_rank(
    base_rank_node_ids_by_rank, 1, 3, 1,
  )
  let randomized_backward_seed_again = build_crossing_trial_seed_rank_node_ids_by_rank(
    base_rank_node_ids_by_rank, 1, 3, 1,
  )
  assert_eq(randomized_backward_seed, randomized_backward_seed_again)
  assert_eq(
    match randomized_backward_seed.get(0) {
      Some(node_ids) => node_ids
      None => []
    },
    ["A", "B", "C", "G"],
  )
  let randomized_backward_target_rank = match randomized_backward_seed.get(1) {
    Some(node_ids) => node_ids.copy()
    None => []
  }
  randomized_backward_target_rank.sort()
  assert_eq(randomized_backward_target_rank, ["D", "E", "F", "H"])
}

///|
test "elk layered crossing single-trial config remains behavior-equivalent" {
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
  let single_plan = default_crossing_execution_plan(
    LayerSweepWithLocalRefinement,
  )
  let single_result = run_crossing_phase_with_plan(input, single_plan)
  let multi_plan : ElkLayeredCrossingExecutionPlan = {
    strategy: LayerSweepWithLocalRefinement,
    config: {
      preserve_order_node_threshold: single_plan.config.preserve_order_node_threshold,
      preserve_order_edge_threshold: single_plan.config.preserve_order_edge_threshold,
      sweep_pass_count: single_plan.config.sweep_pass_count,
      trial_count: 1,
      trial_random_seed: single_plan.config.trial_random_seed,
      trial_continuation_policy: single_plan.config.trial_continuation_policy,
      trial_model_order_inversion_influence: single_plan.config.trial_model_order_inversion_influence,
      swap_refine_node_limit: single_plan.config.swap_refine_node_limit,
      swap_refine_edge_limit: single_plan.config.swap_refine_edge_limit,
      permutation_refine_node_limit: single_plan.config.permutation_refine_node_limit,
      permutation_refine_edge_limit: single_plan.config.permutation_refine_edge_limit,
      permutation_rank_size_limit: single_plan.config.permutation_rank_size_limit,
    },
    sweep_kernel: single_plan.sweep_kernel,
    local_refinement_kernels: single_plan.local_refinement_kernels,
  }
  let multi_result = run_crossing_phase_with_plan(input, multi_plan)
  assert_eq(
    match single_result.optimized_rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
    match multi_result.optimized_rank_node_ids_by_rank.get(1) {
      Some(node_ids) => node_ids
      None => []
    },
  )
  assert_eq(
    single_result.optimized_objective.layered_crossings,
    multi_result.optimized_objective.layered_crossings,
  )
  assert_eq(
    single_result.optimized_objective.global_crossings,
    multi_result.optimized_objective.global_crossings,
  )
}
