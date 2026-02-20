///|
fn merge_style(
  target : Map[String, String],
  style : Map[String, String]?,
) -> Unit {
  match style {
    Some(found) =>
      for entry in found.to_array() {
        let (key, value) = entry
        target[key] = value
      }
    None => ()
  }
}

///|
fn resolve_inline_style(
  graph : MermaidGraph,
  node_id : String,
) -> Map[String, String]? {
  let resolved : Map[String, String] = {}
  let class_style = match graph.class_assignments.get(node_id) {
    Some(class_name) => graph.class_defs.get(class_name)
    None => None
  }
  merge_style(resolved, class_style)
  merge_style(resolved, graph.node_styles.get(node_id))
  if resolved.length() == 0 {
    None
  } else {
    Some(resolved)
  }
}

///|
fn rank_pair_key(left_rank : Int, right_rank : Int) -> String {
  if left_rank <= right_rank {
    "\{left_rank}->\{right_rank}"
  } else {
    "\{right_rank}->\{left_rank}"
  }
}

///|
fn edge_label_major_extent(label : String, horizontal : Bool) -> Int {
  let lines = label.split("\n").map(line => line.to_string()).to_array()
  let mut longest_line = 0
  for line in lines {
    longest_line = longest_line.max(line.length())
  }
  if horizontal {
    longest_line * 6 + 12
  } else {
    lines.length() * 13 + 8
  }
}

///|
fn build_rank_pair_label_major_gap(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  subgraph_entry_by_id : Map[String, String],
  subgraph_exit_by_id : Map[String, String],
  rank_by_node_id : Map[String, Int],
  horizontal : Bool,
) -> Map[String, Int] {
  let rank_pair_label_major_gap : Map[String, Int] = {}
  for edge in graph.edges {
    let source_id = resolve_edge_endpoint_id(
      edge.source,
      use_subgraph_redirects,
      subgraph_exit_by_id,
    )
    let target_id = resolve_edge_endpoint_id(
      edge.target,
      use_subgraph_redirects,
      subgraph_entry_by_id,
    )
    let source_rank = option_int_or(rank_by_node_id.get(source_id), -1)
    let target_rank = option_int_or(rank_by_node_id.get(target_id), -1)
    if source_rank < 0 || target_rank <= source_rank {
      continue
    }
    let label_major_gap = match edge.label {
      Some(label) => edge_label_major_extent(label, horizontal) + 8
      None => 0
    }
    if label_major_gap <= 0 {
      continue
    }
    for rank in source_rank..<target_rank {
      let key = rank_pair_key(rank, rank + 1)
      let current = option_int_or(rank_pair_label_major_gap.get(key), 0)
      if label_major_gap > current {
        rank_pair_label_major_gap[key] = label_major_gap
      }
    }
  }
  rank_pair_label_major_gap
}

///|
fn rank_pair_major_step(
  left_rank : Int,
  right_rank : Int,
  base_major_gap : Int,
  rank_pair_label_major_gap : Map[String, Int],
) -> Int {
  let label_clearance = option_int_or(
    rank_pair_label_major_gap.get(rank_pair_key(left_rank, right_rank)),
    0,
  )
  if label_clearance <= base_major_gap {
    base_major_gap
  } else {
    // Dampen label-driven expansion so long labels gain room without causing
    // large global stretching on small graphs.
    let overflow = label_clearance - base_major_gap
    base_major_gap + overflow * 2 / 3
  }
}

///|
fn build_rank_major_extent_by_rank(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
  horizontal : Bool,
) -> Map[Int, Int] {
  let rank_major_extent_by_rank : Map[Int, Int] = {}
  for rank in 0..<=max_rank {
    let mut extent = 70
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for node_id in node_ids {
          let node_extent = if horizontal {
            option_int_or(width_by_node_id.get(node_id), 70)
          } else {
            option_int_or(height_by_node_id.get(node_id), 44)
          }
          if node_extent > extent {
            extent = node_extent
          }
        }
      None => ()
    }
    rank_major_extent_by_rank[rank] = extent
  }
  rank_major_extent_by_rank
}

