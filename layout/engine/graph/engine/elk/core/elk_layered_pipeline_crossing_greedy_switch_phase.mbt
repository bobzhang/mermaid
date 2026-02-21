///|
fn crossing_greedy_build_node_id_set(
  node_ids : Array[String],
) -> Map[String, Bool] {
  let node_id_set : Map[String, Bool] = {}
  for node_id in node_ids {
    node_id_set[node_id] = true
  }
  node_id_set
}

///|
fn crossing_greedy_neighbor_positions(
  free_node_id : String,
  fixed_neighbor_by_node_id : Map[String, Array[String]],
  fixed_rank_position_by_node_id : Map[String, Int],
  free_node_id_set : Map[String, Bool],
) -> Array[Int] {
  let positions : Array[Int] = []
  match fixed_neighbor_by_node_id.get(free_node_id) {
    Some(neighbor_ids) =>
      for neighbor_id in neighbor_ids {
        if option_bool_or(free_node_id_set.get(neighbor_id), false) {
          continue
        }
        match fixed_rank_position_by_node_id.get(neighbor_id) {
          Some(position) => positions.push(position)
          None => ()
        }
      }
    None => ()
  }
  positions
}

///|
fn crossing_greedy_pair_crossings_if_left_before_right(
  left_positions : Array[Int],
  right_positions : Array[Int],
) -> Int {
  let mut crossings = 0
  for left_position in left_positions {
    for right_position in right_positions {
      if left_position > right_position {
        crossings += 1
      }
    }
  }
  crossings
}

///|
fn crossing_greedy_should_swap_adjacent_pair(
  left_node_id : String,
  right_node_id : String,
  predecessor_by_node_id : Map[String, Array[String]],
  successor_by_node_id : Map[String, Array[String]],
  rank_position_by_node_id : Map[String, Int],
  free_node_id_set : Map[String, Bool],
  order_index_by_node_id : Map[String, Int],
  preserve_current_order_on_tie : Bool,
) -> Bool {
  let predecessor_left_positions = crossing_greedy_neighbor_positions(
    left_node_id, predecessor_by_node_id, rank_position_by_node_id, free_node_id_set,
  )
  let predecessor_right_positions = crossing_greedy_neighbor_positions(
    right_node_id, predecessor_by_node_id, rank_position_by_node_id, free_node_id_set,
  )
  let successor_left_positions = crossing_greedy_neighbor_positions(
    left_node_id, successor_by_node_id, rank_position_by_node_id, free_node_id_set,
  )
  let successor_right_positions = crossing_greedy_neighbor_positions(
    right_node_id, successor_by_node_id, rank_position_by_node_id, free_node_id_set,
  )
  if predecessor_left_positions.length() == 0 &&
    predecessor_right_positions.length() == 0 &&
    successor_left_positions.length() == 0 &&
    successor_right_positions.length() == 0 {
    return false
  }

  let current_crossings = crossing_greedy_pair_crossings_if_left_before_right(
      predecessor_left_positions, predecessor_right_positions,
    ) +
    crossing_greedy_pair_crossings_if_left_before_right(
      successor_left_positions, successor_right_positions,
    )
  let swapped_crossings = crossing_greedy_pair_crossings_if_left_before_right(
      predecessor_right_positions, predecessor_left_positions,
    ) +
    crossing_greedy_pair_crossings_if_left_before_right(
      successor_right_positions, successor_left_positions,
    )
  if swapped_crossings < current_crossings {
    return true
  }
  if swapped_crossings > current_crossings {
    return false
  }
  if preserve_current_order_on_tie {
    return false
  }
  option_int_or(order_index_by_node_id.get(right_node_id), 0) <
  option_int_or(order_index_by_node_id.get(left_node_id), 0)
}

///|
fn apply_crossing_greedy_switch_rank_by_fixed_layer(
  node_ids : Array[String],
  predecessor_by_node_id : Map[String, Array[String]],
  successor_by_node_id : Map[String, Array[String]],
  rank_position_by_node_id : Map[String, Int],
  order_index_by_node_id : Map[String, Int],
  preserve_current_order_on_tie : Bool,
  pass_limit : Int,
) -> Bool {
  if node_ids.length() <= 1 || pass_limit <= 0 {
    return false
  }
  let free_node_id_set = crossing_greedy_build_node_id_set(node_ids)
  let mut changed = false
  let mut pass = 0
  while pass < pass_limit {
    let mut pass_changed = false
    let mut index = 0
    while index + 1 < node_ids.length() {
      let left_node_id = node_ids[index]
      let right_node_id = node_ids[index + 1]
      if crossing_greedy_should_swap_adjacent_pair(
          left_node_id, right_node_id, predecessor_by_node_id, successor_by_node_id,
          rank_position_by_node_id, free_node_id_set, order_index_by_node_id, preserve_current_order_on_tie,
        ) {
        node_ids[index] = right_node_id
        node_ids[index + 1] = left_node_id
        changed = true
        pass_changed = true
      }
      index += 1
    }
    if !pass_changed {
      break
    }
    pass += 1
  }
  changed
}
