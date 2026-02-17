///|
fn option_int_or(value : Int?, fallback : Int) -> Int {
  @layout_engine_graph_internal_core.option_int_or(value, fallback)
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
fn setup_phase_snapshot(
  request : GraphLayoutBackendRequest,
  nodes_in_order : Array[MermaidNode],
) -> GraphLayoutPhaseSnapshot {
  {
    phase: "setup",
    node_count: nodes_in_order.length(),
    edge_count: request.graph.edges.length(),
    group_count: request.graph.subgraphs.length(),
    width: 0,
    height: 0,
  }
}

///|
fn placement_phase_snapshot(
  request : GraphLayoutBackendRequest,
  positioned_nodes : Array[PositionedNode],
) -> GraphLayoutPhaseSnapshot {
  {
    phase: "placement",
    node_count: positioned_nodes.length(),
    edge_count: request.graph.edges.length(),
    group_count: request.graph.subgraphs.length(),
    width: 0,
    height: 0,
  }
}

///|
fn final_phase_snapshot(
  positioned_graph : PositionedGraph,
) -> GraphLayoutPhaseSnapshot {
  {
    phase: "final",
    node_count: positioned_graph.nodes.length(),
    edge_count: positioned_graph.edges.length(),
    group_count: positioned_graph.groups.length(),
    width: positioned_graph.width,
    height: positioned_graph.height,
  }
}

///|
fn build_order_index_by_node_id(
  nodes_in_order : Array[MermaidNode],
) -> Map[String, Int] {
  let order_index_by_node_id : Map[String, Int] = {}
  for i, node in nodes_in_order {
    order_index_by_node_id[node.id] = i
  }
  order_index_by_node_id
}

///|
fn should_include_ranked_layered_edge(
  source_id : String,
  target_id : String,
  rank_by_node_id : Map[String, Int],
) -> Bool {
  if source_id == target_id {
    return false
  }
  let source_rank = option_int_or(rank_by_node_id.get(source_id), -1)
  let target_rank = option_int_or(rank_by_node_id.get(target_id), -1)
  source_rank >= 0 && target_rank >= 0 && source_rank <= target_rank
}

///|
fn collect_layered_adjacency_from_rank(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  subgraph_entry_by_id : Map[String, String],
  subgraph_exit_by_id : Map[String, String],
  nodes_in_order : Array[MermaidNode],
  rank_by_node_id : Map[String, Int],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let successors_by_node_id : Map[String, Array[String]] = {}
  let predecessors_by_node_id : Map[String, Array[String]] = {}
  let visible_node_ids : Map[String, Bool] = {}
  for node in nodes_in_order {
    visible_node_ids[node.id] = true
    successors_by_node_id[node.id] = []
    predecessors_by_node_id[node.id] = []
  }
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
    if !visible_node_ids.contains(source_id) ||
      !visible_node_ids.contains(target_id) {
      continue
    }
    if !should_include_ranked_layered_edge(
        source_id, target_id, rank_by_node_id,
      ) {
      continue
    }
    match successors_by_node_id.get(source_id) {
      Some(successors) => successors.push(target_id)
      None => ()
    }
    match predecessors_by_node_id.get(target_id) {
      Some(predecessors) => predecessors.push(source_id)
      None => ()
    }
  }
  (successors_by_node_id, predecessors_by_node_id)
}

///|
fn build_rank_node_ids(
  nodes_in_order : Array[MermaidNode],
  rank_by_node_id : Map[String, Int],
  max_rank : Int,
) -> Map[Int, Array[String]] {
  let rank_node_ids_by_rank : Map[Int, Array[String]] = {}
  for rank in 0..<=max_rank {
    rank_node_ids_by_rank[rank] = []
  }
  for node in nodes_in_order {
    let rank = option_int_or(rank_by_node_id.get(node.id), 0)
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) => node_ids.push(node.id)
      None => ()
    }
  }
  rank_node_ids_by_rank
}

