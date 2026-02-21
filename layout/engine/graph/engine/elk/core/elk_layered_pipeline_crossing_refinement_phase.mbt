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
