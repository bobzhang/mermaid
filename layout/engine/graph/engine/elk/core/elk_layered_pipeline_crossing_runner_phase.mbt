///|

///|
priv struct ElkLayeredCrossingPhaseResult {
  post_sweep_rank_node_ids_by_rank : Map[Int, Array[String]]
  optimized_rank_node_ids_by_rank : Map[Int, Array[String]]
  post_sweep_objective : ElkLayeredCrossingObjective
  optimized_objective : ElkLayeredCrossingObjective
  selected_trial_index : Int
  trial_summaries : Array[ElkLayeredCrossingTrialSummary]
}

///|
priv struct ElkLayeredCrossingExecutionState {
  post_sweep_rank_node_ids_by_rank : Map[Int, Array[String]]
  post_refinement_rank_node_ids_by_rank : Map[Int, Array[String]]
  sweep_pass_summaries : Array[ElkLayeredCrossingSweepPassSummary]
}

///|
priv struct ElkLayeredCrossingSweepPassSummary {
  pass_index : Int
  sweep_direction : String
  changed : Bool
  objective : ElkLayeredCrossingObjective
  rank_node_ids_by_rank : Map[Int, Array[String]]
}

///|
priv struct ElkLayeredCrossingTrialSummary {
  trial_index : Int
  seed_kind : String
  initial_sweep_direction : String
  sweep_pass_summaries : Array[ElkLayeredCrossingSweepPassSummary]
  post_sweep_objective : ElkLayeredCrossingObjective
  optimized_objective : ElkLayeredCrossingObjective
  model_order_inversion_score : Int
}

