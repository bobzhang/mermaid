///|
fn rank_position_by_node_id(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
) -> Map[String, Int] {
  let rank_position_by_node_id : Map[String, Int] = {}
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for position, node_id in node_ids {
          rank_position_by_node_id[node_id] = position
        }
      None => ()
    }
  }
  rank_position_by_node_id
}

///|
priv struct ElkLayeredCrossingPhaseInput {
  rank_node_ids_by_rank : Map[Int, Array[String]]
  max_rank : Int
  predecessors_by_node_id : Map[String, Array[String]]
  successors_by_node_id : Map[String, Array[String]]
  order_index_by_node_id : Map[String, Int]
  rank_by_node_id : Map[String, Int]
  node_count : Int
  edge_count : Int
  // Reserved for future port-aware crossing objective alignment.
  port_order_slots_by_node_id : Map[String, Array[Int]]
}

///|
priv enum ElkLayeredCrossingOptimizerStrategy {
  LayerSweepWithLocalRefinement
}

///|
priv enum ElkLayeredCrossingSweepKernel {
  NeighborMeanBidirectional
}

///|
priv enum ElkLayeredCrossingLocalRefinementKernel {
  AdjacentSwap
  RankPermutation
}

///|
fn default_crossing_sweep_kernel() -> ElkLayeredCrossingSweepKernel {
  NeighborMeanBidirectional
}

///|
priv struct ElkLayeredCrossingOptimizationConfig {
  preserve_order_node_threshold : Int
  preserve_order_edge_threshold : Int
  sweep_pass_count : Int
  swap_refine_node_limit : Int
  swap_refine_edge_limit : Int
  permutation_refine_node_limit : Int
  permutation_refine_edge_limit : Int
  permutation_rank_size_limit : Int
}

///|
fn default_crossing_optimization_config() -> ElkLayeredCrossingOptimizationConfig {
  {
    preserve_order_node_threshold: 16,
    preserve_order_edge_threshold: 30,
    sweep_pass_count: 4,
    swap_refine_node_limit: 40,
    swap_refine_edge_limit: 120,
    permutation_refine_node_limit: 28,
    permutation_refine_edge_limit: 80,
    permutation_rank_size_limit: 6,
  }
}

///|
priv struct ElkLayeredCrossingExecutionPlan {
  strategy : ElkLayeredCrossingOptimizerStrategy
  config : ElkLayeredCrossingOptimizationConfig
  sweep_kernel : ElkLayeredCrossingSweepKernel
  local_refinement_kernels : Array[ElkLayeredCrossingLocalRefinementKernel]
}

///|
fn default_crossing_local_refinement_kernels() -> Array[
  ElkLayeredCrossingLocalRefinementKernel,
] {
  [AdjacentSwap, RankPermutation]
}

///|
fn default_crossing_execution_plan(
  strategy : ElkLayeredCrossingOptimizerStrategy,
) -> ElkLayeredCrossingExecutionPlan {
  {
    strategy,
    config: default_crossing_optimization_config(),
    sweep_kernel: default_crossing_sweep_kernel(),
    local_refinement_kernels: default_crossing_local_refinement_kernels(),
  }
}

///|
fn build_default_port_order_slots_by_node_id(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
) -> Map[String, Array[Int]] {
  let port_order_slots_by_node_id : Map[String, Array[Int]] = {}
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for node_id in node_ids {
          port_order_slots_by_node_id[node_id] = []
        }
      None => ()
    }
  }
  port_order_slots_by_node_id
}

///|
fn build_crossing_phase_input(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
  rank_by_node_id : Map[String, Int],
  node_count : Int,
  edge_count : Int,
) -> ElkLayeredCrossingPhaseInput {
  {
    rank_node_ids_by_rank,
    max_rank,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    rank_by_node_id,
    node_count,
    edge_count,
    port_order_slots_by_node_id: build_default_port_order_slots_by_node_id(
      rank_node_ids_by_rank, max_rank,
    ),
  }
}

///|
priv struct ElkLayeredCrossingSweepInput {
  rank_node_ids_by_rank : Map[Int, Array[String]]
  max_rank : Int
  predecessors_by_node_id : Map[String, Array[String]]
  successors_by_node_id : Map[String, Array[String]]
  order_index_by_node_id : Map[String, Int]
  preserve_current_order_on_tie : Bool
}

