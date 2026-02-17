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
fn should_include_layered_edge(
  source_id : String,
  target_id : String,
  order_index_by_node_id : Map[String, Int],
) -> Bool {
  if source_id == target_id {
    return false
  }
  let source_index = option_int_or(order_index_by_node_id.get(source_id), -1)
  let target_index = option_int_or(order_index_by_node_id.get(target_id), -1)
  source_index >= 0 && target_index >= 0 && source_index <= target_index
}

///|
fn collect_layered_adjacency(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  subgraph_entry_by_id : Map[String, String],
  subgraph_exit_by_id : Map[String, String],
  nodes_in_order : Array[MermaidNode],
) -> (Map[String, Array[String]], Map[String, Array[String]], Map[String, Int]) {
  let successors_by_node_id : Map[String, Array[String]] = {}
  let predecessors_by_node_id : Map[String, Array[String]] = {}
  let order_index_by_node_id : Map[String, Int] = {}
  let visible_node_ids : Map[String, Bool] = {}
  for i, node in nodes_in_order {
    order_index_by_node_id[node.id] = i
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
    if !should_include_layered_edge(
        source_id, target_id, order_index_by_node_id,
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
  (successors_by_node_id, predecessors_by_node_id, order_index_by_node_id)
}

///|
fn build_rank_by_node_id(
  nodes_in_order : Array[MermaidNode],
  successors_by_node_id : Map[String, Array[String]],
) -> Map[String, Int] {
  let rank_by_node_id : Map[String, Int] = {}
  for node in nodes_in_order {
    rank_by_node_id[node.id] = 0
  }
  for node in nodes_in_order {
    let source_rank = option_int_or(rank_by_node_id.get(node.id), 0)
    match successors_by_node_id.get(node.id) {
      Some(successors) =>
        for target_id in successors {
          let current_rank = option_int_or(rank_by_node_id.get(target_id), 0)
          let candidate_rank = source_rank + 1
          if candidate_rank > current_rank {
            rank_by_node_id[target_id] = candidate_rank
          }
        }
      None => ()
    }
  }
  rank_by_node_id
}

///|
fn compute_max_rank(
  nodes_in_order : Array[MermaidNode],
  rank_by_node_id : Map[String, Int],
) -> Int {
  let mut max_rank = 0
  for node in nodes_in_order {
    max_rank = max_rank.max(option_int_or(rank_by_node_id.get(node.id), 0))
  }
  max_rank
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
fn should_use_elk_layered_pipeline(graph : MermaidGraph) -> Bool {
  graph.diagram_kind is Flowchart &&
  !@layout_engine_graph_internal_core.is_state_graph(graph) &&
  !@layout_engine_graph_internal_core.is_class_or_er_graph(graph)
}

///|
/// Runs the ELK layered flow pipeline for non-state flowcharts.
pub fn run_elk_layered_flow_backend(
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
  let (successors_by_node_id, predecessors_by_node_id, order_index_by_node_id) = collect_layered_adjacency(
    graph, use_subgraph_redirects, subgraph_entry_by_id, subgraph_exit_by_id, nodes_in_order,
  )
  let rank_by_node_id = build_rank_by_node_id(
    nodes_in_order, successors_by_node_id,
  )
  let max_rank = compute_max_rank(nodes_in_order, rank_by_node_id)
  let rank_node_ids_by_rank = build_rank_node_ids(
    nodes_in_order, rank_by_node_id, max_rank,
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
  let horizontal = @layout_engine_graph_internal_core.layout_direction_is_horizontal(
    graph.direction,
  )
  let reverse = @layout_engine_graph_internal_core.layout_direction_is_reverse(
    graph.direction,
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
  let major_step = major_gap.max(global_major_size + (major_gap / 5).max(20))
  let min_minor_step = if horizontal {
    global_max_height + 12
  } else {
    global_max_width + 12
  }
  let minor_step = minor_gap.max(min_minor_step)
  let max_rank_minor_span = (max_rank_size - 1).max(0) * minor_step

  let major_center_by_rank : Map[Int, Int] = {}
  let major_start = padding + 70
  for displayed_rank in 0..<=max_rank {
    let rank = if reverse { max_rank - displayed_rank } else { displayed_rank }
    major_center_by_rank[rank] = major_start + displayed_rank * major_step
  }

  let x_by_node_id : Map[String, Int] = {}
  let y_by_node_id : Map[String, Int] = {}
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) => {
        let rank_minor_span = (node_ids.length() - 1).max(0) * minor_step
        let minor_start = padding +
          70 +
          (max_rank_minor_span - rank_minor_span) / 2
        let major_center = option_int_or(
          major_center_by_rank.get(rank),
          padding + 70,
        )
        for lane, node_id in node_ids {
          let minor_coord = minor_start + lane * minor_step
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
pub fn elk_should_use_layered_pipeline(graph : MermaidGraph) -> Bool {
  should_use_elk_layered_pipeline(graph)
}
