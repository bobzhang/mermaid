///|
fn option_int_or(value : Int?, fallback : Int) -> Int {
  match value {
    Some(found) => found
    None => fallback
  }
}

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
fn node_dimensions(node : MermaidNode) -> (Int, Int) {
  let label_lines = node.label
    .split("\n")
    .map(part => part.to_string())
    .to_array()
  let mut longest_line = 0
  for line in label_lines {
    longest_line = longest_line.max(line.length())
  }

  match node.shape {
    StateStart => (14, 14)
    StateEnd => (14, 14)
    Circle => {
      let diameter = (longest_line * 8 + 14).max(24)
      (diameter, diameter)
    }
    DoubleCircle => {
      let diameter = (longest_line * 8 + 22).max(34)
      (diameter, diameter)
    }
    ClassEntity => {
      let min_width = 120
      let width = min_width.max(longest_line * 8 + 30)
      let detail_rows = (label_lines.length() - 1).max(1)
      let height = 36 + detail_rows * 16 + 10
      (width, height)
    }
    ErEntity => {
      let min_width = 120
      let width = min_width.max(longest_line * 8 + 30)
      let detail_rows = (label_lines.length() - 1).max(1)
      let height = 34 + detail_rows * 16 + 10
      (width, height)
    }
    _ => {
      let min_width = 70
      let width = min_width.max(longest_line * 8 + 24)
      let height = (24 + label_lines.length() * 14).max(44)
      (width, height)
    }
  }
}

///|
fn resolve_edge_endpoint_id(
  node_id : String,
  use_subgraph_redirects : Bool,
  redirects : Map[String, String],
) -> String {
  if use_subgraph_redirects {
    match redirects.get(node_id) {
      Some(found) => found
      None => node_id
    }
  } else {
    node_id
  }
}

///|
fn edge_label_dimensions(label : String) -> (Int, Int) {
  let lines = label.split("\n").map(part => part.to_string()).to_array()
  let mut longest_line = 0
  for line in lines {
    longest_line = longest_line.max(line.length())
  }
  let width = (longest_line * 7 + 12).max(18)
  let height = (lines.length() * 14 + 12).max(18)
  (width, height)
}

///|
priv struct HorizontalLabelRankConstraint {
  source_rank_index : Int
  target_rank_index : Int
  min_extra : Int
}

///|
fn collect_horizontal_label_rank_constraints(
  edges : Array[MermaidEdge],
  flow_rank_by_node_id : Map[String, Int],
  flow_max_rank : Int,
  reverse : Bool,
  node_width_by_id : Map[String, Int],
  node_spacing : Int,
  use_subgraph_redirects : Bool,
  subgraph_exit_by_id : Map[String, String],
  subgraph_entry_by_id : Map[String, String],
) -> Array[HorizontalLabelRankConstraint] {
  let constraints : Array[HorizontalLabelRankConstraint] = []
  let label_clearance = (node_spacing / 6).max(12)
  for edge in edges {
    let label_text = match edge.label {
      Some(text) => text
      None => continue
    }
    let resolved_source_id = resolve_edge_endpoint_id(
      edge.source,
      use_subgraph_redirects,
      subgraph_exit_by_id,
    )
    let resolved_target_id = resolve_edge_endpoint_id(
      edge.target,
      use_subgraph_redirects,
      subgraph_entry_by_id,
    )
    match
      (
        flow_rank_by_node_id.get(resolved_source_id),
        flow_rank_by_node_id.get(resolved_target_id),
        node_width_by_id.get(resolved_source_id),
        node_width_by_id.get(resolved_target_id),
      ) {
      (
        Some(source_rank),
        Some(target_rank),
        Some(source_width),
        Some(target_width),
      ) => {
        let source_rank_index = if reverse {
          flow_max_rank - source_rank
        } else {
          source_rank
        }
        let target_rank_index = if reverse {
          flow_max_rank - target_rank
        } else {
          target_rank
        }
        if target_rank_index <= source_rank_index {
          continue
        }
        let (label_width, _) = edge_label_dimensions(label_text)
        let required_center_delta = source_width / 2 +
          target_width / 2 +
          label_width +
          label_clearance
        let rank_delta = target_rank_index - source_rank_index
        let base_center_delta = rank_delta * node_spacing +
          (target_width - source_width) / 2
        let required_extra = required_center_delta - base_center_delta
        if required_extra > 0 {
          constraints.push({
            source_rank_index,
            target_rank_index,
            min_extra: required_extra,
          })
        }
      }
      _ => ()
    }
  }
  constraints
}

///|
fn solve_horizontal_label_rank_shifts(
  max_rank : Int,
  constraints : Array[HorizontalLabelRankConstraint],
) -> Map[Int, Int] {
  let min_shift_by_rank_index : Map[Int, Int] = {}
  for rank_index in 0..<=max_rank {
    min_shift_by_rank_index[rank_index] = 0
  }
  if constraints.length() == 0 {
    return min_shift_by_rank_index
  }

  let max_passes = (max_rank + 1).max(1)
  for _ in 0..<max_passes {
    let mut changed = false
    for constraint in constraints {
      let source_shift = option_int_or(
        min_shift_by_rank_index.get(constraint.source_rank_index),
        0,
      )
      let current_target_shift = option_int_or(
        min_shift_by_rank_index.get(constraint.target_rank_index),
        0,
      )
      let candidate_target_shift = source_shift + constraint.min_extra
      if candidate_target_shift > current_target_shift {
        min_shift_by_rank_index[constraint.target_rank_index] = candidate_target_shift
        changed = true
      }
    }
    if !changed {
      break
    }
  }

  min_shift_by_rank_index
}

///|
fn horizontal_label_boundary_extra_by_rank_index(
  max_rank : Int,
  min_shift_by_rank_index : Map[Int, Int],
) -> Map[Int, Int] {
  let extra_by_rank_index : Map[Int, Int] = {}
  if max_rank <= 0 {
    return extra_by_rank_index
  }
  for rank_index in 0..<max_rank {
    let left_shift = option_int_or(min_shift_by_rank_index.get(rank_index), 0)
    let right_shift = option_int_or(
      min_shift_by_rank_index.get(rank_index + 1),
      left_shift,
    )
    let boundary_extra = (right_shift - left_shift).max(0)
    if boundary_extra > 0 {
      extra_by_rank_index[rank_index] = boundary_extra
    }
  }
  extra_by_rank_index
}
