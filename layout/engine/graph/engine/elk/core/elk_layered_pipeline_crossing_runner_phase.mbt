///|

///|
priv struct ElkLayeredCrossingPhaseResult {
  post_sweep_rank_node_ids_by_rank : Map[Int, Array[String]]
  optimized_rank_node_ids_by_rank : Map[Int, Array[String]]
  base_objective : ElkLayeredCrossingObjective
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
fn run_crossing_phase_with_plan(
  input : ElkLayeredCrossingPhaseInput,
  plan : ElkLayeredCrossingExecutionPlan,
) -> ElkLayeredCrossingPhaseResult {
  let objective_context = build_crossing_objective_context_from_phase_input(
    input,
  )
  let base_objective = evaluate_crossing_objective(
    input.rank_node_ids_by_rank,
    objective_context,
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
    base_objective,
    post_sweep_objective,
    optimized_objective,
  }
}

///|
fn optimize_rank_node_ids_by_crossing_phase(
  input : ElkLayeredCrossingPhaseInput,
) -> Map[Int, Array[String]] {
  optimize_rank_node_ids_by_crossing_phase_with_strategy(
    input,
    LayerSweepWithLocalRefinement,
  )
}

///|
fn optimize_rank_node_ids_by_crossing_phase_with_strategy(
  input : ElkLayeredCrossingPhaseInput,
  strategy : ElkLayeredCrossingOptimizerStrategy,
) -> Map[Int, Array[String]] {
  let phase_result = run_crossing_phase_with_plan(
    input,
    default_crossing_execution_plan(strategy),
  )
  let _ = phase_result.base_objective
  let _ = phase_result.optimized_objective
  phase_result.optimized_rank_node_ids_by_rank
}

///|
fn optimize_rank_node_ids_by_crossing_phase_with_plan(
  input : ElkLayeredCrossingPhaseInput,
  plan : ElkLayeredCrossingExecutionPlan,
) -> Map[Int, Array[String]] {
  execute_crossing_phase_with_plan(input, plan)
}

///|
fn execute_crossing_phase_with_plan(
  input : ElkLayeredCrossingPhaseInput,
  plan : ElkLayeredCrossingExecutionPlan,
) -> Map[Int, Array[String]] {
  execute_crossing_phase_with_plan_with_trace(input, plan).post_refinement_rank_node_ids_by_rank
}

///|
fn execute_crossing_phase_with_plan_with_trace(
  input : ElkLayeredCrossingPhaseInput,
  plan : ElkLayeredCrossingExecutionPlan,
) -> ElkLayeredCrossingExecutionState {
  let _ = input.port_order_slots_by_node_id
  let config = plan.config
  match plan.strategy {
    LayerSweepWithLocalRefinement => {
      let optimized_rank_node_ids_by_rank = clone_rank_node_ids_by_rank(
        input.rank_node_ids_by_rank,
        input.max_rank,
      )
      let sweep_input = build_crossing_sweep_input_from_phase_input(
        optimized_rank_node_ids_by_rank, input, config,
      )
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
  }
}

///|
fn build_optimized_rank_node_ids_by_rank_with_trace(
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
    default_crossing_execution_plan(LayerSweepWithLocalRefinement),
  )
}

///|
fn build_optimized_rank_node_ids_by_rank(
  base_rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
  rank_by_node_id : Map[String, Int],
  node_count : Int,
  edge_count : Int,
) -> Map[Int, Array[String]] {
  build_optimized_rank_node_ids_by_rank_with_trace(
    base_rank_node_ids_by_rank, max_rank, predecessors_by_node_id, successors_by_node_id,
    order_index_by_node_id, rank_by_node_id, node_count, edge_count,
  ).optimized_rank_node_ids_by_rank
}
