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
  optimize_rank_node_ids_by_crossing_phase_with_plan(
    input,
    default_crossing_execution_plan(strategy),
  )
}

///|
fn optimize_rank_node_ids_by_crossing_phase_with_plan(
  input : ElkLayeredCrossingPhaseInput,
  plan : ElkLayeredCrossingExecutionPlan,
) -> Map[Int, Array[String]] {
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
      apply_crossing_local_refinement_kernels(
        build_crossing_refinement_input_from_phase_input(
          optimized_rank_node_ids_by_rank, input,
        ),
        config,
        plan.local_refinement_kernels,
      )
      optimized_rank_node_ids_by_rank
    }
  }
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
  optimize_rank_node_ids_by_crossing_phase(
    build_crossing_phase_input(
      base_rank_node_ids_by_rank, max_rank, predecessors_by_node_id, successors_by_node_id,
      order_index_by_node_id, rank_by_node_id, node_count, edge_count,
    ),
  )
}