///|
fn build_crossing_sweep_input(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
  preserve_current_order_on_tie : Bool,
) -> ElkLayeredCrossingSweepInput {
  {
    rank_node_ids_by_rank,
    max_rank,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    preserve_current_order_on_tie,
  }
}

///|
fn crossing_preserve_current_order_on_tie(
  node_count : Int,
  edge_count : Int,
  config : ElkLayeredCrossingOptimizationConfig,
) -> Bool {
  node_count > config.preserve_order_node_threshold ||
  edge_count > config.preserve_order_edge_threshold
}

///|
fn build_crossing_sweep_input_from_phase_input(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  input : ElkLayeredCrossingPhaseInput,
  config : ElkLayeredCrossingOptimizationConfig,
) -> ElkLayeredCrossingSweepInput {
  build_crossing_sweep_input(
    rank_node_ids_by_rank,
    input.max_rank,
    input.predecessors_by_node_id,
    input.successors_by_node_id,
    input.order_index_by_node_id,
    crossing_preserve_current_order_on_tie(
      input.node_count,
      input.edge_count,
      config,
    ),
  )
}

///|
priv struct ElkLayeredCrossingRefinementInput {
  rank_node_ids_by_rank : Map[Int, Array[String]]
  max_rank : Int
  rank_by_node_id : Map[String, Int]
  successors_by_node_id : Map[String, Array[String]]
  node_count : Int
  edge_count : Int
}

///|
fn build_crossing_refinement_input(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
  node_count : Int,
  edge_count : Int,
) -> ElkLayeredCrossingRefinementInput {
  {
    rank_node_ids_by_rank,
    max_rank,
    rank_by_node_id,
    successors_by_node_id,
    node_count,
    edge_count,
  }
}

///|
fn build_crossing_refinement_input_from_phase_input(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  input : ElkLayeredCrossingPhaseInput,
) -> ElkLayeredCrossingRefinementInput {
  build_crossing_refinement_input(
    rank_node_ids_by_rank,
    input.max_rank,
    input.rank_by_node_id,
    input.successors_by_node_id,
    input.node_count,
    input.edge_count,
  )
}

///|
fn maybe_refine_rank_order_by_swaps_with_limits(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
  node_count : Int,
  edge_count : Int,
  node_limit : Int,
  edge_limit : Int,
) -> Unit {
  if node_count > node_limit || edge_count > edge_limit {
    return
  }
  let context : ElkLayeredCrossingObjectiveContext = {
    max_rank,
    rank_by_node_id,
    successors_by_node_id,
  }
  let mut best_objective = evaluate_crossing_objective(
    rank_node_ids_by_rank, context,
  )
  let max_allowed_layered_crossings = best_objective.layered_crossings
  let mut pass = 0
  // Keep local swap refinement shallow: additional passes tend to overfit
  // rank order with marginal crossing gains and larger upstream parity drift.
  while pass < 1 {
    let mut improved = false
    for rank in 0..<=max_rank {
      match rank_node_ids_by_rank.get(rank) {
        Some(node_ids) => {
          if node_ids.length() <= 1 {
            continue
          }
          let mut i = 0
          while i + 1 < node_ids.length() {
            let left = node_ids[i]
            let right = node_ids[i + 1]
            node_ids[i] = right
            node_ids[i + 1] = left
            let swapped_objective = evaluate_crossing_objective(
              rank_node_ids_by_rank, context,
            )
            if swapped_objective.layered_crossings >
              max_allowed_layered_crossings {
              node_ids[i] = left
              node_ids[i + 1] = right
              i = i + 1
              continue
            }
            if swapped_objective.global_crossings <
              best_objective.global_crossings ||
              (
                swapped_objective.global_crossings ==
                best_objective.global_crossings &&
                swapped_objective.layered_crossings <
                best_objective.layered_crossings
              ) {
              best_objective = swapped_objective
              improved = true
            } else {
              node_ids[i] = left
              node_ids[i + 1] = right
            }
            i = i + 1
          }
        }
        None => ()
      }
    }
    if !improved {
      break
    }
    pass += 1
  }
}

