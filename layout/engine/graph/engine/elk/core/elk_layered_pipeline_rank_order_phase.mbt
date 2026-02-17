///|
priv struct LayeredVirtualOrderingState {
  rank_node_ids_by_rank : Map[Int, Array[String]]
  rank_by_node_id : Map[String, Int]
  order_index_by_node_id : Map[String, Int]
  predecessors_by_node_id : Map[String, Array[String]]
  successors_by_node_id : Map[String, Array[String]]
  virtual_by_node_id : Map[String, Bool]
}

///|
fn clone_rank_node_ids_by_rank(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
) -> Map[Int, Array[String]] {
  let cloned : Map[Int, Array[String]] = {}
  for rank in 0..<=max_rank {
    let copied_node_ids : Array[String] = []
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for node_id in node_ids {
          copied_node_ids.push(node_id)
        }
      None => ()
    }
    cloned[rank] = copied_node_ids
  }
  cloned
}

///|
fn ensure_rank_node_ids_entry(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  rank : Int,
) -> Unit {
  if !rank_node_ids_by_rank.contains(rank) {
    rank_node_ids_by_rank[rank] = []
  }
}

///|
fn append_normalized_ordering_edge(
  source_id : String,
  target_id : String,
  successors_by_node_id : Map[String, Array[String]],
  predecessors_by_node_id : Map[String, Array[String]],
) -> Unit {
  if source_id == target_id {
    return
  }
  match successors_by_node_id.get(source_id) {
    Some(successors) => successors.push(target_id)
    None => successors_by_node_id[source_id] = [target_id]
  }
  match predecessors_by_node_id.get(target_id) {
    Some(predecessors) => predecessors.push(source_id)
    None => predecessors_by_node_id[target_id] = [source_id]
  }
}

///|
fn build_virtual_ordering_state(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  rank_by_node_id : Map[String, Int],
  max_rank : Int,
  order_index_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> LayeredVirtualOrderingState {
  let normalized_rank_node_ids_by_rank = clone_rank_node_ids_by_rank(
    rank_node_ids_by_rank, max_rank,
  )
  let normalized_rank_by_node_id : Map[String, Int] = {}
  let normalized_order_index_by_node_id : Map[String, Int] = {}
  let normalized_predecessors_by_node_id : Map[String, Array[String]] = {}
  let normalized_successors_by_node_id : Map[String, Array[String]] = {}
  let virtual_by_node_id : Map[String, Bool] = {}

  for rank in 0..<=max_rank {
    match normalized_rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for position, node_id in node_ids {
          normalized_rank_by_node_id[node_id] = rank
          normalized_order_index_by_node_id[node_id] = option_int_or(
            order_index_by_node_id.get(node_id),
            rank * 10000 + position,
          )
          normalized_predecessors_by_node_id[node_id] = []
          normalized_successors_by_node_id[node_id] = []
          virtual_by_node_id[node_id] = false
        }
      None => ()
    }
  }

  let mut edge_serial = 0
  for source_id, direct_successors in successors_by_node_id {
    let source_rank = option_int_or(rank_by_node_id.get(source_id), -1)
    if source_rank < 0 {
      continue
    }
    let source_order = option_int_or(order_index_by_node_id.get(source_id), 0)
    for target_id in direct_successors {
      let target_rank = option_int_or(rank_by_node_id.get(target_id), -1)
      if target_rank <= source_rank {
        continue
      }
      let target_order = option_int_or(
        order_index_by_node_id.get(target_id),
        source_order,
      )
      let rank_span = target_rank - source_rank
      let mut previous_id = source_id
      if rank_span > 1 {
        for offset in 1..<rank_span {
          let virtual_rank = source_rank + offset
          let virtual_id = "__elk_virtual_\{edge_serial}_\{offset}"
          ensure_rank_node_ids_entry(
            normalized_rank_node_ids_by_rank, virtual_rank,
          )
          match normalized_rank_node_ids_by_rank.get(virtual_rank) {
            Some(node_ids) => node_ids.push(virtual_id)
            None => ()
          }
          let interpolated_order = (
              source_order * (rank_span - offset) + target_order * offset
            ) *
            1000 /
            rank_span
          normalized_rank_by_node_id[virtual_id] = virtual_rank
          normalized_order_index_by_node_id[virtual_id] = interpolated_order
          normalized_predecessors_by_node_id[virtual_id] = []
          normalized_successors_by_node_id[virtual_id] = []
          virtual_by_node_id[virtual_id] = true
          append_normalized_ordering_edge(
            previous_id, virtual_id, normalized_successors_by_node_id, normalized_predecessors_by_node_id,
          )
          previous_id = virtual_id
        }
      }
      append_normalized_ordering_edge(
        previous_id, target_id, normalized_successors_by_node_id, normalized_predecessors_by_node_id,
      )
      edge_serial += 1
    }
  }

  let mut dense_order = 0
  for rank in 0..<=max_rank {
    match normalized_rank_node_ids_by_rank.get(rank) {
      Some(node_ids) => {
        node_ids.sort_by((left, right) => {
          let left_order = option_int_or(
            normalized_order_index_by_node_id.get(left),
            0,
          )
          let right_order = option_int_or(
            normalized_order_index_by_node_id.get(right),
            0,
          )
          if left_order != right_order {
            left_order.compare(right_order)
          } else {
            left.compare(right)
          }
        })
        for node_id in node_ids {
          normalized_order_index_by_node_id[node_id] = dense_order
          dense_order += 1
        }
      }
      None => ()
    }
  }

  {
    rank_node_ids_by_rank: normalized_rank_node_ids_by_rank,
    rank_by_node_id: normalized_rank_by_node_id,
    order_index_by_node_id: normalized_order_index_by_node_id,
    predecessors_by_node_id: normalized_predecessors_by_node_id,
    successors_by_node_id: normalized_successors_by_node_id,
    virtual_by_node_id,
  }
}

///|
fn filter_real_rank_node_ids_by_rank(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  virtual_by_node_id : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let real_rank_node_ids_by_rank : Map[Int, Array[String]] = {}
  for rank in 0..<=max_rank {
    let real_node_ids : Array[String] = []
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for node_id in node_ids {
          if !option_bool_or(virtual_by_node_id.get(node_id), false) {
            real_node_ids.push(node_id)
          }
        }
      None => ()
    }
    real_rank_node_ids_by_rank[rank] = real_node_ids
  }
  real_rank_node_ids_by_rank
}

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
  let mut best_crossings = layered_crossing_count(
    rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
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
            if swapped_crossings < best_crossings {
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
  if alternate_score < base_score {
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
