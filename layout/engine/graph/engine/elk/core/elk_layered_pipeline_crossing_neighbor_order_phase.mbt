///|
priv struct NodeNeighborOrderKey {
  has_center : Bool
  neighbor_position_sum : Int
  neighbor_position_count : Int
}

///|
fn empty_neighbor_order_key() -> NodeNeighborOrderKey {
  { has_center: false, neighbor_position_sum: 0, neighbor_position_count: 0 }
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
    {
      has_center: true,
      neighbor_position_sum: sum,
      neighbor_position_count: count,
    }
  }
}

///|
fn node_neighbor_positions(
  node_id : String,
  neighbor_by_node_id : Map[String, Array[String]],
  rank_position_by_node_id : Map[String, Int],
) -> Array[Int] {
  let positions : Array[Int] = []
  match neighbor_by_node_id.get(node_id) {
    Some(neighbors) =>
      for neighbor_id in neighbors {
        match rank_position_by_node_id.get(neighbor_id) {
          Some(position) => positions.push(position)
          None => ()
        }
      }
    None => ()
  }
  positions
}

///|
fn compare_neighbor_order_key(
  left : NodeNeighborOrderKey,
  right : NodeNeighborOrderKey,
) -> Int {
  if left.has_center && right.has_center {
    let left_scaled = left.neighbor_position_sum * right.neighbor_position_count
    let right_scaled = right.neighbor_position_sum *
      left.neighbor_position_count
    left_scaled.compare(right_scaled)
  } else if left.has_center != right.has_center {
    if left.has_center {
      -1
    } else {
      1
    }
  } else {
    0
  }
}

///|
priv struct NodeNeighborMedianOrderKey {
  has_center : Bool
  median_x2 : Int
}

///|
fn empty_neighbor_median_order_key() -> NodeNeighborMedianOrderKey {
  { has_center: false, median_x2: 0 }
}

///|
fn node_neighbor_median_order_key(
  node_id : String,
  neighbor_by_node_id : Map[String, Array[String]],
  rank_position_by_node_id : Map[String, Int],
) -> NodeNeighborMedianOrderKey {
  let positions = node_neighbor_positions(
    node_id, neighbor_by_node_id, rank_position_by_node_id,
  )
  if positions.length() == 0 {
    return empty_neighbor_median_order_key()
  }
  positions.sort()
  let median_x2 = if positions.length() % 2 == 1 {
    positions[positions.length() / 2] * 2
  } else {
    positions[positions.length() / 2 - 1] + positions[positions.length() / 2]
  }
  { has_center: true, median_x2 }
}

///|
fn compare_neighbor_median_order_key(
  left : NodeNeighborMedianOrderKey,
  right : NodeNeighborMedianOrderKey,
) -> Int {
  if left.has_center && right.has_center {
    left.median_x2.compare(right.median_x2)
  } else if left.has_center != right.has_center {
    if left.has_center {
      -1
    } else {
      1
    }
  } else {
    0
  }
}

///|
fn sort_rank_nodes_by_neighbors(
  node_ids : Array[String],
  neighbor_by_node_id : Map[String, Array[String]],
  rank_position_by_node_id : Map[String, Int],
  order_index_by_node_id : Map[String, Int],
  preserve_current_order_on_tie : Bool,
) -> Bool {
  let original_node_ids = node_ids.copy()
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
    let neighbor_order_compare = compare_neighbor_order_key(left_key, right_key)
    if neighbor_order_compare != 0 {
      neighbor_order_compare
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
  let mut changed = false
  for index in 0..<node_ids.length() {
    if node_ids[index] != original_node_ids[index] {
      changed = true
      break
    }
  }
  changed
}

///|
fn sort_rank_nodes_by_neighbors_median(
  node_ids : Array[String],
  neighbor_by_node_id : Map[String, Array[String]],
  rank_position_by_node_id : Map[String, Int],
  order_index_by_node_id : Map[String, Int],
  preserve_current_order_on_tie : Bool,
) -> Bool {
  let original_node_ids = node_ids.copy()
  let neighbor_key_by_node_id : Map[String, NodeNeighborMedianOrderKey] = {}
  for node_id in node_ids {
    neighbor_key_by_node_id[node_id] = node_neighbor_median_order_key(
      node_id, neighbor_by_node_id, rank_position_by_node_id,
    )
  }
  node_ids.sort_by((left, right) => {
    let left_key = match neighbor_key_by_node_id.get(left) {
      Some(value) => value
      None => empty_neighbor_median_order_key()
    }
    let right_key = match neighbor_key_by_node_id.get(right) {
      Some(value) => value
      None => empty_neighbor_median_order_key()
    }
    let neighbor_order_compare = compare_neighbor_median_order_key(
      left_key, right_key,
    )
    if neighbor_order_compare != 0 {
      neighbor_order_compare
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
  let mut changed = false
  for index in 0..<node_ids.length() {
    if node_ids[index] != original_node_ids[index] {
      changed = true
      break
    }
  }
  changed
}