///|
fn build_rank_node_ids_by_lane(
  nodes_in_order : Array[MermaidNode],
  rank_by_node_id : Map[String, Int],
  lane_by_node_id : Map[String, Int],
  order_index_by_node_id : Map[String, Int],
  max_rank : Int,
) -> Map[Int, Array[String]] {
  let rank_node_ids_by_rank = build_rank_node_ids(
    nodes_in_order, rank_by_node_id, max_rank,
  )
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        node_ids.sort_by((left, right) => {
          let left_lane = option_int_or(lane_by_node_id.get(left), 0)
          let right_lane = option_int_or(lane_by_node_id.get(right), 0)
          if left_lane != right_lane {
            return left_lane.compare(right_lane)
          }
          option_int_or(order_index_by_node_id.get(left), 0).compare(
            option_int_or(order_index_by_node_id.get(right), 0),
          )
        })
      None => ()
    }
  }
  rank_node_ids_by_rank
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
fn node_neighbor_barycenter(
  node_id : String,
  neighbor_by_node_id : Map[String, Array[String]],
  rank_position_by_node_id : Map[String, Int],
) -> (Bool, Int) {
  let mut sum = 0
  let mut count = 0
  match neighbor_by_node_id.get(node_id) {
    Some(neighbors) =>
      for neighbor_id in neighbors {
        match rank_position_by_node_id.get(neighbor_id) {
          Some(position) => {
            sum += position
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
    (true, sum * 1000 / count)
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
    let (left_has_center, left_center) = node_neighbor_barycenter(
      left, neighbor_by_node_id, rank_position_by_node_id,
    )
    let (right_has_center, right_center) = node_neighbor_barycenter(
      right, neighbor_by_node_id, rank_position_by_node_id,
    )
    if left_has_center && right_has_center && left_center != right_center {
      return left_center.compare(right_center)
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
fn should_use_elk_layered_pipeline(graph : MermaidGraph) -> Bool {
  // Keep ELK layered pass scoped to small/medium flowcharts where the
  // lightweight MoonBit implementation is quality-competitive. Larger dense
  // graphs fallback to the shared backend for stability.
  let within_layered_complexity_budget = graph.nodes.length() <= 16 &&
    graph.edges.length() <= 30
  graph.diagram_kind is Flowchart &&
  !@layout_engine_graph_internal_core.is_state_graph(graph) &&
  !@layout_engine_graph_internal_core.is_class_or_er_graph(graph) &&
  within_layered_complexity_budget
}

///|
/// Runs the ELK layered flow pipeline for non-state flowcharts.
fn run_elk_layered_flow_backend(
  request : GraphLayoutBackendRequest,
  routing_policy : GraphBackendRoutingPolicy,
) -> GraphLayoutBackendResult {
  let graph = request.graph
  let options = request.options
  let use_subgraph_redirects = request.use_subgraph_redirects
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, use_subgraph_redirects,
  )
  let subgraph_entry_by_id = prep_state.subgraph_entry_by_id()
  let subgraph_exit_by_id = prep_state.subgraph_exit_by_id()
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order(),
    graph.edges,
  )
  let horizontal = @layout_engine_graph_internal_core.layout_direction_is_horizontal(
    graph.direction,
  )
  let reverse = @layout_engine_graph_internal_core.layout_direction_is_reverse(
    graph.direction,
  )
  let order_index_by_node_id = build_order_index_by_node_id(nodes_in_order)
  let lane_state = @layout_engine_graph_lane_core.compute_legacy_lane_state(
    graph,
    nodes_in_order,
    false,
    false,
    horizontal,
    request.compact_fanin,
    false,
    false,
  )
  let rank_by_node_id = lane_state.flow_rank_by_node_id()
  let max_rank = lane_state.flow_max_rank()
  let rank_node_ids_by_rank = build_rank_node_ids_by_lane(
    nodes_in_order,
    rank_by_node_id,
    lane_state.flow_lane_by_node_id(),
    order_index_by_node_id,
    max_rank,
  )
  let (successors_by_node_id, predecessors_by_node_id) = collect_layered_adjacency_from_rank(
    graph, use_subgraph_redirects, subgraph_entry_by_id, subgraph_exit_by_id, nodes_in_order,
    rank_by_node_id,
  )
  optimize_rank_order(
    rank_node_ids_by_rank, max_rank, predecessors_by_node_id, successors_by_node_id,
    order_index_by_node_id,
  )
  maybe_refine_rank_order_by_swaps(
    rank_node_ids_by_rank,
    max_rank,
    rank_by_node_id,
    successors_by_node_id,
    nodes_in_order.length(),
    graph.edges.length(),
  )

  let padding = @layout_engine_graph_internal_core.resolve_padding(options)
  let node_spacing = @layout_engine_graph_internal_core.resolve_node_spacing(
    options,
  )
  let layer_spacing = @layout_engine_graph_internal_core.resolve_layer_spacing(
    options,
  )

  let width_by_node_id : Map[String, Int] = {}
  let height_by_node_id : Map[String, Int] = {}
  let mut global_max_width = 0
  let mut global_max_height = 0
  for node in nodes_in_order {
    let (width, height) = node_dimensions(node)
    width_by_node_id[node.id] = width
    height_by_node_id[node.id] = height
    global_max_width = global_max_width.max(width)
    global_max_height = global_max_height.max(height)
  }

  let mut max_rank_size = 1
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) => max_rank_size = max_rank_size.max(node_ids.length())
      None => ()
    }
  }

  let major_gap = if horizontal { node_spacing } else { layer_spacing }
  let minor_gap = if horizontal { layer_spacing } else { node_spacing }
  let global_major_size = if horizontal {
    global_max_width
  } else {
    global_max_height
  }
  let base_major_step = major_gap.max(
    global_major_size + (major_gap / 5).max(20),
  )
  let min_minor_step = if horizontal {
    global_max_height + 12
  } else {
    global_max_width + 12
  }
  let minor_step = minor_gap.max(min_minor_step)
  let max_rank_minor_span = (max_rank_size - 1).max(0) * minor_step
  let minor_coord_by_node_id = build_minor_coord_by_node_id(
    rank_node_ids_by_rank, max_rank, padding, minor_step, max_rank_minor_span, predecessors_by_node_id,
    successors_by_node_id, horizontal, width_by_node_id, height_by_node_id,
  )
  let rank_pair_label_major_gap = build_rank_pair_label_major_gap(
    graph, use_subgraph_redirects, subgraph_entry_by_id, subgraph_exit_by_id, rank_by_node_id,
    horizontal,
  )

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

  let positioned_index_by_id = positioned_index_by_node_id(positioned_nodes)
  let node_horizontal_by_id : Map[String, Bool] = {}
  for node in positioned_nodes {
    node_horizontal_by_id[node.id] = horizontal
  }

  let mut max_right = padding
  let mut max_bottom = padding
  for node in positioned_nodes {
    max_right = max_right.max(node.x + node.width / 2)
    max_bottom = max_bottom.max(node.y + node.height / 2)
  }

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
  let positioned_graph = @layout_engine_graph_finalize_core.finalize_positioned_graph(
    padding, max_right, max_bottom, positioned_nodes, positioned_edges, positioned_groups,
  )
  let phase_snapshots = [
    setup_phase_snapshot(request, nodes_in_order),
    placement_phase_snapshot(request, positioned_nodes),
    final_phase_snapshot(positioned_graph),
  ]
  { positioned_graph, phase_snapshots }
}

///|
/// Returns true when the ELK layered pipeline should be used.
fn elk_should_use_layered_pipeline(graph : MermaidGraph) -> Bool {
  should_use_elk_layered_pipeline(graph)
}
