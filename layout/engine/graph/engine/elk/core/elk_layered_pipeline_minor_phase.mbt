///|
fn positioned_index_by_node_id(
  positioned_nodes : Array[PositionedNode],
) -> Map[String, Int] {
  let index_by_node_id : Map[String, Int] = {}
  for index, node in positioned_nodes {
    index_by_node_id[node.id] = index
  }
  index_by_node_id
}

///|
fn minor_node_size(
  node_id : String,
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Int {
  if horizontal {
    option_int_or(height_by_node_id.get(node_id), 44)
  } else {
    option_int_or(width_by_node_id.get(node_id), 70)
  }
}

///|
fn rank_pair_minor_gap(
  left_node_id : String,
  right_node_id : String,
  minor_step : Int,
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Int {
  let left_size = minor_node_size(
    left_node_id, horizontal, width_by_node_id, height_by_node_id,
  )
  let right_size = minor_node_size(
    right_node_id, horizontal, width_by_node_id, height_by_node_id,
  )
  let size_gap = (left_size + right_size) / 2 + 12
  size_gap.max(minor_step)
}

///|
fn node_neighbor_minor_coords(
  node_id : String,
  neighbor_by_node_id : Map[String, Array[String]],
  minor_coord_by_node_id : Map[String, Int],
) -> Array[Int] {
  let coords : Array[Int] = []
  match neighbor_by_node_id.get(node_id) {
    Some(neighbors) =>
      for neighbor_id in neighbors {
        match minor_coord_by_node_id.get(neighbor_id) {
          Some(minor_coord) => coords.push(minor_coord)
          None => ()
        }
      }
    None => ()
  }
  coords
}

///|
fn node_neighbor_minor_center(
  node_id : String,
  neighbor_by_node_id : Map[String, Array[String]],
  minor_coord_by_node_id : Map[String, Int],
) -> (Bool, Int) {
  let coords = node_neighbor_minor_coords(
    node_id, neighbor_by_node_id, minor_coord_by_node_id,
  )
  if coords.length() == 0 {
    (false, 0)
  } else {
    let mut sum = 0
    for coord in coords {
      sum += coord
    }
    (true, sum / coords.length())
  }
}

///|
fn resolve_rank_desired_minor_coords(
  node_ids : Array[String],
  neighbor_by_node_id : Map[String, Array[String]],
  minor_coord_by_node_id : Map[String, Int],
  default_minor_start : Int,
  minor_step : Int,
) -> Array[Int] {
  let desired : Array[Int] = []
  for lane, node_id in node_ids {
    let default_minor = default_minor_start + lane * minor_step
    let (has_neighbor_minor_center, neighbor_minor_center) = node_neighbor_minor_center(
      node_id, neighbor_by_node_id, minor_coord_by_node_id,
    )
    desired.push(
      if has_neighbor_minor_center {
        neighbor_minor_center
      } else {
        default_minor
      },
    )
  }
  desired
}

///|
fn relax_rank_minor_coords(
  node_ids : Array[String],
  desired_coords : Array[Int],
  minor_step : Int,
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Array[Int] {
  let coords : Array[Int] = []
  for coord in desired_coords {
    coords.push(coord)
  }
  if coords.length() <= 1 {
    return coords
  }

  for i in 1..<coords.length() {
    let gap = rank_pair_minor_gap(
      node_ids[i - 1],
      node_ids[i],
      minor_step,
      horizontal,
      width_by_node_id,
      height_by_node_id,
    )
    let min_right = coords[i - 1] + gap
    if coords[i] < min_right {
      coords[i] = min_right
    }
  }

  let mut reverse_i = coords.length() - 1
  while reverse_i > 0 {
    let left_i = reverse_i - 1
    let gap = rank_pair_minor_gap(
      node_ids[left_i],
      node_ids[reverse_i],
      minor_step,
      horizontal,
      width_by_node_id,
      height_by_node_id,
    )
    let max_left = coords[reverse_i] - gap
    if coords[left_i] > max_left {
      coords[left_i] = max_left
    }
    reverse_i = left_i
  }

  let mut desired_sum = 0
  let mut resolved_sum = 0
  for coord in desired_coords {
    desired_sum += coord
  }
  for coord in coords {
    resolved_sum += coord
  }
  let mean_shift = (desired_sum - resolved_sum) / coords.length()
  if mean_shift != 0 {
    for i in 0..<coords.length() {
      coords[i] = coords[i] + mean_shift
    }
  }

  for i in 1..<coords.length() {
    let gap = rank_pair_minor_gap(
      node_ids[i - 1],
      node_ids[i],
      minor_step,
      horizontal,
      width_by_node_id,
      height_by_node_id,
    )
    let min_right = coords[i - 1] + gap
    if coords[i] < min_right {
      coords[i] = min_right
    }
  }

  let mut reverse_i = coords.length() - 1
  while reverse_i > 0 {
    let left_i = reverse_i - 1
    let gap = rank_pair_minor_gap(
      node_ids[left_i],
      node_ids[reverse_i],
      minor_step,
      horizontal,
      width_by_node_id,
      height_by_node_id,
    )
    let max_left = coords[reverse_i] - gap
    if coords[left_i] > max_left {
      coords[left_i] = max_left
    }
    reverse_i = left_i
  }

  coords
}

///|
fn align_rank_minor_coords(
  rank : Int,
  rank_node_ids_by_rank : Map[Int, Array[String]],
  neighbor_by_node_id : Map[String, Array[String]],
  minor_coord_by_node_id : Map[String, Int],
  padding : Int,
  minor_step : Int,
  max_rank_minor_span : Int,
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Unit {
  match rank_node_ids_by_rank.get(rank) {
    Some(node_ids) => {
      if node_ids.length() == 0 {
        return
      }
      let rank_minor_span = (node_ids.length() - 1).max(0) * minor_step
      let default_minor_start = padding +
        70 +
        (max_rank_minor_span - rank_minor_span) / 2
      let desired_minor_coords = resolve_rank_desired_minor_coords(
        node_ids, neighbor_by_node_id, minor_coord_by_node_id, default_minor_start,
        minor_step,
      )
      let resolved_minor_coords = relax_rank_minor_coords(
        node_ids, desired_minor_coords, minor_step, horizontal, width_by_node_id,
        height_by_node_id,
      )
      for i, node_id in node_ids {
        minor_coord_by_node_id[node_id] = resolved_minor_coords[i]
      }
    }
    None => ()
  }
}

///|
fn build_minor_coord_by_node_id(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  compact_small_graph : Bool,
  padding : Int,
  minor_step : Int,
  max_rank_minor_span : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Map[String, Int] {
  let minor_coord_by_node_id : Map[String, Int] = {}
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) => {
        let rank_minor_span = (node_ids.length() - 1).max(0) * minor_step
        let minor_start = padding +
          70 +
          (max_rank_minor_span - rank_minor_span) / 2
        for lane, node_id in node_ids {
          minor_coord_by_node_id[node_id] = minor_start + lane * minor_step
        }
      }
      None => ()
    }
  }

  let mut pass = 0
  while pass < 4 {
    for rank in 1..<=max_rank {
      align_rank_minor_coords(
        rank, rank_node_ids_by_rank, predecessors_by_node_id, minor_coord_by_node_id,
        padding, minor_step, max_rank_minor_span, horizontal, width_by_node_id, height_by_node_id,
      )
    }
    if max_rank > 0 {
      let mut rank = max_rank - 1
      while true {
        align_rank_minor_coords(
          rank, rank_node_ids_by_rank, successors_by_node_id, minor_coord_by_node_id,
          padding, minor_step, max_rank_minor_span, horizontal, width_by_node_id,
          height_by_node_id,
        )
        if rank == 0 {
          break
        }
        rank = rank - 1
      }
    }
    pass += 1
  }

  if compact_small_graph {
    let mut singleton_only = true
    let mut has_populated_rank = false
    let mut min_populated_rank = 0
    let mut max_populated_rank = 0
    for rank in 0..<=max_rank {
      match rank_node_ids_by_rank.get(rank) {
        Some(node_ids) => {
          if node_ids.length() == 0 {
            continue
          }
          if !has_populated_rank {
            has_populated_rank = true
            min_populated_rank = rank
            max_populated_rank = rank
          } else {
            min_populated_rank = min_populated_rank.min(rank)
            max_populated_rank = max_populated_rank.max(rank)
          }
          if node_ids.length() != 1 {
            singleton_only = false
            break
          }
        }
        None => ()
      }
    }
    if singleton_only &&
      has_populated_rank &&
      max_populated_rank > min_populated_rank {
      let rank_span = max_populated_rank - min_populated_rank
      let stair_amplitude = (minor_step / 8).max(4).min(8)
      for rank in min_populated_rank..<=max_populated_rank {
        match rank_node_ids_by_rank.get(rank) {
          Some(node_ids) =>
            if node_ids.length() == 1 {
              let node_id = node_ids[0]
              let stair_offset = (rank - min_populated_rank) *
                (stair_amplitude * 2) /
                rank_span -
                stair_amplitude
              minor_coord_by_node_id[node_id] = option_int_or(
                  minor_coord_by_node_id.get(node_id),
                  padding + 70,
                ) +
                stair_offset
            }
          None => ()
        }
      }
    }
  }

  let mut has_minor = false
  let mut min_minor = 0
  for _, minor_coord in minor_coord_by_node_id {
    if !has_minor {
      has_minor = true
      min_minor = minor_coord
    } else if minor_coord < min_minor {
      min_minor = minor_coord
    }
  }
  let floor_minor = padding + 70
  if has_minor && min_minor < floor_minor {
    let normalize_offset = floor_minor - min_minor
    let node_ids : Array[String] = []
    for node_id, _ in minor_coord_by_node_id {
      node_ids.push(node_id)
    }
    for node_id in node_ids {
      minor_coord_by_node_id[node_id] = option_int_or(
          minor_coord_by_node_id.get(node_id),
          floor_minor,
        ) +
        normalize_offset
    }
  }

  minor_coord_by_node_id
}

///|
fn build_minor_coord_by_lane_seed(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  lane_by_node_id : Map[String, Int],
  padding : Int,
  minor_step : Int,
) -> Map[String, Int] {
  let mut has_lane = false
  let mut min_lane = 0
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for node_id in node_ids {
          let lane = option_int_or(lane_by_node_id.get(node_id), 0)
          if !has_lane {
            has_lane = true
            min_lane = lane
          } else if lane < min_lane {
            min_lane = lane
          }
        }
      None => ()
    }
  }

  let minor_coord_by_node_id : Map[String, Int] = {}
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) => {
        let mut previous_minor = padding + 70 - minor_step
        for node_id in node_ids {
          let lane = option_int_or(lane_by_node_id.get(node_id), 0)
          let seeded_minor = padding + 70 + (lane - min_lane) * minor_step
          let resolved_minor = seeded_minor.max(previous_minor + minor_step)
          minor_coord_by_node_id[node_id] = resolved_minor
          previous_minor = resolved_minor
        }
      }
      None => ()
    }
  }
  minor_coord_by_node_id
}

///|
