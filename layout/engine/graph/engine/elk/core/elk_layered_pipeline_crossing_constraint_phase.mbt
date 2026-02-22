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
priv struct CrossingConstraintGroup {
  node_ids : Array[String]
  barycenter : Double
  summed_weight : Double
  degree : Int
}

///|
let crossing_constraint_barycenter_equality_delta = 0.0001

///|
fn build_crossing_constraint_groups(
  node_ids : Array[String],
  barycenter_by_node_id : Map[String, Double],
  degree_by_node_id : Map[String, Int],
) -> Array[CrossingConstraintGroup] {
  let groups : Array[CrossingConstraintGroup] = []
  for index, node_id in node_ids {
    let barycenter = match barycenter_by_node_id.get(node_id) {
      Some(value) => value
      None => index.to_double()
    }
    let degree = match degree_by_node_id.get(node_id) {
      Some(value) => if value > 0 { value } else { 1 }
      None => 1
    }
    groups.push({
      node_ids: [node_id],
      barycenter,
      summed_weight: barycenter * degree.to_double(),
      degree,
    })
  }
  groups
}

///|
fn crossing_constraint_group_index_by_node_id(
  groups : Array[CrossingConstraintGroup],
) -> Map[String, Int] {
  let group_index_by_node_id : Map[String, Int] = {}
  for group_index, group in groups {
    for node_id in group.node_ids {
      group_index_by_node_id[node_id] = group_index
    }
  }
  group_index_by_node_id
}

///|
fn find_first_forster_violated_constraint(
  groups : Array[CrossingConstraintGroup],
  rank_constraint_successors_by_node_id : Map[String, Array[String]],
) -> (Int, Int)? {
  let group_index_by_node_id = crossing_constraint_group_index_by_node_id(
    groups,
  )
  for source_group_index, source_group in groups {
    let seen_target_group_by_index : Map[Int, Bool] = {}
    for source_node_id in source_group.node_ids {
      match rank_constraint_successors_by_node_id.get(source_node_id) {
        Some(target_node_ids) =>
          for target_node_id in target_node_ids {
            let target_group_index = option_int_or(
              group_index_by_node_id.get(target_node_id),
              -1,
            )
            if target_group_index < 0 ||
              target_group_index == source_group_index ||
              seen_target_group_by_index.contains(target_group_index) {
              continue
            }
            seen_target_group_by_index[target_group_index] = true
            if source_group_index > target_group_index {
              let source_barycenter = source_group.barycenter
              let target_barycenter = groups[target_group_index].barycenter
              let barycenter_delta = source_barycenter - target_barycenter
              let barycenter_abs_delta = if barycenter_delta < 0.0 {
                -barycenter_delta
              } else {
                barycenter_delta
              }
              if source_barycenter >
                target_barycenter +
                crossing_constraint_barycenter_equality_delta ||
                (
                  barycenter_abs_delta <=
                  crossing_constraint_barycenter_equality_delta &&
                  source_group_index > target_group_index
                ) {
                return Some((source_group_index, target_group_index))
              }
            }
          }
        None => ()
      }
    }
  }
  None
}

///|
fn merge_crossing_constraint_groups(
  groups : Array[CrossingConstraintGroup],
  first_group_index : Int,
  second_group_index : Int,
) -> Array[CrossingConstraintGroup] {
  let first_group = groups[first_group_index]
  let second_group = groups[second_group_index]
  let merged_node_ids = first_group.node_ids.copy()
  for node_id in second_group.node_ids {
    merged_node_ids.push(node_id)
  }
  let merged_summed_weight = first_group.summed_weight +
    second_group.summed_weight
  let merged_degree = first_group.degree + second_group.degree
  let merged_barycenter = if merged_degree > 0 {
    merged_summed_weight / merged_degree.to_double()
  } else {
    (first_group.barycenter + second_group.barycenter) / 2.0
  }
  let merged_group : CrossingConstraintGroup = {
    node_ids: merged_node_ids,
    barycenter: merged_barycenter,
    summed_weight: merged_summed_weight,
    degree: merged_degree,
  }

  let merged_groups : Array[CrossingConstraintGroup] = []
  let mut inserted = false
  for index, group in groups {
    if index == first_group_index || index == second_group_index {
      continue
    }
    if !inserted && group.barycenter > merged_group.barycenter {
      merged_groups.push(merged_group)
      inserted = true
    }
    merged_groups.push(group)
  }
  if !inserted {
    merged_groups.push(merged_group)
  }
  merged_groups
}

///|
fn flatten_crossing_constraint_groups(
  groups : Array[CrossingConstraintGroup],
) -> Array[String] {
  let resolved_node_ids : Array[String] = []
  for group in groups {
    for node_id in group.node_ids {
      resolved_node_ids.push(node_id)
    }
  }
  resolved_node_ids
}

///|
fn apply_crossing_in_layer_successor_constraints_forster(
  node_ids : Array[String],
  in_layer_successors_by_node_id : Map[String, Array[String]],
  barycenter_by_node_id : Map[String, Double],
  degree_by_node_id : Map[String, Int],
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
  let mut groups = build_crossing_constraint_groups(
    node_ids, barycenter_by_node_id, degree_by_node_id,
  )
  while true {
    match
      find_first_forster_violated_constraint(
        groups, rank_constraint_successors_by_node_id,
      ) {
      Some((first_group_index, second_group_index)) =>
        groups = merge_crossing_constraint_groups(
          groups, first_group_index, second_group_index,
        )
      None => break
    }
  }
  let resolved_node_ids = flatten_crossing_constraint_groups(groups)
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
