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
priv struct NodeNeighborOrderKey {
  has_center : Bool
  mean_scaled : Int
}

///|
fn empty_neighbor_order_key() -> NodeNeighborOrderKey {
  { has_center: false, mean_scaled: 0 }
}

///|
fn node_neighbor_order_key(
  node_id : String,
  neighbor_by_node_id : Map[String, Array[String]],
  rank_position_by_node_id : Map[String, Int],
) -> NodeNeighborOrderKey {
  let mut count = 0
  let mut sum = 0
  match neighbor_by_node_id.get(node_id) {
    Some(neighbors) =>
      for neighbor_id in neighbors {
        match rank_position_by_node_id.get(neighbor_id) {
          Some(position) => {
            count += 1
            sum += position
          }
          None => ()
        }
      }
    None => ()
  }
  if count == 0 {
    empty_neighbor_order_key()
  } else {
    let mean_scaled = sum * 1000 / count
    { has_center: true, mean_scaled }
  }
}

///|
fn sort_rank_nodes_by_neighbors(
  node_ids : Array[String],
  neighbor_by_node_id : Map[String, Array[String]],
  rank_position_by_node_id : Map[String, Int],
  order_index_by_node_id : Map[String, Int],
  preserve_current_order_on_tie : Bool,
) -> Unit {
  let neighbor_key_by_node_id : Map[String, NodeNeighborOrderKey] = {}
  for node_id in node_ids {
    neighbor_key_by_node_id[node_id] = node_neighbor_order_key(
      node_id, neighbor_by_node_id, rank_position_by_node_id,
    )
  }
  node_ids.sort_by((left, right) => {
    let left_key = match neighbor_key_by_node_id.get(left) {
      Some(value) => value
      None => empty_neighbor_order_key()
    }
    let right_key = match neighbor_key_by_node_id.get(right) {
      Some(value) => value
      None => empty_neighbor_order_key()
    }
    let left_has_center = left_key.has_center
    let left_mean = left_key.mean_scaled
    let right_has_center = right_key.has_center
    let right_mean = right_key.mean_scaled
    if left_has_center && right_has_center && left_mean != right_mean {
      return left_mean.compare(right_mean)
    }
    if left_has_center != right_has_center {
      if left_has_center {
        -1
      } else {
        1
      }
    } else if preserve_current_order_on_tie {
      option_int_or(
        rank_position_by_node_id.get(left),
        option_int_or(order_index_by_node_id.get(left), 0),
      ).compare(
        option_int_or(
          rank_position_by_node_id.get(right),
          option_int_or(order_index_by_node_id.get(right), 0),
        ),
      )
    } else {
      option_int_or(order_index_by_node_id.get(left), 0).compare(
        option_int_or(order_index_by_node_id.get(right), 0),
      )
    }
  })
}

///|
fn pair_inversion_crossings(edge_pairs : Array[(Int, Int)]) -> Int {
  let mut crossings = 0
  for left_index in 0..<edge_pairs.length() {
    let (left_source_pos, left_target_pos) = edge_pairs[left_index]
    for right_index in (left_index + 1)..<edge_pairs.length() {
      let (right_source_pos, right_target_pos) = edge_pairs[right_index]
      if (
          left_source_pos < right_source_pos &&
          left_target_pos > right_target_pos
        ) ||
        (
          left_source_pos > right_source_pos &&
          left_target_pos < right_target_pos
        ) {
        crossings += 1
      }
    }
  }
  crossings
}