///|
priv struct ElkLayeredCrossingExecutionTrace {
  execution_state : ElkLayeredCrossingExecutionState
  selected_trial_index : Int
  trial_summaries : Array[ElkLayeredCrossingTrialSummary]
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
fn crossing_trial_seed_kind_tag(trial_index : Int) -> String {
  if crossing_trial_uses_initial_order_seed(trial_index) {
    "initial-order"
  } else {
    "randomized-start-rank"
  }
}

///|
fn crossing_sweep_direction_tag(initial_forward_sweep : Bool) -> String {
  if initial_forward_sweep {
    "forward"
  } else {
    "backward"
  }
}

///|
fn next_crossing_trial_random_double(
  random_state_by_key : Map[String, UInt64],
) -> Double {
  let random_state = match
    random_state_by_key.get(crossing_neighbor_random_state_key) {
    Some(value) => value
    None => java_random_state_from_seed(1)
  }
  let (next_state, high_bits) = java_random_next_bits(random_state, 26)
  let (next_next_state, low_bits) = java_random_next_bits(next_state, 27)
  random_state_by_key[crossing_neighbor_random_state_key] = next_next_state
  ((high_bits.to_int64() << 27) + low_bits.to_int64()).to_double() /
  9007199254740992.0
}

///|
fn randomize_node_ids_for_crossing_trial(
  node_ids : Array[String],
  random_state_by_key : Map[String, UInt64],
) -> Unit {
  if node_ids.length() <= 1 {
    return
  }
  let random_key_by_node_id : Map[String, Double] = {}
  let initial_rank_position_by_node_id : Map[String, Int] = {}
  for rank_position, node_id in node_ids {
    initial_rank_position_by_node_id[node_id] = rank_position
    random_key_by_node_id[node_id] = next_crossing_trial_random_double(
      random_state_by_key,
    )
  }
  node_ids.sort_by((left, right) => {
    let left_key = match random_key_by_node_id.get(left) {
      Some(value) => value
      None => 0.0
    }
    let right_key = match random_key_by_node_id.get(right) {
      Some(value) => value
      None => 0.0
    }
    let random_order = left_key.compare(right_key)
    if random_order != 0 {
      random_order
    } else {
      option_int_or(initial_rank_position_by_node_id.get(left), 0).compare(
        option_int_or(initial_rank_position_by_node_id.get(right), 0),
      )
    }
  })
}

///|
fn build_crossing_trial_seed_rank_node_ids_by_rank_with_random_state(
  input_rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  trial_index : Int,
  initial_forward_sweep : Bool,
  trial_random_state_by_key : Map[String, UInt64],
) -> Map[Int, Array[String]] {
  let seed_rank_node_ids_by_rank = clone_rank_node_ids_by_rank(
    input_rank_node_ids_by_rank, max_rank,
  )
  if crossing_trial_uses_initial_order_seed(trial_index) {
    return seed_rank_node_ids_by_rank
  }
  let start_rank = if initial_forward_sweep { 0 } else { max_rank }
  match seed_rank_node_ids_by_rank.get(start_rank) {
    Some(node_ids) =>
      randomize_node_ids_for_crossing_trial(node_ids, trial_random_state_by_key)
    None => ()
  }
  seed_rank_node_ids_by_rank
}

///|
fn crossing_execution_state_is_better(
  candidate : ElkLayeredCrossingExecutionState,
  incumbent : ElkLayeredCrossingExecutionState,
  objective_context : ElkLayeredCrossingObjectiveContext,
  components : ElkLayeredCrossingComponentBundle,
  input : ElkLayeredCrossingPhaseInput,
  config : ElkLayeredCrossingOptimizationConfig,
) -> Bool {
  let candidate_objective = evaluate_crossing_objective_with_counter(
    candidate.post_refinement_rank_node_ids_by_rank,
    objective_context,
    components,
  )
  let incumbent_objective = evaluate_crossing_objective_with_counter(
    incumbent.post_refinement_rank_node_ids_by_rank,
    objective_context,
    components,
  )
  if crossing_objective_is_better(candidate_objective, incumbent_objective) {
    return true
  }
  if crossing_objective_is_better(incumbent_objective, candidate_objective) {
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
  let candidate_weighted_score = crossing_weighted_trial_score(
    candidate_objective,
    candidate_model_order_inversion,
    config.trial_model_order_inversion_influence,
  )
  let incumbent_weighted_score = crossing_weighted_trial_score(
    incumbent_objective,
    incumbent_model_order_inversion,
    config.trial_model_order_inversion_influence,
  )
  if candidate_weighted_score < incumbent_weighted_score {
    return true
  }
  if candidate_weighted_score > incumbent_weighted_score {
    return false
  }
  candidate_model_order_inversion < incumbent_model_order_inversion
}

///|
fn crossing_objective_is_better(
  candidate : ElkLayeredCrossingObjective,
  incumbent : ElkLayeredCrossingObjective,
) -> Bool {
  candidate.layered_crossings < incumbent.layered_crossings
}

///|
fn crossing_weighted_trial_score(
  objective : ElkLayeredCrossingObjective,
  model_order_inversion_score : Int,
  model_order_inversion_influence : Double,
) -> Double {
  objective.layered_crossings.to_double() +
  model_order_inversion_influence * model_order_inversion_score.to_double()
}

///|
fn should_continue_crossing_trial_pass(
  config : ElkLayeredCrossingOptimizationConfig,
  pass_changed : Bool,
  pass_objective : ElkLayeredCrossingObjective,
  previous_pass_objective : ElkLayeredCrossingObjective?,
) -> Bool {
  match config.trial_continuation_policy {
    ContinueWhilePassChanges => pass_changed
    ContinueWhileObjectiveImproves =>
      match previous_pass_objective {
        Some(previous_objective) =>
          crossing_objective_is_better(pass_objective, previous_objective)
        None => true
      }
  }
}

///|
fn execute_crossing_phase_once_with_plan_and_seed(
  input : ElkLayeredCrossingPhaseInput,
  plan : ElkLayeredCrossingExecutionPlan,
  components : ElkLayeredCrossingComponentBundle,
  seed_rank_node_ids_by_rank : Map[Int, Array[String]],
  initial_forward_sweep : Bool,
  neighbor_mean_random_state_by_key : Map[String, UInt64],
) -> ElkLayeredCrossingExecutionState {
  let _ = input.port_order_slots_by_node_id
  let _ = input.ordering_edges
  let config = plan.config
  let objective_context = build_crossing_objective_context_from_phase_input(
    input,
  )
  let sweep_rank_node_ids_by_rank = seed_rank_node_ids_by_rank
  let sweep_input = build_crossing_sweep_input_from_phase_input_with_random_state(
    sweep_rank_node_ids_by_rank, input, config, neighbor_mean_random_state_by_key,
  )
  let sweep_pass_summaries : Array[ElkLayeredCrossingSweepPassSummary] = []
  let mut best_post_sweep_rank_node_ids_by_rank = clone_rank_node_ids_by_rank(
    sweep_rank_node_ids_by_rank,
    input.max_rank,
  )
  let mut best_post_sweep_objective = evaluate_crossing_objective_with_counter(
    best_post_sweep_rank_node_ids_by_rank, objective_context, components,
  )
  let mut best_post_sweep_model_order_inversion = rank_order_model_inversion_score(
    best_post_sweep_rank_node_ids_by_rank,
    input.max_rank,
    input.order_index_by_node_id,
  )
  let mut previous_pass_objective : ElkLayeredCrossingObjective? = None
  let mut pass = 0
  let mut forward_sweep = initial_forward_sweep
  while pass < config.sweep_pass_count {
    let changed = apply_crossing_sweep_heuristic_once(
      sweep_input,
      forward_sweep,
      pass == 0,
      components,
    )
    let pass_objective = evaluate_crossing_objective_with_counter(
      sweep_input.rank_node_ids_by_rank,
      objective_context,
      components,
    )
    sweep_pass_summaries.push({
      pass_index: pass,
      sweep_direction: crossing_sweep_direction_tag(forward_sweep),
      changed,
      objective: pass_objective,
      rank_node_ids_by_rank: clone_rank_node_ids_by_rank(
        sweep_input.rank_node_ids_by_rank,
        input.max_rank,
      ),
    })
    if crossing_objective_is_better(pass_objective, best_post_sweep_objective) {
      best_post_sweep_objective = pass_objective
      best_post_sweep_model_order_inversion = rank_order_model_inversion_score(
        sweep_input.rank_node_ids_by_rank,
        input.max_rank,
        input.order_index_by_node_id,
      )
      best_post_sweep_rank_node_ids_by_rank = clone_rank_node_ids_by_rank(
        sweep_input.rank_node_ids_by_rank,
        input.max_rank,
      )
    } else if !crossing_objective_is_better(
        best_post_sweep_objective, pass_objective,
      ) &&
      config.trial_model_order_inversion_influence > 0.0 {
      let pass_model_order_inversion = rank_order_model_inversion_score(
        sweep_input.rank_node_ids_by_rank,
        input.max_rank,
        input.order_index_by_node_id,
      )
      let pass_weighted_score = crossing_weighted_trial_score(
        pass_objective,
        pass_model_order_inversion,
        config.trial_model_order_inversion_influence,
      )
      let best_weighted_score = crossing_weighted_trial_score(
        best_post_sweep_objective,
        best_post_sweep_model_order_inversion,
        config.trial_model_order_inversion_influence,
      )
      if pass_weighted_score < best_weighted_score ||
        (
          pass_weighted_score == best_weighted_score &&
          pass_model_order_inversion < best_post_sweep_model_order_inversion
        ) {
        best_post_sweep_objective = pass_objective
        best_post_sweep_model_order_inversion = pass_model_order_inversion
        best_post_sweep_rank_node_ids_by_rank = clone_rank_node_ids_by_rank(
          sweep_input.rank_node_ids_by_rank,
          input.max_rank,
        )
      }
    }
    let should_continue = should_continue_crossing_trial_pass(
      config, changed, pass_objective, previous_pass_objective,
    )
    previous_pass_objective = Some(pass_objective)
    if !should_continue {
      break
    }
    forward_sweep = !forward_sweep
    pass = pass + 1
  }
  let post_sweep_rank_node_ids_by_rank = best_post_sweep_rank_node_ids_by_rank
  let optimized_rank_node_ids_by_rank = clone_rank_node_ids_by_rank(
    sweep_input.rank_node_ids_by_rank,
    input.max_rank,
  )
  apply_crossing_constraint_resolver(
    build_crossing_refinement_input_from_phase_input(
      optimized_rank_node_ids_by_rank, input,
    ),
    config,
    plan.local_refinement_kernels,
    components,
  )
  let post_sweep_objective = evaluate_crossing_objective_with_counter(
    post_sweep_rank_node_ids_by_rank, objective_context, components,
  )
  let optimized_objective = evaluate_crossing_objective_with_counter(
    optimized_rank_node_ids_by_rank, objective_context, components,
  )
  let optimized_model_order_inversion = rank_order_model_inversion_score(
    optimized_rank_node_ids_by_rank,
    input.max_rank,
    input.order_index_by_node_id,
  )
  let post_sweep_model_order_inversion = rank_order_model_inversion_score(
    post_sweep_rank_node_ids_by_rank,
    input.max_rank,
    input.order_index_by_node_id,
  )
  let optimized_beats_post_sweep = if config.trial_model_order_inversion_influence >
    0.0 {
    let optimized_weighted_score = crossing_weighted_trial_score(
      optimized_objective,
      optimized_model_order_inversion,
      config.trial_model_order_inversion_influence,
    )
    let post_sweep_weighted_score = crossing_weighted_trial_score(
      post_sweep_objective,
      post_sweep_model_order_inversion,
      config.trial_model_order_inversion_influence,
    )
    optimized_weighted_score < post_sweep_weighted_score ||
    (
      optimized_weighted_score == post_sweep_weighted_score &&
      optimized_model_order_inversion < post_sweep_model_order_inversion
    )
  } else {
    let objectives_equal = optimized_objective.layered_crossings ==
      post_sweep_objective.layered_crossings &&
      optimized_objective.global_crossings ==
      post_sweep_objective.global_crossings
    let optimized_improves_post_sweep = (
        optimized_objective.layered_crossings <
        post_sweep_objective.layered_crossings &&
        optimized_objective.global_crossings <=
        post_sweep_objective.global_crossings
      ) ||
      (
        optimized_objective.global_crossings <
        post_sweep_objective.global_crossings &&
        optimized_objective.layered_crossings <=
        post_sweep_objective.layered_crossings
      )
    let optimized_wins_equal_objective_by_model_order = objectives_equal &&
      optimized_model_order_inversion < post_sweep_model_order_inversion
    optimized_improves_post_sweep ||
    optimized_wins_equal_objective_by_model_order
  }
  if !optimized_beats_post_sweep {
    return {
      post_sweep_rank_node_ids_by_rank,
      post_refinement_rank_node_ids_by_rank: clone_rank_node_ids_by_rank(
        post_sweep_rank_node_ids_by_rank,
        input.max_rank,
      ),
      sweep_pass_summaries,
    }
  }
  {
    post_sweep_rank_node_ids_by_rank,
    post_refinement_rank_node_ids_by_rank: optimized_rank_node_ids_by_rank,
    sweep_pass_summaries,
  }
}

///|
fn run_crossing_phase_with_plan(
  input : ElkLayeredCrossingPhaseInput,
  plan : ElkLayeredCrossingExecutionPlan,
) -> ElkLayeredCrossingPhaseResult {
  let components = build_crossing_component_bundle(plan)
  let objective_context = build_crossing_objective_context_from_phase_input(
    input,
  )
  let execution_trace = execute_crossing_phase_with_plan_with_trial_trace(
    input, plan,
  )
  let execution_state = execution_trace.execution_state
  let post_sweep_objective = evaluate_crossing_objective_with_counter(
    execution_state.post_sweep_rank_node_ids_by_rank,
    objective_context,
    components,
  )
  let optimized_objective = evaluate_crossing_objective_with_counter(
    execution_state.post_refinement_rank_node_ids_by_rank,
    objective_context,
    components,
  )
  {
    post_sweep_rank_node_ids_by_rank: execution_state.post_sweep_rank_node_ids_by_rank,
    optimized_rank_node_ids_by_rank: execution_state.post_refinement_rank_node_ids_by_rank,
    post_sweep_objective,
    optimized_objective,
    selected_trial_index: execution_trace.selected_trial_index,
    trial_summaries: execution_trace.trial_summaries,
  }
}

///|
fn execute_crossing_phase_with_plan_with_trial_trace(
  input : ElkLayeredCrossingPhaseInput,
  plan : ElkLayeredCrossingExecutionPlan,
) -> ElkLayeredCrossingExecutionTrace {
  let config = plan.config
  let components = build_crossing_component_bundle(plan)
  let objective_context = build_crossing_objective_context_from_phase_input(
    input,
  )
  match plan.strategy {
    LayerSweepWithLocalRefinement => {
      let trial_count = normalized_crossing_trial_count(config.trial_count)
      let trial_summaries : Array[ElkLayeredCrossingTrialSummary] = []
      let mut best_execution_state : ElkLayeredCrossingExecutionState? = None
      let mut selected_trial_index = 0
      for trial_index in 0..<trial_count {
        let initial_forward_sweep = crossing_trial_initial_forward_sweep(
          trial_index,
        )
        let trial_random_state_by_key = build_crossing_neighbor_mean_random_state_by_seed(
          config.trial_random_seed + trial_index,
        )
        let trial_execution_state = execute_crossing_phase_once_with_plan_and_seed(
          input,
          plan,
          components,
          build_crossing_trial_seed_rank_node_ids_by_rank_with_random_state(
            input.rank_node_ids_by_rank,
            input.max_rank,
            trial_index,
            initial_forward_sweep,
            trial_random_state_by_key,
          ),
          initial_forward_sweep,
          trial_random_state_by_key,
        )
        let post_sweep_objective = evaluate_crossing_objective_with_counter(
          trial_execution_state.post_sweep_rank_node_ids_by_rank,
          objective_context,
          components,
        )
        let optimized_objective = evaluate_crossing_objective_with_counter(
          trial_execution_state.post_refinement_rank_node_ids_by_rank,
          objective_context,
          components,
        )
        trial_summaries.push({
          trial_index,
          seed_kind: crossing_trial_seed_kind_tag(trial_index),
          initial_sweep_direction: crossing_sweep_direction_tag(
            initial_forward_sweep,
          ),
          sweep_pass_summaries: trial_execution_state.sweep_pass_summaries,
          post_sweep_objective,
          optimized_objective,
          model_order_inversion_score: rank_order_model_inversion_score(
            trial_execution_state.post_refinement_rank_node_ids_by_rank,
            input.max_rank,
            input.order_index_by_node_id,
          ),
        })
        match best_execution_state {
          Some(incumbent) =>
            if crossing_execution_state_is_better(
                trial_execution_state, incumbent, objective_context, components,
                input, config,
              ) {
              best_execution_state = Some(trial_execution_state)
              selected_trial_index = trial_index
            }
          None => {
            best_execution_state = Some(trial_execution_state)
            selected_trial_index = trial_index
          }
        }
      }
      match best_execution_state {
        Some(state) =>
          { execution_state: state, selected_trial_index, trial_summaries }
        None => {
          let fallback_random_state_by_key = build_crossing_neighbor_mean_random_state_by_seed(
            config.trial_random_seed,
          )
          let fallback_execution_state = execute_crossing_phase_once_with_plan_and_seed(
            input,
            plan,
            components,
            build_crossing_trial_seed_rank_node_ids_by_rank_with_random_state(
              input.rank_node_ids_by_rank,
              input.max_rank,
              0,
              true,
              fallback_random_state_by_key,
            ),
            true,
            fallback_random_state_by_key,
          )
          let fallback_trace : ElkLayeredCrossingTrialSummary = {
            trial_index: 0,
            seed_kind: crossing_trial_seed_kind_tag(0),
            initial_sweep_direction: crossing_sweep_direction_tag(true),
            sweep_pass_summaries: fallback_execution_state.sweep_pass_summaries,
            post_sweep_objective: evaluate_crossing_objective_with_counter(
              fallback_execution_state.post_sweep_rank_node_ids_by_rank,
              objective_context,
              components,
            ),
            optimized_objective: evaluate_crossing_objective_with_counter(
              fallback_execution_state.post_refinement_rank_node_ids_by_rank,
              objective_context,
              components,
            ),
            model_order_inversion_score: rank_order_model_inversion_score(
              fallback_execution_state.post_refinement_rank_node_ids_by_rank,
              input.max_rank,
              input.order_index_by_node_id,
            ),
          }
          {
            execution_state: fallback_execution_state,
            selected_trial_index: 0,
            trial_summaries: [fallback_trace],
          }
        }
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