///|
fn permutation_swap(
  values : Array[String],
  left_index : Int,
  right_index : Int,
) -> Unit {
  if left_index == right_index {
    return
  }
  let left = values[left_index]
  values[left_index] = values[right_index]
  values[right_index] = left
}

///|
fn for_each_rank_permutation(
  values : Array[String],
  visit : (Array[String]) -> Unit,
) -> Unit {
  let working = values.copy()
  fn walk(start_index : Int) -> Unit {
    if start_index >= working.length() {
      visit(working.copy())
      return
    }
    for index in start_index..<working.length() {
      permutation_swap(working, start_index, index)
      walk(start_index + 1)
      permutation_swap(working, start_index, index)
    }
  }
  walk(0)
}

///|
fn maybe_refine_rank_order_by_rank_permutations_with_limits(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
  node_count : Int,
  edge_count : Int,
  node_limit : Int,
  edge_limit : Int,
  rank_size_limit : Int,
) -> Unit {
  if node_count > node_limit || edge_count > edge_limit {
    return
  }

  let context : ElkLayeredCrossingObjectiveContext = {
    max_rank,
    rank_by_node_id,
    successors_by_node_id,
  }
  let initial_objective = evaluate_crossing_objective(
    rank_node_ids_by_rank, context,
  )
  let max_allowed_layered_crossings = initial_objective.layered_crossings
  let mut best_objective = initial_objective

  let mut pass = 0
  // Mirror the shallow refinement bound used by adjacent-swap search.
  while pass < 1 {
    let mut improved = false
    for rank in 0..<=max_rank {
      match rank_node_ids_by_rank.get(rank) {
        Some(node_ids) => {
          if node_ids.length() <= 1 || node_ids.length() > rank_size_limit {
            continue
          }
          let original_order = node_ids.copy()
          let mut best_order = original_order
          for_each_rank_permutation(original_order, fn(candidate_order) {
            node_ids.clear()
            for node_id in candidate_order {
              node_ids.push(node_id)
            }
            let candidate_objective = evaluate_crossing_objective(
              rank_node_ids_by_rank, context,
            )
            if candidate_objective.layered_crossings >
              max_allowed_layered_crossings {
              return
            }
            if candidate_objective.global_crossings <
              best_objective.global_crossings ||
              (
                candidate_objective.global_crossings ==
                best_objective.global_crossings &&
                candidate_objective.layered_crossings <
                best_objective.layered_crossings
              ) {
              best_objective = candidate_objective
              best_order = candidate_order
              improved = true
            }
          })
          node_ids.clear()
          for node_id in best_order {
            node_ids.push(node_id)
          }
        }
        None => ()
      }
    }
    if !improved {
      break
    }
    pass += 1
  }
}

///|
fn apply_crossing_local_refinement_with_kernel(
  refinement_input : ElkLayeredCrossingRefinementInput,
  config : ElkLayeredCrossingOptimizationConfig,
  kernel : ElkLayeredCrossingLocalRefinementKernel,
) -> Unit {
  match kernel {
    AdjacentSwap =>
      maybe_refine_rank_order_by_swaps_with_limits(
        refinement_input.rank_node_ids_by_rank,
        refinement_input.max_rank,
        refinement_input.rank_by_node_id,
        refinement_input.successors_by_node_id,
        refinement_input.node_count,
        refinement_input.edge_count,
        config.swap_refine_node_limit,
        config.swap_refine_edge_limit,
      )
    RankPermutation =>
      maybe_refine_rank_order_by_rank_permutations_with_limits(
        refinement_input.rank_node_ids_by_rank,
        refinement_input.max_rank,
        refinement_input.rank_by_node_id,
        refinement_input.successors_by_node_id,
        refinement_input.node_count,
        refinement_input.edge_count,
        config.permutation_refine_node_limit,
        config.permutation_refine_edge_limit,
        config.permutation_rank_size_limit,
      )
  }
}

///|
fn apply_crossing_local_refinement_kernels(
  refinement_input : ElkLayeredCrossingRefinementInput,
  config : ElkLayeredCrossingOptimizationConfig,
  kernels : Array[ElkLayeredCrossingLocalRefinementKernel],
) -> Unit {
  for kernel in kernels {
    apply_crossing_local_refinement_with_kernel(
      refinement_input, config, kernel,
    )
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