///|
fn build_major_center_by_rank(
  max_rank : Int,
  rank_major_extent_by_rank : Map[Int, Int],
  reverse : Bool,
  padding : Int,
  base_major_gap : Int,
  rank_pair_label_major_gap : Map[String, Int],
) -> Map[Int, Int] {
  let major_center_by_rank : Map[Int, Int] = {}
  let first_rank = if reverse { max_rank } else { 0 }
  let first_rank_extent = option_int_or(
    rank_major_extent_by_rank.get(first_rank),
    70,
  )
  let major_start = padding + first_rank_extent / 2 + 20
  let mut displayed_major_center = major_start
  for displayed_rank in 0..<=max_rank {
    let rank = if reverse { max_rank - displayed_rank } else { displayed_rank }
    if displayed_rank > 0 {
      let previous_displayed_rank = displayed_rank - 1
      let previous_rank = if reverse {
        max_rank - previous_displayed_rank
      } else {
        previous_displayed_rank
      }
      let previous_rank_extent = option_int_or(
        rank_major_extent_by_rank.get(previous_rank),
        70,
      )
      let rank_extent = option_int_or(rank_major_extent_by_rank.get(rank), 70)
      let gap = rank_pair_major_step(
        previous_rank, rank, base_major_gap, rank_pair_label_major_gap,
      )
      displayed_major_center += previous_rank_extent / 2 + rank_extent / 2 + gap
    }
    major_center_by_rank[rank] = displayed_major_center
  }
  major_center_by_rank
}

