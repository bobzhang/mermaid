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
fn node_neighbor_order_key(
  node_id : String,
  neighbor_by_node_id : Map[String, Array[String]],
  rank_position_by_node_id : Map[String, Int],
) -> (Bool, Int, Int) {
  let positions : Array[Int] = []
  let mut sum = 0
  match neighbor_by_node_id.get(node_id) {
    Some(neighbors) =>
      for neighbor_id in neighbors {
        match rank_position_by_node_id.get(neighbor_id) {
          Some(position) => {
            positions.push(position)
            sum += position
          }
          None => ()
        }
      }
    None => ()
  }
  if positions.length() == 0 {
    (false, 0, 0)
  } else {
    positions.sort()
    let count = positions.length()
    let median_scaled = if count % 2 == 1 {
      positions[count / 2] * 1000
    } else {
      (positions[count / 2 - 1] + positions[count / 2]) * 500
    }
    let mean_scaled = sum * 1000 / count
    (true, median_scaled, mean_scaled)
  }
}

///|
fn sort_rank_nodes_by_neighbors(
  node_ids : Array[String],
  neighbor_by_node_id : Map[String, Array[String]],
  rank_position_by_node_id : Map[String, Int],
  order_index_by_node_id : Map[String, Int],
) -> Unit {
  node_ids.sort_by((left, right) => {
    let (left_has_center, left_median, left_mean) = node_neighbor_order_key(
      left, neighbor_by_node_id, rank_position_by_node_id,
    )
    let (right_has_center, right_median, right_mean) = node_neighbor_order_key(
      right, neighbor_by_node_id, rank_position_by_node_id,
    )
    if left_has_center && right_has_center && left_median != right_median {
      return left_median.compare(right_median)
    }
    if left_has_center && right_has_center && left_mean != right_mean {
      return left_mean.compare(right_mean)
    }
    if left_has_center != right_has_center {
      if left_has_center {
        -1
      } else {
        1
      }
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
  let best_layered_crossings = layered_crossing_count(
    rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  let max_allowed_layered_crossings = best_layered_crossings
  let mut best_global_crossings = global_crossing_count(
    rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  let mut best_crossings = best_layered_crossings
  let mut pass = 0
  while pass < 3 {
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
            let swapped_crossings = layered_crossing_count(
              rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
            )
            if swapped_crossings > max_allowed_layered_crossings {
              node_ids[i] = left
              node_ids[i + 1] = right
              i = i + 1
              continue
            }
            let swapped_global_crossings = global_crossing_count(
              rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
            )
            if swapped_global_crossings < best_global_crossings ||
              (
                swapped_global_crossings == best_global_crossings &&
                swapped_crossings < best_crossings
              ) {
              best_global_crossings = swapped_global_crossings
              best_crossings = swapped_crossings
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

  let initial_layered_crossings = layered_crossing_count(
    rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  let max_allowed_layered_crossings = initial_layered_crossings
  let mut best_layered_crossings = initial_layered_crossings
  let mut best_global_crossings = global_crossing_count(
    rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )

  let mut pass = 0
  while pass < 2 {
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
            let candidate_layered_crossings = layered_crossing_count(
              rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
            )
            if candidate_layered_crossings > max_allowed_layered_crossings {
              return
            }
            let candidate_global_crossings = global_crossing_count(
              rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
            )
            if candidate_global_crossings < best_global_crossings ||
              (
                candidate_global_crossings == best_global_crossings &&
                candidate_layered_crossings < best_layered_crossings
              ) {
              best_layered_crossings = candidate_layered_crossings
              best_global_crossings = candidate_global_crossings
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
  let optimized_rank_node_ids_by_rank = clone_rank_node_ids_by_rank(
    base_rank_node_ids_by_rank, max_rank,
  )
  optimize_rank_order(
    optimized_rank_node_ids_by_rank, max_rank, predecessors_by_node_id, successors_by_node_id,
    order_index_by_node_id,
  )
  maybe_refine_rank_order_by_swaps(
    optimized_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
    node_count, edge_count,
  )
  maybe_refine_rank_order_by_rank_permutations(
    optimized_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
    node_count, edge_count,
  )
  optimized_rank_node_ids_by_rank
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
) -> Unit {
  if max_rank <= 0 {
    return
  }
  let mut pass = 0
  while pass < 4 {
    let forward_positions = rank_position_by_node_id(
      rank_node_ids_by_rank, max_rank,
    )
    for rank in 1..<=max_rank {
      match rank_node_ids_by_rank.get(rank) {
        Some(node_ids) =>
          sort_rank_nodes_by_neighbors(
            node_ids, predecessors_by_node_id, forward_positions, order_index_by_node_id,
          )
        None => ()
      }
    }

    let backward_positions = rank_position_by_node_id(
      rank_node_ids_by_rank, max_rank,
    )
    let mut rank = max_rank - 1
    while true {
      match rank_node_ids_by_rank.get(rank) {
        Some(node_ids) =>
          sort_rank_nodes_by_neighbors(
            node_ids, successors_by_node_id, backward_positions, order_index_by_node_id,
          )
        None => ()
      }
      if rank == 0 {
        break
      }
      rank = rank - 1
    }
    pass += 1
  }
}
