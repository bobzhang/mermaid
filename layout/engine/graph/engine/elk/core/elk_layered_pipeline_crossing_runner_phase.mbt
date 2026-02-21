///|

///|
priv struct ElkLayeredCrossingPhaseResult {
  post_sweep_rank_node_ids_by_rank : Map[Int, Array[String]]
  optimized_rank_node_ids_by_rank : Map[Int, Array[String]]
  post_sweep_objective : ElkLayeredCrossingObjective
  optimized_objective : ElkLayeredCrossingObjective
}

///|
priv struct ElkLayeredCrossingExecutionState {
  post_sweep_rank_node_ids_by_rank : Map[Int, Array[String]]
  post_refinement_rank_node_ids_by_rank : Map[Int, Array[String]]
}

///|
fn build_crossing_objective_context_from_phase_input(
  input : ElkLayeredCrossingPhaseInput,
) -> ElkLayeredCrossingObjectiveContext {
  {
    max_rank: input.max_rank,
    rank_by_node_id: input.rank_by_node_id,
    successors_by_node_id: input.successors_by_node_id,
  }
}

///|
fn normalized_crossing_trial_count(trial_count : Int) -> Int {
  if trial_count <= 0 {
    1
  } else {
    trial_count
  }
}

///|
fn crossing_trial_initial_forward_sweep(trial_index : Int) -> Bool {
  trial_index % 2 == 0
}

///|
fn crossing_trial_uses_initial_order_seed(trial_index : Int) -> Bool {
  // Align with upstream layered crossing runs:
  // - trial 0: initial input order + forward sweep
  // - trial 1: initial input order + backward sweep
  // - later trials: randomized first-layer seed.
  trial_index < 2
}

///|
fn shuffle_node_ids_for_crossing_trial(
  node_ids : Array[String],
  random_state : UInt64,
) -> Unit {
  if node_ids.length() <= 1 {
    return
  }
  let mut next_random_state = random_state
  let mut index = node_ids.length() - 1
  while index > 0 {
    let (candidate_random_state, swap_index) = java_random_next_int(
      next_random_state,
      index + 1,
    )
    next_random_state = candidate_random_state
    if swap_index != index {
      let value = node_ids[index]
      node_ids[index] = node_ids[swap_index]
      node_ids[swap_index] = value
    }
    index = index - 1
  }
}

///|
fn build_crossing_trial_seed_rank_node_ids_by_rank(
  input_rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  trial_index : Int,
  trial_random_seed : Int,
) -> Map[Int, Array[String]] {
  let seed_rank_node_ids_by_rank = clone_rank_node_ids_by_rank(
    input_rank_node_ids_by_rank, max_rank,
  )
  if crossing_trial_uses_initial_order_seed(trial_index) {
    return seed_rank_node_ids_by_rank
  }
  let start_rank = if crossing_trial_initial_forward_sweep(trial_index) {
    0
  } else {
    max_rank
  }
  match seed_rank_node_ids_by_rank.get(start_rank) {
    Some(node_ids) =>
      shuffle_node_ids_for_crossing_trial(
        node_ids,
        java_random_state_from_seed(trial_random_seed + trial_index),
      )
    None => ()
  }
  seed_rank_node_ids_by_rank
}

///|
fn crossing_execution_state_is_better(
  candidate : ElkLayeredCrossingExecutionState,
  incumbent : ElkLayeredCrossingExecutionState,
  objective_context : ElkLayeredCrossingObjectiveContext,
  input : ElkLayeredCrossingPhaseInput,
  config : ElkLayeredCrossingOptimizationConfig,
) -> Bool {
  let candidate_objective = evaluate_crossing_objective(
    candidate.post_refinement_rank_node_ids_by_rank,
    objective_context,
  )
  let incumbent_objective = evaluate_crossing_objective(
    incumbent.post_refinement_rank_node_ids_by_rank,
    objective_context,
  )
  if candidate_objective.layered_crossings <
    incumbent_objective.layered_crossings {
    return true
  }
  if candidate_objective.layered_crossings >
    incumbent_objective.layered_crossings {
    return false
  }
  if candidate_objective.global_crossings < incumbent_objective.global_crossings {
    return true
  }
  if candidate_objective.global_crossings > incumbent_objective.global_crossings {
    return false
  }
  if config.trial_model_order_inversion_influence <= 0.0 {
    // Keep incumbent on crossing ties, matching upstream layered trial selection.
    return false
  }
  let candidate_model_order_inversion = rank_order_model_inversion_score(
    candidate.post_refinement_rank_node_ids_by_rank,
    input.max_rank,
    input.order_index_by_node_id,
  )
  let incumbent_model_order_inversion = rank_order_model_inversion_score(
    incumbent.post_refinement_rank_node_ids_by_rank,
    input.max_rank,
    input.order_index_by_node_id,
  )
  candidate_model_order_inversion < incumbent_model_order_inversion
}

