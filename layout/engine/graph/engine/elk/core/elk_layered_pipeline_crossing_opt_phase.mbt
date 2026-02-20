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
fn maybe_refine_rank_order_by_swaps(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
  node_count : Int,
  edge_count : Int,
) -> Unit {
  if node_count > 40 || edge_count > 120 {
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
fn maybe_refine_rank_order_by_rank_permutations(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
  node_count : Int,
  edge_count : Int,
) -> Unit {
  if node_count > 28 || edge_count > 80 {
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
          if node_ids.length() <= 1 || node_ids.length() > 6 {
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
fn optimize_rank_node_ids_by_crossing_phase(
  input : ElkLayeredCrossingPhaseInput,
) -> Map[Int, Array[String]] {
  let _ = input.port_order_slots_by_node_id
  let optimized_rank_node_ids_by_rank = clone_rank_node_ids_by_rank(
    input.rank_node_ids_by_rank,
    input.max_rank,
  )
  let preserve_current_order_on_tie = input.node_count > 16 ||
    input.edge_count > 30
  optimize_rank_order(
    optimized_rank_node_ids_by_rank,
    input.max_rank,
    input.predecessors_by_node_id,
    input.successors_by_node_id,
    input.order_index_by_node_id,
    preserve_current_order_on_tie,
  )
  maybe_refine_rank_order_by_swaps(
    optimized_rank_node_ids_by_rank,
    input.max_rank,
    input.rank_by_node_id,
    input.successors_by_node_id,
    input.node_count,
    input.edge_count,
  )
  maybe_refine_rank_order_by_rank_permutations(
    optimized_rank_node_ids_by_rank,
    input.max_rank,
    input.rank_by_node_id,
    input.successors_by_node_id,
    input.node_count,
    input.edge_count,
  )
  optimized_rank_node_ids_by_rank
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
  let base_score = rank_order_crossing_score(
    base_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  let alternate_score = rank_order_crossing_score(
    alternate_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  if alternate_score <= base_score {
    alternate_rank_node_ids_by_rank
  } else {
    base_rank_node_ids_by_rank
  }
}

///|
fn optimize_rank_order(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
  preserve_current_order_on_tie : Bool,
) -> Unit {
  if max_rank <= 0 {
    return
  }
  let mut pass = 0
  while pass < 4 {
    sweep_rank_order_once(
      rank_node_ids_by_rank, max_rank, predecessors_by_node_id, successors_by_node_id,
      order_index_by_node_id, preserve_current_order_on_tie,
    )
    pass += 1
  }
}

///|
fn sweep_rank_order_once(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
  preserve_current_order_on_tie : Bool,
) -> Unit {
  if max_rank <= 0 {
    return
  }
  for rank in 1..<=max_rank {
    // Keep the layer-sweep state coherent: each rank update should observe
    // already-updated neighbor order from earlier ranks in the same pass.
    let forward_positions = rank_position_by_node_id(
      rank_node_ids_by_rank, max_rank,
    )
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        sort_rank_nodes_by_neighbors(
          node_ids, predecessors_by_node_id, forward_positions, order_index_by_node_id,
          preserve_current_order_on_tie,
        )
      None => ()
    }
  }

  let mut rank = max_rank - 1
  while true {
    let backward_positions = rank_position_by_node_id(
      rank_node_ids_by_rank, max_rank,
    )
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        sort_rank_nodes_by_neighbors(
          node_ids, successors_by_node_id, backward_positions, order_index_by_node_id,
          preserve_current_order_on_tie,
        )
      None => ()
    }
    if rank == 0 {
      break
    }
    rank = rank - 1
  }
}
