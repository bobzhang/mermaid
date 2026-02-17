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
fn node_neighbor_minor_center(
  node_id : String,
  neighbor_by_node_id : Map[String, Array[String]],
  minor_coord_by_node_id : Map[String, Int],
) -> (Bool, Int) {
  let mut sum = 0
  let mut count = 0
  match neighbor_by_node_id.get(node_id) {
    Some(neighbors) =>
      for neighbor_id in neighbors {
        match minor_coord_by_node_id.get(neighbor_id) {
          Some(minor_coord) => {
            sum += minor_coord
            count += 1
          }
          None => ()
        }
      }
    None => ()
  }
  if count == 0 {
    (false, 0)
  } else {
    (true, sum / count)
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
  base_major_step : Int,
  rank_pair_label_major_gap : Map[String, Int],
) -> Int {
  let label_clearance = option_int_or(
    rank_pair_label_major_gap.get(rank_pair_key(left_rank, right_rank)),
    0,
  )
  if label_clearance <= base_major_step {
    base_major_step
  } else {
    // Dampen label-driven expansion so long labels gain room without causing
    // large global stretching on small graphs.
    let overflow = label_clearance - base_major_step
    base_major_step + overflow * 2 / 3
  }
}

///|
fn build_major_center_by_rank(
  max_rank : Int,
  reverse : Bool,
  padding : Int,
  base_major_step : Int,
  rank_pair_label_major_gap : Map[String, Int],
) -> Map[Int, Int] {
  let major_center_by_rank : Map[Int, Int] = {}
  let major_start = padding + 70
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
      let step = rank_pair_major_step(
        previous_rank, rank, base_major_step, rank_pair_label_major_gap,
      )
      displayed_major_center += step
    }
    major_center_by_rank[rank] = displayed_major_center
  }
  major_center_by_rank
}

///|
fn build_axis_coords_by_node_id(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  major_center_by_rank : Map[Int, Int],
  minor_coord_by_node_id : Map[String, Int],
  padding : Int,
  horizontal : Bool,
) -> (Map[String, Int], Map[String, Int]) {
  let x_by_node_id : Map[String, Int] = {}
  let y_by_node_id : Map[String, Int] = {}
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) => {
        let major_center = option_int_or(
          major_center_by_rank.get(rank),
          padding + 70,
        )
        for node_id in node_ids {
          let minor_coord = option_int_or(
            minor_coord_by_node_id.get(node_id),
            padding + 70,
          )
          if horizontal {
            x_by_node_id[node_id] = major_center
            y_by_node_id[node_id] = minor_coord
          } else {
            x_by_node_id[node_id] = minor_coord
            y_by_node_id[node_id] = major_center
          }
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
  let positioned_groups = @layout_engine_graph_group_core.build_legacy_positioned_groups(
    graph, padding, horizontal, reverse, false, node_spacing, layer_spacing, positioned_nodes,
    positioned_by_id, positioned_index_by_id,
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

///|
fn should_use_elk_layered_pipeline(graph : MermaidGraph) -> Bool {
  elk_graph_supports_layered_pipeline(graph)
}