///|
fn layered_crossing_count(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Int {
  let rank_position_by_node_id = rank_position_by_node_id(
    rank_node_ids_by_rank, max_rank,
  )
  let edge_pairs_by_rank_pair : Map[String, Array[(Int, Int)]] = {}
  for source_id, successors in successors_by_node_id {
    let source_rank = option_int_or(rank_by_node_id.get(source_id), -1)
    let source_pos = option_int_or(rank_position_by_node_id.get(source_id), -1)
    if source_rank < 0 || source_pos < 0 {
      continue
    }
    for target_id in successors {
      let target_rank = option_int_or(rank_by_node_id.get(target_id), -1)
      let target_pos = option_int_or(
        rank_position_by_node_id.get(target_id),
        -1,
      )
      if target_rank <= source_rank || target_pos < 0 {
        continue
      }
      let rank_pair_key = "\{source_rank}->\{target_rank}"
      if !edge_pairs_by_rank_pair.contains(rank_pair_key) {
        edge_pairs_by_rank_pair[rank_pair_key] = []
      }
      match edge_pairs_by_rank_pair.get(rank_pair_key) {
        Some(edge_pairs) => edge_pairs.push((source_pos, target_pos))
        None => ()
      }
    }
  }
  let mut crossings = 0
  for _, edge_pairs in edge_pairs_by_rank_pair {
    crossings += pair_inversion_crossings(edge_pairs)
  }
  crossings
}

///|
priv struct RankOrderEdgeSegment {
  source_id : String
  target_id : String
  source_rank : Int
  target_rank : Int
  source_pos : Int
  target_pos : Int
}

///|
fn collect_rank_order_edge_segments(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Array[RankOrderEdgeSegment] {
  let segments : Array[RankOrderEdgeSegment] = []
  let rank_position_by_node_id = rank_position_by_node_id(
    rank_node_ids_by_rank, max_rank,
  )
  for source_id, successors in successors_by_node_id {
    let source_rank = option_int_or(rank_by_node_id.get(source_id), -1)
    let source_pos = option_int_or(rank_position_by_node_id.get(source_id), -1)
    if source_rank < 0 || source_pos < 0 {
      continue
    }
    for target_id in successors {
      let target_rank = option_int_or(rank_by_node_id.get(target_id), -1)
      let target_pos = option_int_or(
        rank_position_by_node_id.get(target_id),
        -1,
      )
      if target_rank <= source_rank || target_pos < 0 {
        continue
      }
      segments.push({
        source_id,
        target_id,
        source_rank,
        target_rank,
        source_pos,
        target_pos,
      })
    }
  }
  segments
}

///|
fn segment_orientation(
  ax : Int,
  ay : Int,
  bx : Int,
  by : Int,
  cx : Int,
  cy : Int,
) -> Int {
  let abx = bx - ax
  let aby = by - ay
  let acx = cx - ax
  let acy = cy - ay
  abx * acy - aby * acx
}

///|
fn rank_order_edge_segments_cross(
  left : RankOrderEdgeSegment,
  right : RankOrderEdgeSegment,
) -> Bool {
  if left.source_id == right.source_id ||
    left.source_id == right.target_id ||
    left.target_id == right.source_id ||
    left.target_id == right.target_id {
    return false
  }
  let overlap_start_rank = left.source_rank.max(right.source_rank)
  let overlap_end_rank = left.target_rank.min(right.target_rank)
  if overlap_end_rank <= overlap_start_rank {
    return false
  }
  let o1 = segment_orientation(
    left.source_rank,
    left.source_pos,
    left.target_rank,
    left.target_pos,
    right.source_rank,
    right.source_pos,
  )
  let o2 = segment_orientation(
    left.source_rank,
    left.source_pos,
    left.target_rank,
    left.target_pos,
    right.target_rank,
    right.target_pos,
  )
  let o3 = segment_orientation(
    right.source_rank,
    right.source_pos,
    right.target_rank,
    right.target_pos,
    left.source_rank,
    left.source_pos,
  )
  let o4 = segment_orientation(
    right.source_rank,
    right.source_pos,
    right.target_rank,
    right.target_pos,
    left.target_rank,
    left.target_pos,
  )
  if o1 == 0 || o2 == 0 || o3 == 0 || o4 == 0 {
    return false
  }
  (o1 > 0) != (o2 > 0) && (o3 > 0) != (o4 > 0)
}

///|
fn global_crossing_count(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Int {
  let segments = collect_rank_order_edge_segments(
    rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  let mut crossings = 0
  for left_index in 0..<segments.length() {
    let left = segments[left_index]
    for right_index in (left_index + 1)..<segments.length() {
      let right = segments[right_index]
      if rank_order_edge_segments_cross(left, right) {
        crossings += 1
      }
    }
  }
  crossings
}

///|
priv struct ElkLayeredCrossingObjectiveContext {
  max_rank : Int
  rank_by_node_id : Map[String, Int]
  successors_by_node_id : Map[String, Array[String]]
}

///|
priv struct ElkLayeredCrossingObjective {
  layered_crossings : Int
  global_crossings : Int
}

///|
priv enum ElkLayeredRankOrderSelectionPolicy {
  LayeredCrossingsPreferAlternateOnTie
}

///|
fn evaluate_crossing_objective(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  context : ElkLayeredCrossingObjectiveContext,
) -> ElkLayeredCrossingObjective {
  {
    layered_crossings: layered_crossing_count(
      rank_node_ids_by_rank,
      context.max_rank,
      context.rank_by_node_id,
      context.successors_by_node_id,
    ),
    global_crossings: global_crossing_count(
      rank_node_ids_by_rank,
      context.max_rank,
      context.rank_by_node_id,
      context.successors_by_node_id,
    ),
  }
}

///|
fn select_rank_order_candidate_by_policy(
  base_rank_node_ids_by_rank : Map[Int, Array[String]],
  alternate_rank_node_ids_by_rank : Map[Int, Array[String]],
  context : ElkLayeredCrossingObjectiveContext,
  policy : ElkLayeredRankOrderSelectionPolicy,
) -> Map[Int, Array[String]] {
  let base_objective = evaluate_crossing_objective(
    base_rank_node_ids_by_rank, context,
  )
  let alternate_objective = evaluate_crossing_objective(
    alternate_rank_node_ids_by_rank, context,
  )
  match policy {
    LayeredCrossingsPreferAlternateOnTie =>
      if alternate_objective.layered_crossings <=
        base_objective.layered_crossings {
        alternate_rank_node_ids_by_rank
      } else {
        base_rank_node_ids_by_rank
      }
  }
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
      let preserve_current_order_on_tie = input.node_count >
        config.preserve_order_node_threshold ||
        input.edge_count > config.preserve_order_edge_threshold
      optimize_rank_order_with_sweep_passes_and_kernel(
        optimized_rank_node_ids_by_rank,
        input.max_rank,
        input.predecessors_by_node_id,
        input.successors_by_node_id,
        input.order_index_by_node_id,
        preserve_current_order_on_tie,
        config.sweep_pass_count,
        plan.sweep_kernel,
      )
      apply_crossing_local_refinement_kernels(
        build_crossing_refinement_input(
          optimized_rank_node_ids_by_rank,
          input.max_rank,
          input.rank_by_node_id,
          input.successors_by_node_id,
          input.node_count,
          input.edge_count,
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

///|
fn rank_order_crossing_score(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Int {
  layered_crossing_count(
    rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
}

///|
fn select_lower_crossing_rank_order(
  base_rank_node_ids_by_rank : Map[Int, Array[String]],
  alternate_rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Map[Int, Array[String]] {
  select_rank_order_candidate_by_policy(
    base_rank_node_ids_by_rank,
    alternate_rank_node_ids_by_rank,
    { max_rank, rank_by_node_id, successors_by_node_id },
    LayeredCrossingsPreferAlternateOnTie,
  )
}

///|
fn optimize_rank_order_with_sweep_passes_and_kernel(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
  preserve_current_order_on_tie : Bool,
  sweep_pass_count : Int,
  sweep_kernel : ElkLayeredCrossingSweepKernel,
) -> Unit {
  optimize_rank_order_with_sweep_passes_from_input(
    build_crossing_sweep_input(
      rank_node_ids_by_rank, max_rank, predecessors_by_node_id, successors_by_node_id,
      order_index_by_node_id, preserve_current_order_on_tie,
    ),
    sweep_pass_count,
    sweep_kernel,
  )
}

///|
fn optimize_rank_order_with_sweep_passes_from_input(
  sweep_input : ElkLayeredCrossingSweepInput,
  sweep_pass_count : Int,
  sweep_kernel : ElkLayeredCrossingSweepKernel,
) -> Unit {
  if sweep_input.max_rank <= 0 {
    return
  }
  let mut pass = 0
  while pass < sweep_pass_count {
    sweep_rank_order_once_from_input_with_kernel(sweep_input, sweep_kernel)
    pass += 1
  }
}

///|
fn sweep_rank_order_once_from_input_with_kernel(
  sweep_input : ElkLayeredCrossingSweepInput,
  sweep_kernel : ElkLayeredCrossingSweepKernel,
) -> Unit {
  if sweep_input.max_rank <= 0 {
    return
  }
  match sweep_kernel {
    NeighborMeanBidirectional => {
      for rank in 1..<=sweep_input.max_rank {
        // Keep the layer-sweep state coherent: each rank update should observe
        // already-updated neighbor order from earlier ranks in the same pass.
        let forward_positions = rank_position_by_node_id(
          sweep_input.rank_node_ids_by_rank,
          sweep_input.max_rank,
        )
        match sweep_input.rank_node_ids_by_rank.get(rank) {
          Some(node_ids) =>
            sort_rank_nodes_by_neighbors(
              node_ids,
              sweep_input.predecessors_by_node_id,
              forward_positions,
              sweep_input.order_index_by_node_id,
              sweep_input.preserve_current_order_on_tie,
            )
          None => ()
        }
      }

      let mut rank = sweep_input.max_rank - 1
      while true {
        let backward_positions = rank_position_by_node_id(
          sweep_input.rank_node_ids_by_rank,
          sweep_input.max_rank,
        )
        match sweep_input.rank_node_ids_by_rank.get(rank) {
          Some(node_ids) =>
            sort_rank_nodes_by_neighbors(
              node_ids,
              sweep_input.successors_by_node_id,
              backward_positions,
              sweep_input.order_index_by_node_id,
              sweep_input.preserve_current_order_on_tie,
            )
          None => ()
        }
        if rank == 0 {
          break
        }
        rank = rank - 1
      }
    }
  }
}