///|
fn major_node_extent(
  node_id : String,
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Int {
  if horizontal {
    option_int_or(width_by_node_id.get(node_id), 70)
  } else {
    option_int_or(height_by_node_id.get(node_id), 44)
  }
}

///|
fn major_direction_sign(
  source_id : String,
  target_id : String,
  baseline_major_coord_by_node_id : Map[String, Int],
) -> Int {
  let source_major = option_int_or(
    baseline_major_coord_by_node_id.get(source_id),
    0,
  )
  let target_major = option_int_or(
    baseline_major_coord_by_node_id.get(target_id),
    source_major + 1,
  )
  if target_major >= source_major {
    1
  } else {
    -1
  }
}

///|
fn major_edge_min_step(
  source_id : String,
  target_id : String,
  rank_by_node_id : Map[String, Int],
  baseline_major_coord_by_node_id : Map[String, Int],
  base_major_gap : Int,
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Int {
  let source_rank = option_int_or(rank_by_node_id.get(source_id), 0)
  let target_rank = option_int_or(
    rank_by_node_id.get(target_id),
    source_rank + 1,
  )
  let raw_rank_delta = if target_rank >= source_rank {
    target_rank - source_rank
  } else {
    source_rank - target_rank
  }
  let rank_delta = raw_rank_delta.max(1)
  let source_major = option_int_or(
    baseline_major_coord_by_node_id.get(source_id),
    0,
  )
  let target_major = option_int_or(
    baseline_major_coord_by_node_id.get(target_id),
    source_major,
  )
  let baseline_delta = if target_major >= source_major {
    target_major - source_major
  } else {
    source_major - target_major
  }
  let baseline_step = baseline_delta / rank_delta
  let source_extent = major_node_extent(
    source_id, horizontal, width_by_node_id, height_by_node_id,
  )
  let target_extent = major_node_extent(
    target_id, horizontal, width_by_node_id, height_by_node_id,
  )
  let size_step = source_extent / 2 + target_extent / 2 + base_major_gap
  size_step.max(baseline_step.max(8))
}

///|
fn sorted_neighbor_ids_by_minor(
  neighbor_ids : Array[String],
  minor_coord_by_node_id : Map[String, Int],
  baseline_major_coord_by_node_id : Map[String, Int],
) -> Array[String] {
  let sorted = neighbor_ids.copy()
  sorted.sort_by((left, right) => {
    let left_minor = option_int_or(minor_coord_by_node_id.get(left), 0)
    let right_minor = option_int_or(minor_coord_by_node_id.get(right), 0)
    if left_minor != right_minor {
      left_minor - right_minor
    } else {
      let left_major = option_int_or(
        baseline_major_coord_by_node_id.get(left),
        0,
      )
      let right_major = option_int_or(
        baseline_major_coord_by_node_id.get(right),
        0,
      )
      if left_major != right_major {
        left_major - right_major
      } else {
        left.compare(right)
      }
    }
  })
  sorted
}

///|
fn build_baseline_major_coord_by_node_id(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  major_center_by_rank : Map[Int, Int],
) -> Map[String, Int] {
  let baseline_major_coord_by_node_id : Map[String, Int] = {}
  for rank in 0..<=max_rank {
    let major_center = option_int_or(major_center_by_rank.get(rank), 0)
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for node_id in node_ids {
          baseline_major_coord_by_node_id[node_id] = major_center
        }
      None => ()
    }
  }
  baseline_major_coord_by_node_id
}

///|
fn enforce_major_edge_constraints(
  major_coord_by_node_id : Map[String, Int],
  baseline_major_coord_by_node_id : Map[String, Int],
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
  base_major_gap : Int,
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Unit {
  let mut pass = 0
  while pass < 4 {
    for source_id, target_ids in successors_by_node_id {
      let source_major = option_int_or(
        major_coord_by_node_id.get(source_id),
        option_int_or(baseline_major_coord_by_node_id.get(source_id), 0),
      )
      for target_id in target_ids {
        let sign = major_direction_sign(
          source_id, target_id, baseline_major_coord_by_node_id,
        )
        let edge_step = major_edge_min_step(
          source_id, target_id, rank_by_node_id, baseline_major_coord_by_node_id,
          base_major_gap, horizontal, width_by_node_id, height_by_node_id,
        )
        let target_major = option_int_or(
          major_coord_by_node_id.get(target_id),
          option_int_or(
            baseline_major_coord_by_node_id.get(target_id),
            source_major,
          ),
        )
        if sign > 0 {
          let min_target = source_major + edge_step
          if target_major < min_target {
            major_coord_by_node_id[target_id] = min_target
          }
        } else {
          let max_target = source_major - edge_step
          if target_major > max_target {
            major_coord_by_node_id[target_id] = max_target
          }
        }
      }
    }
    pass += 1
  }
}

///|
priv struct MajorRelaxCandidate {
  name : String
  major_coord_by_node_id : Map[String, Int]
  violation_score : Int
  span : Int
  baseline_delta_sum : Int
  objective : Int
}

///|
fn clone_major_coord_by_node_id(
  major_coord_by_node_id : Map[String, Int],
) -> Map[String, Int] {
  let cloned : Map[String, Int] = {}
  for node_id, major_coord in major_coord_by_node_id {
    cloned[node_id] = major_coord
  }
  cloned
}

///|
fn sorted_node_ids_from_coord_map(
  major_coord_by_node_id : Map[String, Int],
) -> Array[String] {
  let node_ids : Array[String] = []
  for node_id, _ in major_coord_by_node_id {
    node_ids.push(node_id)
  }
  node_ids.sort()
  node_ids
}

///|
fn major_coord_span(
  node_ids : Array[String],
  major_coord_by_node_id : Map[String, Int],
) -> Int {
  let mut has_major = false
  let mut min_major = 0
  let mut max_major = 0
  for node_id in node_ids {
    let major_coord = option_int_or(major_coord_by_node_id.get(node_id), 0)
    if !has_major {
      has_major = true
      min_major = major_coord
      max_major = major_coord
    } else {
      if major_coord < min_major {
        min_major = major_coord
      }
      if major_coord > max_major {
        max_major = major_coord
      }
    }
  }
  if has_major {
    max_major - min_major
  } else {
    0
  }
}

///|
fn major_baseline_delta_sum(
  node_ids : Array[String],
  major_coord_by_node_id : Map[String, Int],
  baseline_major_coord_by_node_id : Map[String, Int],
) -> Int {
  let mut delta_sum = 0
  for node_id in node_ids {
    let baseline_major = option_int_or(
      baseline_major_coord_by_node_id.get(node_id),
      0,
    )
    let major_coord = option_int_or(
      major_coord_by_node_id.get(node_id),
      baseline_major,
    )
    delta_sum += if major_coord >= baseline_major {
      major_coord - baseline_major
    } else {
      baseline_major - major_coord
    }
  }
  delta_sum
}

///|
fn major_constraint_violation_score(
  major_coord_by_node_id : Map[String, Int],
  baseline_major_coord_by_node_id : Map[String, Int],
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
  base_major_gap : Int,
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Int {
  let mut violation_score = 0
  for source_id, target_ids in successors_by_node_id {
    let source_major = option_int_or(
      major_coord_by_node_id.get(source_id),
      option_int_or(baseline_major_coord_by_node_id.get(source_id), 0),
    )
    for target_id in target_ids {
      let sign = major_direction_sign(
        source_id, target_id, baseline_major_coord_by_node_id,
      )
      let edge_step = major_edge_min_step(
        source_id, target_id, rank_by_node_id, baseline_major_coord_by_node_id, base_major_gap,
        horizontal, width_by_node_id, height_by_node_id,
      )
      let target_major = option_int_or(
        major_coord_by_node_id.get(target_id),
        option_int_or(
          baseline_major_coord_by_node_id.get(target_id),
          source_major,
        ),
      )
      let signed_delta = (target_major - source_major) * sign
      if signed_delta < edge_step {
        violation_score += edge_step - signed_delta
      }
    }
  }
  violation_score
}

///|
fn build_major_relax_candidate(
  name : String,
  major_coord_by_node_id : Map[String, Int],
  node_ids : Array[String],
  baseline_major_coord_by_node_id : Map[String, Int],
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
  base_major_gap : Int,
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> MajorRelaxCandidate {
  let violation_score = major_constraint_violation_score(
    major_coord_by_node_id, baseline_major_coord_by_node_id, rank_by_node_id, successors_by_node_id,
    base_major_gap, horizontal, width_by_node_id, height_by_node_id,
  )
  let span = major_coord_span(node_ids, major_coord_by_node_id)
  let baseline_delta_sum = major_baseline_delta_sum(
    node_ids, major_coord_by_node_id, baseline_major_coord_by_node_id,
  )
  // Prioritize edge-constraint correctness before compaction and drift.
  let objective = violation_score * 10000 + span * 10 + baseline_delta_sum
  {
    name,
    major_coord_by_node_id,
    violation_score,
    span,
    baseline_delta_sum,
    objective,
  }
}

///|
fn better_major_relax_candidate(
  left : MajorRelaxCandidate,
  right : MajorRelaxCandidate,
) -> MajorRelaxCandidate {
  if left.objective < right.objective {
    left
  } else if left.objective > right.objective {
    right
  } else if left.violation_score < right.violation_score {
    left
  } else if left.violation_score > right.violation_score {
    right
  } else if left.span < right.span {
    left
  } else if left.span > right.span {
    right
  } else if left.baseline_delta_sum < right.baseline_delta_sum {
    left
  } else if left.baseline_delta_sum > right.baseline_delta_sum {
    right
  } else if left.name.compare(right.name) <= 0 {
    left
  } else {
    right
  }
}

///|
fn relax_major_forward_sweep(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  reverse : Bool,
  major_coord_by_node_id : Map[String, Int],
  rank_by_node_id : Map[String, Int],
  predecessors_by_node_id : Map[String, Array[String]],
  baseline_major_coord_by_node_id : Map[String, Int],
  minor_coord_by_node_id : Map[String, Int],
  base_major_gap : Int,
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Unit {
  for displayed_rank in 0..<=max_rank {
    let rank = if reverse { max_rank - displayed_rank } else { displayed_rank }
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids_in_rank) =>
        for node_id in node_ids_in_rank {
          let baseline_major = option_int_or(
            baseline_major_coord_by_node_id.get(node_id),
            0,
          )
          let mut has_candidate = false
          let mut candidate_major = baseline_major
          match predecessors_by_node_id.get(node_id) {
            Some(predecessor_ids) => {
              let sorted_predecessors = sorted_neighbor_ids_by_minor(
                predecessor_ids, minor_coord_by_node_id, baseline_major_coord_by_node_id,
              )
              if sorted_predecessors.length() > 0 {
                let predecessor_id = sorted_predecessors[sorted_predecessors.length() /
                  2]
                let predecessor_major = option_int_or(
                  major_coord_by_node_id.get(predecessor_id),
                  option_int_or(
                    baseline_major_coord_by_node_id.get(predecessor_id),
                    baseline_major,
                  ),
                )
                let sign = major_direction_sign(
                  predecessor_id, node_id, baseline_major_coord_by_node_id,
                )
                let edge_step = major_edge_min_step(
                  predecessor_id, node_id, rank_by_node_id, baseline_major_coord_by_node_id,
                  base_major_gap, horizontal, width_by_node_id, height_by_node_id,
                )
                candidate_major = predecessor_major + sign * edge_step
                has_candidate = true
              }
            }
            None => ()
          }
          if has_candidate {
            let current_major = option_int_or(
              major_coord_by_node_id.get(node_id),
              baseline_major,
            )
            major_coord_by_node_id[node_id] = (
                baseline_major * 2 + current_major + candidate_major * 2
              ) /
              5
          }
        }
      None => ()
    }
  }
}

///|
fn relax_major_backward_sweep(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  reverse : Bool,
  major_coord_by_node_id : Map[String, Int],
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
  baseline_major_coord_by_node_id : Map[String, Int],
  minor_coord_by_node_id : Map[String, Int],
  base_major_gap : Int,
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Unit {
  for displayed_rank in 0..<=max_rank {
    let rank = if reverse { displayed_rank } else { max_rank - displayed_rank }
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids_in_rank) =>
        for node_id in node_ids_in_rank {
          let baseline_major = option_int_or(
            baseline_major_coord_by_node_id.get(node_id),
            0,
          )
          let mut has_candidate = false
          let mut candidate_major = baseline_major
          match successors_by_node_id.get(node_id) {
            Some(successor_ids) => {
              let sorted_successors = sorted_neighbor_ids_by_minor(
                successor_ids, minor_coord_by_node_id, baseline_major_coord_by_node_id,
              )
              if sorted_successors.length() > 0 {
                let successor_id = sorted_successors[sorted_successors.length() /
                  2]
                let successor_major = option_int_or(
                  major_coord_by_node_id.get(successor_id),
                  option_int_or(
                    baseline_major_coord_by_node_id.get(successor_id),
                    baseline_major,
                  ),
                )
                let sign = major_direction_sign(
                  node_id, successor_id, baseline_major_coord_by_node_id,
                )
                let edge_step = major_edge_min_step(
                  node_id, successor_id, rank_by_node_id, baseline_major_coord_by_node_id,
                  base_major_gap, horizontal, width_by_node_id, height_by_node_id,
                )
                candidate_major = successor_major - sign * edge_step
                has_candidate = true
              }
            }
            None => ()
          }
          if has_candidate {
            let current_major = option_int_or(
              major_coord_by_node_id.get(node_id),
              baseline_major,
            )
            major_coord_by_node_id[node_id] = (
                baseline_major * 2 + current_major + candidate_major * 2
              ) /
              5
          }
        }
      None => ()
    }
  }
}

///|
fn finalize_major_coord_by_node_id(
  major_coord_by_node_id : Map[String, Int],
  baseline_major_coord_by_node_id : Map[String, Int],
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
  base_major_gap : Int,
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Map[String, Int] {
  let node_ids = sorted_node_ids_from_coord_map(baseline_major_coord_by_node_id)
  if node_ids.length() == 0 {
    return major_coord_by_node_id
  }

  let mut min_baseline_major = option_int_or(
    baseline_major_coord_by_node_id.get(node_ids[0]),
    0,
  )
  for node_id in node_ids {
    let baseline_major = option_int_or(
      baseline_major_coord_by_node_id.get(node_id),
      min_baseline_major,
    )
    if baseline_major < min_baseline_major {
      min_baseline_major = baseline_major
    }
  }

  let major_clamp_span = (base_major_gap * 2).max(90)
  let mut min_major = min_baseline_major
  let mut has_major = false
  for node_id in node_ids {
    let baseline_major = option_int_or(
      baseline_major_coord_by_node_id.get(node_id),
      min_baseline_major,
    )
    let major = option_int_or(
      major_coord_by_node_id.get(node_id),
      baseline_major,
    )
    let clamped_major = if major < baseline_major - major_clamp_span {
      baseline_major - major_clamp_span
    } else if major > baseline_major + major_clamp_span {
      baseline_major + major_clamp_span
    } else {
      major
    }
    major_coord_by_node_id[node_id] = clamped_major
    if !has_major {
      has_major = true
      min_major = clamped_major
    } else if clamped_major < min_major {
      min_major = clamped_major
    }
  }

  if has_major && min_major < min_baseline_major {
    let normalize_offset = min_baseline_major - min_major
    for node_id in node_ids {
      major_coord_by_node_id[node_id] = option_int_or(
          major_coord_by_node_id.get(node_id),
          min_baseline_major,
        ) +
        normalize_offset
    }
  }

  enforce_major_edge_constraints(
    major_coord_by_node_id, baseline_major_coord_by_node_id, rank_by_node_id, successors_by_node_id,
    base_major_gap, horizontal, width_by_node_id, height_by_node_id,
  )
  major_coord_by_node_id
}

///|
fn relax_major_coord_with_sweep_order(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  reverse : Bool,
  rank_by_node_id : Map[String, Int],
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  baseline_major_coord_by_node_id : Map[String, Int],
  minor_coord_by_node_id : Map[String, Int],
  base_major_gap : Int,
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
  forward_first : Bool,
) -> Map[String, Int] {
  let major_coord_by_node_id = clone_major_coord_by_node_id(
    baseline_major_coord_by_node_id,
  )
  let mut pass = 0
  while pass < 6 {
    if forward_first {
      relax_major_forward_sweep(
        rank_node_ids_by_rank, max_rank, reverse, major_coord_by_node_id, rank_by_node_id,
        predecessors_by_node_id, baseline_major_coord_by_node_id, minor_coord_by_node_id,
        base_major_gap, horizontal, width_by_node_id, height_by_node_id,
      )
      enforce_major_edge_constraints(
        major_coord_by_node_id, baseline_major_coord_by_node_id, rank_by_node_id,
        successors_by_node_id, base_major_gap, horizontal, width_by_node_id, height_by_node_id,
      )
      relax_major_backward_sweep(
        rank_node_ids_by_rank, max_rank, reverse, major_coord_by_node_id, rank_by_node_id,
        successors_by_node_id, baseline_major_coord_by_node_id, minor_coord_by_node_id,
        base_major_gap, horizontal, width_by_node_id, height_by_node_id,
      )
      enforce_major_edge_constraints(
        major_coord_by_node_id, baseline_major_coord_by_node_id, rank_by_node_id,
        successors_by_node_id, base_major_gap, horizontal, width_by_node_id, height_by_node_id,
      )
    } else {
      relax_major_backward_sweep(
        rank_node_ids_by_rank, max_rank, reverse, major_coord_by_node_id, rank_by_node_id,
        successors_by_node_id, baseline_major_coord_by_node_id, minor_coord_by_node_id,
        base_major_gap, horizontal, width_by_node_id, height_by_node_id,
      )
      enforce_major_edge_constraints(
        major_coord_by_node_id, baseline_major_coord_by_node_id, rank_by_node_id,
        successors_by_node_id, base_major_gap, horizontal, width_by_node_id, height_by_node_id,
      )
      relax_major_forward_sweep(
        rank_node_ids_by_rank, max_rank, reverse, major_coord_by_node_id, rank_by_node_id,
        predecessors_by_node_id, baseline_major_coord_by_node_id, minor_coord_by_node_id,
        base_major_gap, horizontal, width_by_node_id, height_by_node_id,
      )
      enforce_major_edge_constraints(
        major_coord_by_node_id, baseline_major_coord_by_node_id, rank_by_node_id,
        successors_by_node_id, base_major_gap, horizontal, width_by_node_id, height_by_node_id,
      )
    }
    pass += 1
  }
  finalize_major_coord_by_node_id(
    major_coord_by_node_id, baseline_major_coord_by_node_id, rank_by_node_id, successors_by_node_id,
    base_major_gap, horizontal, width_by_node_id, height_by_node_id,
  )
}

///|
fn average_major_coord_by_node_id(
  node_ids : Array[String],
  left_major_coord_by_node_id : Map[String, Int],
  right_major_coord_by_node_id : Map[String, Int],
  baseline_major_coord_by_node_id : Map[String, Int],
) -> Map[String, Int] {
  let averaged : Map[String, Int] = {}
  for node_id in node_ids {
    let baseline_major = option_int_or(
      baseline_major_coord_by_node_id.get(node_id),
      0,
    )
    let left_major = option_int_or(
      left_major_coord_by_node_id.get(node_id),
      baseline_major,
    )
    let right_major = option_int_or(
      right_major_coord_by_node_id.get(node_id),
      baseline_major,
    )
    averaged[node_id] = (left_major + right_major) / 2
  }
  averaged
}

///|
fn relax_major_coord_by_node_id(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  reverse : Bool,
  rank_by_node_id : Map[String, Int],
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  baseline_major_coord_by_node_id : Map[String, Int],
  minor_coord_by_node_id : Map[String, Int],
  base_major_gap : Int,
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Map[String, Int] {
  let node_ids = sorted_node_ids_from_coord_map(baseline_major_coord_by_node_id)
  if node_ids.length() == 0 {
    return baseline_major_coord_by_node_id
  }

  let forward_major_coord_by_node_id = relax_major_coord_with_sweep_order(
    rank_node_ids_by_rank, max_rank, reverse, rank_by_node_id, predecessors_by_node_id,
    successors_by_node_id, baseline_major_coord_by_node_id, minor_coord_by_node_id,
    base_major_gap, horizontal, width_by_node_id, height_by_node_id, true,
  )
  let backward_major_coord_by_node_id = relax_major_coord_with_sweep_order(
    rank_node_ids_by_rank, max_rank, reverse, rank_by_node_id, predecessors_by_node_id,
    successors_by_node_id, baseline_major_coord_by_node_id, minor_coord_by_node_id,
    base_major_gap, horizontal, width_by_node_id, height_by_node_id, false,
  )
  let balanced_major_seed = average_major_coord_by_node_id(
    node_ids, forward_major_coord_by_node_id, backward_major_coord_by_node_id, baseline_major_coord_by_node_id,
  )
  let balanced_major_coord_by_node_id = finalize_major_coord_by_node_id(
    balanced_major_seed, baseline_major_coord_by_node_id, rank_by_node_id, successors_by_node_id,
    base_major_gap, horizontal, width_by_node_id, height_by_node_id,
  )

  let forward_candidate = build_major_relax_candidate(
    "forward-first", forward_major_coord_by_node_id, node_ids, baseline_major_coord_by_node_id,
    rank_by_node_id, successors_by_node_id, base_major_gap, horizontal, width_by_node_id,
    height_by_node_id,
  )
  let backward_candidate = build_major_relax_candidate(
    "backward-first", backward_major_coord_by_node_id, node_ids, baseline_major_coord_by_node_id,
    rank_by_node_id, successors_by_node_id, base_major_gap, horizontal, width_by_node_id,
    height_by_node_id,
  )
  let balanced_candidate = build_major_relax_candidate(
    "balanced", balanced_major_coord_by_node_id, node_ids, baseline_major_coord_by_node_id,
    rank_by_node_id, successors_by_node_id, base_major_gap, horizontal, width_by_node_id,
    height_by_node_id,
  )
  // Keep forward-first as the stable baseline; only swap if baseline violates
  // edge constraints and an alternate candidate clearly improves feasibility.
  let alternate_candidate = better_major_relax_candidate(
    backward_candidate, balanced_candidate,
  )
  let selected_candidate = if forward_candidate.violation_score > 0 &&
    alternate_candidate.violation_score < forward_candidate.violation_score {
    alternate_candidate
  } else {
    forward_candidate
  }
  selected_candidate.major_coord_by_node_id
}

///|
fn build_major_coord_by_strategy(
  strategy : ElkLayeredMajorPlacementStrategy,
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  reverse : Bool,
  rank_by_node_id : Map[String, Int],
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  major_center_by_rank : Map[Int, Int],
  minor_coord_by_node_id : Map[String, Int],
  base_major_gap : Int,
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Map[String, Int] {
  let baseline_major_coord_by_node_id = build_baseline_major_coord_by_node_id(
    rank_node_ids_by_rank, max_rank, major_center_by_rank,
  )
  let use_relaxed_compaction = use_relaxed_major_compaction(
    max_rank, rank_by_node_id, successors_by_node_id,
  )
  match strategy {
    RankCentered => baseline_major_coord_by_node_id
    RelaxedCompaction =>
      if use_relaxed_compaction {
        relax_major_coord_by_node_id(
          rank_node_ids_by_rank, max_rank, reverse, rank_by_node_id, predecessors_by_node_id,
          successors_by_node_id, baseline_major_coord_by_node_id, minor_coord_by_node_id,
          base_major_gap, horizontal, width_by_node_id, height_by_node_id,
        )
      } else {
        baseline_major_coord_by_node_id
      }
  }
}

///|
fn use_relaxed_major_compaction(
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Bool {
  let mut edge_count = 0
  let mut long_span_edge_count = 0
  for source_id, target_ids in successors_by_node_id {
    let source_rank = option_int_or(rank_by_node_id.get(source_id), 0)
    for target_id in target_ids {
      edge_count += 1
      let target_rank = option_int_or(
        rank_by_node_id.get(target_id),
        source_rank + 1,
      )
      let rank_delta = if target_rank >= source_rank {
        target_rank - source_rank
      } else {
        source_rank - target_rank
      }
      if rank_delta > 1 {
        long_span_edge_count += 1
      }
    }
  }
  edge_count >= 12 &&
  max_rank >= 5 &&
  long_span_edge_count > 0 &&
  long_span_edge_count * 100 >= edge_count * 30
}

///|
fn build_axis_coords_by_node_id(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  major_coord_by_node_id : Map[String, Int],
  minor_coord_by_node_id : Map[String, Int],
  padding : Int,
  horizontal : Bool,
) -> (Map[String, Int], Map[String, Int]) {
  let x_by_node_id : Map[String, Int] = {}
  let y_by_node_id : Map[String, Int] = {}
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for node_id in node_ids {
          let major_coord = option_int_or(
            major_coord_by_node_id.get(node_id),
            padding + 70,
          )
          let minor_coord = option_int_or(
            minor_coord_by_node_id.get(node_id),
            padding + 70,
          )
          if horizontal {
            x_by_node_id[node_id] = major_coord
            y_by_node_id[node_id] = minor_coord
          } else {
            x_by_node_id[node_id] = minor_coord
            y_by_node_id[node_id] = major_coord
          }
        }
      None => ()
    }
  }
  (x_by_node_id, y_by_node_id)
}

///|
fn build_positioned_nodes_from_axis_coords(
  graph : MermaidGraph,
  nodes_in_order : Array[MermaidNode],
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
  x_by_node_id : Map[String, Int],
  y_by_node_id : Map[String, Int],
  padding : Int,
) -> (Array[PositionedNode], Map[String, PositionedNode]) {
  let positioned_nodes : Array[PositionedNode] = []
  let positioned_by_id : Map[String, PositionedNode] = {}
  for node in nodes_in_order {
    let width = option_int_or(width_by_node_id.get(node.id), 70)
    let height = option_int_or(height_by_node_id.get(node.id), 44)
    let positioned = PositionedNode::{
      id: node.id,
      label: node.label,
      shape: node.shape,
      x: option_int_or(x_by_node_id.get(node.id), padding + 70),
      y: option_int_or(y_by_node_id.get(node.id), padding + 70),
      width,
      height,
      inline_style: resolve_inline_style(graph, node.id),
    }
    positioned_nodes.push(positioned)
    positioned_by_id[node.id] = positioned
  }
  (positioned_nodes, positioned_by_id)
}

///|
fn build_node_horizontal_by_id(
  positioned_nodes : Array[PositionedNode],
  horizontal : Bool,
) -> Map[String, Bool] {
  let node_horizontal_by_id : Map[String, Bool] = {}
  for node in positioned_nodes {
    node_horizontal_by_id[node.id] = horizontal
  }
  node_horizontal_by_id
}

///|
fn positioned_nodes_layout_extent(
  positioned_nodes : Array[PositionedNode],
  padding : Int,
) -> (Int, Int) {
  let mut max_right = padding
  let mut max_bottom = padding
  for node in positioned_nodes {
    max_right = max_right.max(node.x + node.width / 2)
    max_bottom = max_bottom.max(node.y + node.height / 2)
  }
  (max_right, max_bottom)
}

///|
fn finalize_elk_layered_positioned_graph(
  graph : MermaidGraph,
  padding : Int,
  horizontal : Bool,
  reverse : Bool,
  node_spacing : Int,
  layer_spacing : Int,
  use_subgraph_redirects : Bool,
  subgraph_exit_by_id : Map[String, String],
  subgraph_entry_by_id : Map[String, String],
  routing_policy : GraphBackendRoutingPolicy,
  positioned_nodes : Array[PositionedNode],
  positioned_by_id : Map[String, PositionedNode],
  node_horizontal_by_id : Map[String, Bool],
  max_right : Int,
  max_bottom : Int,
) -> PositionedGraph {
  let positioned_index_by_id = positioned_index_by_node_id(positioned_nodes)
  // Keep ELK layered major-axis placement stable through finalize.
  // Flow-subgraph gap shifting is a legacy dagre compaction step that can
  // rewrite node major coordinates after rank placement.
  let positioned_groups = @layout_engine_graph_group_core.build_legacy_positioned_groups(
    graph, padding, horizontal, reverse, false, true, node_spacing, layer_spacing,
    positioned_nodes, positioned_by_id, positioned_index_by_id,
  )
  let positioned_edges = @layout_engine_graph_routing_core.route_legacy_positioned_edges(
    graph,
    false,
    false,
    horizontal,
    layer_spacing,
    node_spacing,
    use_subgraph_redirects,
    subgraph_exit_by_id,
    subgraph_entry_by_id,
    positioned_nodes,
    positioned_by_id,
    node_horizontal_by_id,
    routing_policy.enable_target_boundary_ports,
    routing_policy.preserve_assigned_endpoint_ports,
    false,
  )
  @layout_engine_graph_finalize_core.finalize_positioned_graph(
    padding, max_right, max_bottom, positioned_nodes, positioned_edges, positioned_groups,
  )
}

///|
fn elk_graph_supports_layered_pipeline(graph : MermaidGraph) -> Bool {
  graph.diagram_kind is Flowchart &&
  !@layout_engine_graph_internal_core.is_state_graph(graph) &&
  !@layout_engine_graph_internal_core.is_class_or_er_graph(graph)
}
