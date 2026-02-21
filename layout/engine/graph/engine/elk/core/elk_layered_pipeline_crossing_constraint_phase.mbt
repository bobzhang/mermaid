///|
fn build_rank_constraint_successors_by_node_id(
  node_ids : Array[String],
  in_layer_successors_by_node_id : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let rank_node_id_set : Map[String, Bool] = {}
  for node_id in node_ids {
    rank_node_id_set[node_id] = true
  }
  let rank_constraint_successors_by_node_id : Map[String, Array[String]] = {}
  for source_id in node_ids {
    let filtered_successors : Array[String] = []
    let seen_successor_by_node_id : Map[String, Bool] = {}
    match in_layer_successors_by_node_id.get(source_id) {
      Some(successors) =>
        for target_id in successors {
          if source_id == target_id || !rank_node_id_set.contains(target_id) {
            continue
          }
          if seen_successor_by_node_id.contains(target_id) {
            continue
          }
          seen_successor_by_node_id[target_id] = true
          filtered_successors.push(target_id)
        }
      None => ()
    }
    if filtered_successors.length() > 0 {
      rank_constraint_successors_by_node_id[source_id] = filtered_successors
    }
  }
  rank_constraint_successors_by_node_id
}

///|
fn rank_constraint_order_index_by_node_id(
  node_ids : Array[String],
) -> Map[String, Int] {
  let rank_order_index_by_node_id : Map[String, Int] = {}
  for index, node_id in node_ids {
    rank_order_index_by_node_id[node_id] = index
  }
  rank_order_index_by_node_id
}

///|
fn next_zero_incoming_constraint_node_id(
  node_ids : Array[String],
  placed_by_node_id : Map[String, Bool],
  incoming_count_by_node_id : Map[String, Int],
  rank_order_index_by_node_id : Map[String, Int],
) -> String? {
  let mut best_node_id = ""
  let mut best_order_index = 0
  let mut has_candidate = false
  for fallback_index, node_id in node_ids {
    if option_bool_or(placed_by_node_id.get(node_id), false) {
      continue
    }
    if option_int_or(incoming_count_by_node_id.get(node_id), 0) != 0 {
      continue
    }
    let order_index = option_int_or(
      rank_order_index_by_node_id.get(node_id),
      fallback_index,
    )
    if !has_candidate || order_index < best_order_index {
      best_node_id = node_id
      best_order_index = order_index
      has_candidate = true
    }
  }
  if has_candidate {
    Some(best_node_id)
  } else {
    None
  }
}

///|
fn next_unplaced_constraint_node_id(
  node_ids : Array[String],
  placed_by_node_id : Map[String, Bool],
  rank_order_index_by_node_id : Map[String, Int],
) -> String? {
  let mut best_node_id = ""
  let mut best_order_index = 0
  let mut has_candidate = false
  for fallback_index, node_id in node_ids {
    if option_bool_or(placed_by_node_id.get(node_id), false) {
      continue
    }
    let order_index = option_int_or(
      rank_order_index_by_node_id.get(node_id),
      fallback_index,
    )
    if !has_candidate || order_index < best_order_index {
      best_node_id = node_id
      best_order_index = order_index
      has_candidate = true
    }
  }
  if has_candidate {
    Some(best_node_id)
  } else {
    None
  }
}

///|
fn apply_crossing_in_layer_successor_constraints(
  node_ids : Array[String],
  in_layer_successors_by_node_id : Map[String, Array[String]],
) -> Bool {
  if node_ids.length() <= 1 {
    return false
  }
  let rank_constraint_successors_by_node_id = build_rank_constraint_successors_by_node_id(
    node_ids, in_layer_successors_by_node_id,
  )
  if rank_constraint_successors_by_node_id.length() == 0 {
    return false
  }
  let rank_order_index_by_node_id = rank_constraint_order_index_by_node_id(
    node_ids,
  )
  let incoming_count_by_node_id : Map[String, Int] = {}
  for node_id in node_ids {
    incoming_count_by_node_id[node_id] = 0
  }
  for _source_id, successors in rank_constraint_successors_by_node_id {
    for successor_id in successors {
      incoming_count_by_node_id[successor_id] = option_int_or(
          incoming_count_by_node_id.get(successor_id),
          0,
        ) +
        1
    }
  }
  let placed_by_node_id : Map[String, Bool] = {}
  let resolved_node_ids : Array[String] = []
  while resolved_node_ids.length() < node_ids.length() {
    let next_node_id = match
      next_zero_incoming_constraint_node_id(
        node_ids, placed_by_node_id, incoming_count_by_node_id, rank_order_index_by_node_id,
      ) {
      Some(node_id) => node_id
      None =>
        match
          next_unplaced_constraint_node_id(
            node_ids, placed_by_node_id, rank_order_index_by_node_id,
          ) {
          Some(node_id) => node_id
          None => return false
        }
    }
    resolved_node_ids.push(next_node_id)
    placed_by_node_id[next_node_id] = true
    match rank_constraint_successors_by_node_id.get(next_node_id) {
      Some(successors) =>
        for successor_id in successors {
          if option_bool_or(placed_by_node_id.get(successor_id), false) {
            continue
          }
          incoming_count_by_node_id[successor_id] = option_int_or(
              incoming_count_by_node_id.get(successor_id),
              0,
            ) -
            1
        }
      None => ()
    }
  }
  let mut changed = false
  for index in 0..<node_ids.length() {
    if node_ids[index] != resolved_node_ids[index] {
      changed = true
      break
    }
  }
  if !changed {
    return false
  }
  node_ids.clear()
  for node_id in resolved_node_ids {
    node_ids.push(node_id)
  }
  true
}