///|
fn execute_crossing_phase_once_with_plan_and_seed(
  input : ElkLayeredCrossingPhaseInput,
  plan : ElkLayeredCrossingExecutionPlan,
  seed_rank_node_ids_by_rank : Map[Int, Array[String]],
  initial_forward_sweep : Bool,
) -> ElkLayeredCrossingExecutionState {
  let _ = input.port_order_slots_by_node_id
  let config = plan.config
  let optimized_rank_node_ids_by_rank = seed_rank_node_ids_by_rank
  let sweep_input = build_crossing_sweep_input_from_phase_input(
    optimized_rank_node_ids_by_rank, input, config,
  )
  if initial_forward_sweep {
    optimize_rank_order_with_sweep_passes_and_kernel(
      sweep_input.rank_node_ids_by_rank,
      sweep_input.max_rank,
      sweep_input.predecessors_by_node_id,
      sweep_input.successors_by_node_id,
      sweep_input.order_index_by_node_id,
      sweep_input.preserve_current_order_on_tie,
      config.sweep_pass_count,
      plan.sweep_kernel,
    )
  } else {
    optimize_rank_order_with_sweep_passes_from_input_and_start_direction(
      sweep_input,
      config.sweep_pass_count,
      plan.sweep_kernel,
      false,
    )
  }
  let post_sweep_rank_node_ids_by_rank = clone_rank_node_ids_by_rank(
    optimized_rank_node_ids_by_rank,
    input.max_rank,
  )
  apply_crossing_local_refinement_kernels(
    build_crossing_refinement_input_from_phase_input(
      optimized_rank_node_ids_by_rank, input,
    ),
    config,
    plan.local_refinement_kernels,
  )
  {
    post_sweep_rank_node_ids_by_rank,
    post_refinement_rank_node_ids_by_rank: optimized_rank_node_ids_by_rank,
  }
}

///|
fn run_crossing_phase_with_plan(
  input : ElkLayeredCrossingPhaseInput,
  plan : ElkLayeredCrossingExecutionPlan,
) -> ElkLayeredCrossingPhaseResult {
  let objective_context = build_crossing_objective_context_from_phase_input(
    input,
  )
  let execution_state = execute_crossing_phase_with_plan_with_trace(input, plan)
  let post_sweep_objective = evaluate_crossing_objective(
    execution_state.post_sweep_rank_node_ids_by_rank,
    objective_context,
  )
  let optimized_objective = evaluate_crossing_objective(
    execution_state.post_refinement_rank_node_ids_by_rank,
    objective_context,
  )
  {
    post_sweep_rank_node_ids_by_rank: execution_state.post_sweep_rank_node_ids_by_rank,
    optimized_rank_node_ids_by_rank: execution_state.post_refinement_rank_node_ids_by_rank,
    post_sweep_objective,
    optimized_objective,
  }
}

///|
fn execute_crossing_phase_with_plan_with_trace(
  input : ElkLayeredCrossingPhaseInput,
  plan : ElkLayeredCrossingExecutionPlan,
) -> ElkLayeredCrossingExecutionState {
  let config = plan.config
  let objective_context = build_crossing_objective_context_from_phase_input(
    input,
  )
  match plan.strategy {
    LayerSweepWithLocalRefinement => {
      let trial_count = normalized_crossing_trial_count(config.trial_count)
      let mut best_execution_state : ElkLayeredCrossingExecutionState? = None
      for trial_index in 0..<trial_count {
        let trial_execution_state = execute_crossing_phase_once_with_plan_and_seed(
          input,
          plan,
          build_crossing_trial_seed_rank_node_ids_by_rank(
            input.rank_node_ids_by_rank,
            input.max_rank,
            trial_index,
            config.trial_random_seed,
          ),
          crossing_trial_initial_forward_sweep(trial_index),
        )
        match best_execution_state {
          Some(incumbent) =>
            if crossing_execution_state_is_better(
                trial_execution_state, incumbent, objective_context, input, config,
              ) {
              best_execution_state = Some(trial_execution_state)
            }
          None => best_execution_state = Some(trial_execution_state)
        }
      }
      match best_execution_state {
        Some(state) => state
        None =>
          execute_crossing_phase_once_with_plan_and_seed(
            input,
            plan,
            build_crossing_trial_seed_rank_node_ids_by_rank(
              input.rank_node_ids_by_rank,
              input.max_rank,
              0,
              config.trial_random_seed,
            ),
            true,
          )
      }
    }
  }
}

///|
fn build_optimized_rank_node_ids_by_rank_with_plan_and_trace(
  plan : ElkLayeredCrossingExecutionPlan,
  base_rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
  rank_by_node_id : Map[String, Int],
  node_count : Int,
  edge_count : Int,
) -> ElkLayeredCrossingPhaseResult {
  run_crossing_phase_with_plan(
    build_crossing_phase_input(
      base_rank_node_ids_by_rank, max_rank, predecessors_by_node_id, successors_by_node_id,
      order_index_by_node_id, rank_by_node_id, node_count, edge_count,
    ),
    plan,
  )
}
