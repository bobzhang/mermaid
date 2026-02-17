///|
fn option_int_or(value : Int?, fallback : Int) -> Int {
  @layout_engine_graph_internal_core.option_int_or(value, fallback)
}

///|
fn option_bool_or(value : Bool?, fallback : Bool) -> Bool {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
fn node_is_active(
  active_by_node_id : Map[String, Bool],
  node_id : String,
) -> Bool {
  option_bool_or(active_by_node_id.get(node_id), false)
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
priv struct ElkLayeredSetupState {
  graph : MermaidGraph
  options : RenderOptions
  use_subgraph_redirects : Bool
  compact_fanin : Bool
  subgraph_entry_by_id : Map[String, String]
  subgraph_exit_by_id : Map[String, String]
  nodes_in_order : Array[MermaidNode]
  horizontal : Bool
  reverse : Bool
  base_order_index_by_node_id : Map[String, Int]
  node_ids_in_order : Array[String]
}

///|
fn run_elk_layered_setup_phase(
  request : GraphLayoutBackendRequest,
) -> ElkLayeredSetupState {
  let graph = request.graph
  let options = request.options
  let use_subgraph_redirects = request.use_subgraph_redirects
  let compact_fanin = request.compact_fanin
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
  let base_order_index_by_node_id = build_order_index_by_node_id(nodes_in_order)
  let node_ids_in_order : Array[String] = []
  for node in nodes_in_order {
    node_ids_in_order.push(node.id)
  }
  {
    graph,
    options,
    use_subgraph_redirects,
    compact_fanin,
    subgraph_entry_by_id,
    subgraph_exit_by_id,
    nodes_in_order,
    horizontal,
    reverse,
    base_order_index_by_node_id,
    node_ids_in_order,
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
fn build_order_index_by_id(
  node_ids_in_order : Array[String],
) -> Map[String, Int] {
  let order_index_by_node_id : Map[String, Int] = {}
  for i, node_id in node_ids_in_order {
    order_index_by_node_id[node_id] = i
  }
  order_index_by_node_id
}

///|
fn compare_node_ids_by_order(
  left : String,
  right : String,
  order_index_by_node_id : Map[String, Int],
) -> Int {
  let left_order = option_int_or(order_index_by_node_id.get(left), 0)
  let right_order = option_int_or(order_index_by_node_id.get(right), 0)
  if left_order != right_order {
    left_order.compare(right_order)
  } else {
    left.compare(right)
  }
}

///|
fn collect_visible_resolved_edges(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  subgraph_entry_by_id : Map[String, String],
  subgraph_exit_by_id : Map[String, String],
  node_ids : Array[String],
) -> Array[(String, String)] {
  let visible_node_ids : Map[String, Bool] = {}
  for node_id in node_ids {
    visible_node_ids[node_id] = true
  }
  let resolved_edges : Array[(String, String)] = []
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
    if source_id == target_id {
      continue
    }
    if !visible_node_ids.contains(source_id) ||
      !visible_node_ids.contains(target_id) {
      continue
    }
    resolved_edges.push((source_id, target_id))
  }
  resolved_edges
}

///|
fn adjust_neighbor_degree_after_removal(
  neighbors : Array[String]?,
  degree_by_node_id : Map[String, Int],
  active_by_node_id : Map[String, Bool],
) -> Unit {
  match neighbors {
    Some(found) =>
      for neighbor_id in found {
        if !node_is_active(active_by_node_id, neighbor_id) {
          continue
        }
        degree_by_node_id[neighbor_id] = option_int_or(
            degree_by_node_id.get(neighbor_id),
            0,
          ) -
          1
      }
    None => ()
  }
}

///|
fn remove_feedback_order_node(
  node_id : String,
  append_left : Bool,
  left_order : Array[String],
  right_order : Array[String],
  active_by_node_id : Map[String, Bool],
  out_neighbors_by_node_id : Map[String, Array[String]],
  in_neighbors_by_node_id : Map[String, Array[String]],
  indegree_by_node_id : Map[String, Int],
  outdegree_by_node_id : Map[String, Int],
) -> Unit {
  active_by_node_id[node_id] = false
  if append_left {
    left_order.push(node_id)
  } else {
    right_order.push(node_id)
  }
  adjust_neighbor_degree_after_removal(
    out_neighbors_by_node_id.get(node_id),
    indegree_by_node_id,
    active_by_node_id,
  )
  adjust_neighbor_degree_after_removal(
    in_neighbors_by_node_id.get(node_id),
    outdegree_by_node_id,
    active_by_node_id,
  )
}

///|
fn collect_active_source_or_sink_nodes(
  node_ids : Array[String],
  active_by_node_id : Map[String, Bool],
  indegree_by_node_id : Map[String, Int],
  outdegree_by_node_id : Map[String, Int],
  collect_sinks : Bool,
) -> Array[String] {
  let selected : Array[String] = []
  for node_id in node_ids {
    if !node_is_active(active_by_node_id, node_id) {
      continue
    }
    let indegree = option_int_or(indegree_by_node_id.get(node_id), 0)
    let outdegree = option_int_or(outdegree_by_node_id.get(node_id), 0)
    if collect_sinks {
      if outdegree == 0 {
        selected.push(node_id)
      }
    } else if indegree == 0 {
      selected.push(node_id)
    }
  }
  selected
}

///|
fn find_feedback_break_node(
  node_ids : Array[String],
  active_by_node_id : Map[String, Bool],
  indegree_by_node_id : Map[String, Int],
  outdegree_by_node_id : Map[String, Int],
  base_order_index_by_node_id : Map[String, Int],
) -> String? {
  let mut has_best = false
  let mut best_node_id = ""
  let mut best_score = 0
  let mut best_outdegree = 0
  for node_id in node_ids {
    if !node_is_active(active_by_node_id, node_id) {
      continue
    }
    let indegree = option_int_or(indegree_by_node_id.get(node_id), 0)
    let outdegree = option_int_or(outdegree_by_node_id.get(node_id), 0)
    let score = outdegree - indegree
    if !has_best ||
      score > best_score ||
      (score == best_score && outdegree > best_outdegree) ||
      (
        score == best_score &&
        outdegree == best_outdegree &&
        compare_node_ids_by_order(
          node_id, best_node_id, base_order_index_by_node_id,
        ) <
        0
      ) {
      has_best = true
      best_node_id = node_id
      best_score = score
      best_outdegree = outdegree
    }
  }
  if has_best {
    Some(best_node_id)
  } else {
    None
  }
}

///|
fn compute_feedback_acyclic_node_order(
  node_ids : Array[String],
  resolved_edges : Array[(String, String)],
  base_order_index_by_node_id : Map[String, Int],
) -> Array[String] {
  let active_by_node_id : Map[String, Bool] = {}
  let indegree_by_node_id : Map[String, Int] = {}
  let outdegree_by_node_id : Map[String, Int] = {}
  let out_neighbors_by_node_id : Map[String, Array[String]] = {}
  let in_neighbors_by_node_id : Map[String, Array[String]] = {}
  for node_id in node_ids {
    active_by_node_id[node_id] = true
    indegree_by_node_id[node_id] = 0
    outdegree_by_node_id[node_id] = 0
    out_neighbors_by_node_id[node_id] = []
    in_neighbors_by_node_id[node_id] = []
  }
  for edge in resolved_edges {
    let (source_id, target_id) = edge
    outdegree_by_node_id[source_id] = option_int_or(
        outdegree_by_node_id.get(source_id),
        0,
      ) +
      1
    indegree_by_node_id[target_id] = option_int_or(
        indegree_by_node_id.get(target_id),
        0,
      ) +
      1
    match out_neighbors_by_node_id.get(source_id) {
      Some(neighbors) => neighbors.push(target_id)
      None => ()
    }
    match in_neighbors_by_node_id.get(target_id) {
      Some(neighbors) => neighbors.push(source_id)
      None => ()
    }
  }

  let left_order : Array[String] = []
  let right_order : Array[String] = []
  let mut remaining = node_ids.length()
  while remaining > 0 {
    let sinks = collect_active_source_or_sink_nodes(
      node_ids, active_by_node_id, indegree_by_node_id, outdegree_by_node_id, true,
    )
    if sinks.length() > 0 {
      sinks.sort_by((left, right) => {
        compare_node_ids_by_order(left, right, base_order_index_by_node_id)
      })
      for node_id in sinks {
        if !node_is_active(active_by_node_id, node_id) {
          continue
        }
        remove_feedback_order_node(
          node_id, false, left_order, right_order, active_by_node_id, out_neighbors_by_node_id,
          in_neighbors_by_node_id, indegree_by_node_id, outdegree_by_node_id,
        )
        remaining -= 1
      }
      continue
    }

    let sources = collect_active_source_or_sink_nodes(
      node_ids, active_by_node_id, indegree_by_node_id, outdegree_by_node_id, false,
    )
    if sources.length() > 0 {
      sources.sort_by((left, right) => {
        compare_node_ids_by_order(left, right, base_order_index_by_node_id)
      })
      for node_id in sources {
        if !node_is_active(active_by_node_id, node_id) {
          continue
        }
        remove_feedback_order_node(
          node_id, true, left_order, right_order, active_by_node_id, out_neighbors_by_node_id,
          in_neighbors_by_node_id, indegree_by_node_id, outdegree_by_node_id,
        )
        remaining -= 1
      }
      continue
    }

    match
      find_feedback_break_node(
        node_ids, active_by_node_id, indegree_by_node_id, outdegree_by_node_id, base_order_index_by_node_id,
      ) {
      Some(node_id) => {
        remove_feedback_order_node(
          node_id, true, left_order, right_order, active_by_node_id, out_neighbors_by_node_id,
          in_neighbors_by_node_id, indegree_by_node_id, outdegree_by_node_id,
        )
        remaining -= 1
      }
      None => break
    }
  }

  let ordered : Array[String] = []
  for node_id in left_order {
    ordered.push(node_id)
  }
  let mut i = right_order.length()
  while i > 0 {
    i = i - 1
    ordered.push(right_order[i])
  }
  ordered
}

///|
fn sort_ready_nodes_by_order(
  ready_node_ids : Array[String],
  order_index_by_node_id : Map[String, Int],
) -> Unit {
  ready_node_ids.sort_by((left, right) => {
    compare_node_ids_by_order(left, right, order_index_by_node_id)
  })
}

///|
fn orient_edges_by_feedback_order(
  resolved_edges : Array[(String, String)],
  order_index_by_node_id : Map[String, Int],
) -> Array[(String, String)] {
  let acyclic_edges : Array[(String, String)] = []
  for edge in resolved_edges {
    let (source_id, target_id) = edge
    if source_id == target_id {
      continue
    }
    let source_order = option_int_or(order_index_by_node_id.get(source_id), -1)
    let target_order = option_int_or(order_index_by_node_id.get(target_id), -1)
    if source_order < 0 || target_order < 0 || source_order == target_order {
      continue
    }
    if source_order < target_order {
      acyclic_edges.push((source_id, target_id))
    } else {
      acyclic_edges.push((target_id, source_id))
    }
  }
  acyclic_edges
}

///|
fn build_layered_rank_state(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  subgraph_entry_by_id : Map[String, String],
  subgraph_exit_by_id : Map[String, String],
  nodes_in_order : Array[MermaidNode],
) -> (
  Map[String, Int],
  Int,
  Map[String, Int],
  Map[String, Array[String]],
  Map[String, Array[String]],
) {
  let node_ids : Array[String] = []
  for node in nodes_in_order {
    node_ids.push(node.id)
  }
  let base_order_index_by_node_id = build_order_index_by_node_id(nodes_in_order)
  let resolved_edges = collect_visible_resolved_edges(
    graph, use_subgraph_redirects, subgraph_entry_by_id, subgraph_exit_by_id, node_ids,
  )
  let feedback_order_node_ids = compute_feedback_acyclic_node_order(
    node_ids, resolved_edges, base_order_index_by_node_id,
  )
  let order_index_by_node_id = build_order_index_by_id(feedback_order_node_ids)
  let acyclic_edges = orient_edges_by_feedback_order(
    resolved_edges, order_index_by_node_id,
  )

  let rank_by_node_id : Map[String, Int] = {}
  let indegree_by_node_id : Map[String, Int] = {}
  let successors_by_node_id : Map[String, Array[String]] = {}
  let predecessors_by_node_id : Map[String, Array[String]] = {}
  for node_id in node_ids {
    rank_by_node_id[node_id] = 0
    indegree_by_node_id[node_id] = 0
    successors_by_node_id[node_id] = []
    predecessors_by_node_id[node_id] = []
  }
  for edge in acyclic_edges {
    let (source_id, target_id) = edge
    match successors_by_node_id.get(source_id) {
      Some(successors) => successors.push(target_id)
      None => ()
    }
    match predecessors_by_node_id.get(target_id) {
      Some(predecessors) => predecessors.push(source_id)
      None => ()
    }
    indegree_by_node_id[target_id] = option_int_or(
        indegree_by_node_id.get(target_id),
        0,
      ) +
      1
  }

  let ready_node_ids : Array[String] = []
  for node_id in node_ids {
    if option_int_or(indegree_by_node_id.get(node_id), 0) == 0 {
      ready_node_ids.push(node_id)
    }
  }
  sort_ready_nodes_by_order(ready_node_ids, order_index_by_node_id)

  while ready_node_ids.length() > 0 {
    let node_id = ready_node_ids[0]
    let _ = ready_node_ids.remove(0)
    let node_rank = option_int_or(rank_by_node_id.get(node_id), 0)
    match successors_by_node_id.get(node_id) {
      Some(successors) =>
        for successor_id in successors {
          let next_rank = node_rank + 1
          if next_rank > option_int_or(rank_by_node_id.get(successor_id), 0) {
            rank_by_node_id[successor_id] = next_rank
          }
          indegree_by_node_id[successor_id] = option_int_or(
              indegree_by_node_id.get(successor_id),
              0,
            ) -
            1
          if option_int_or(indegree_by_node_id.get(successor_id), 0) == 0 {
            ready_node_ids.push(successor_id)
            sort_ready_nodes_by_order(ready_node_ids, order_index_by_node_id)
          }
        }
      None => ()
    }
  }

  let mut max_rank = 0
  for _, rank in rank_by_node_id {
    if rank > max_rank {
      max_rank = rank
    }
  }
  (
    rank_by_node_id, max_rank, order_index_by_node_id, successors_by_node_id, predecessors_by_node_id,
  )
}

///|
fn build_layered_neighbor_state_from_rank_seed(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  subgraph_entry_by_id : Map[String, String],
  subgraph_exit_by_id : Map[String, String],
  node_ids : Array[String],
  rank_by_node_id : Map[String, Int],
  order_index_by_node_id : Map[String, Int],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let successors_by_node_id : Map[String, Array[String]] = {}
  let predecessors_by_node_id : Map[String, Array[String]] = {}
  for node_id in node_ids {
    successors_by_node_id[node_id] = []
    predecessors_by_node_id[node_id] = []
  }

  let resolved_edges = collect_visible_resolved_edges(
    graph, use_subgraph_redirects, subgraph_entry_by_id, subgraph_exit_by_id, node_ids,
  )
  for edge in resolved_edges {
    let (source_id, target_id) = edge
    let source_rank = option_int_or(rank_by_node_id.get(source_id), -1)
    let target_rank = option_int_or(rank_by_node_id.get(target_id), -1)
    if source_rank < 0 || target_rank < 0 {
      continue
    }
    let (oriented_source_id, oriented_target_id) = if source_rank < target_rank {
      (source_id, target_id)
    } else if source_rank > target_rank {
      (target_id, source_id)
    } else if compare_node_ids_by_order(
        source_id, target_id, order_index_by_node_id,
      ) <=
      0 {
      (source_id, target_id)
    } else {
      (target_id, source_id)
    }
    append_normalized_ordering_edge(
      oriented_source_id, oriented_target_id, successors_by_node_id, predecessors_by_node_id,
    )
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
priv struct LayeredVirtualOrderingState {
  rank_node_ids_by_rank : Map[Int, Array[String]]
  rank_by_node_id : Map[String, Int]
  order_index_by_node_id : Map[String, Int]
  predecessors_by_node_id : Map[String, Array[String]]
  successors_by_node_id : Map[String, Array[String]]
  virtual_by_node_id : Map[String, Bool]
}

///|
fn clone_rank_node_ids_by_rank(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
) -> Map[Int, Array[String]] {
  let cloned : Map[Int, Array[String]] = {}
  for rank in 0..<=max_rank {
    let copied_node_ids : Array[String] = []
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for node_id in node_ids {
          copied_node_ids.push(node_id)
        }
      None => ()
    }
    cloned[rank] = copied_node_ids
  }
  cloned
}

///|
fn ensure_rank_node_ids_entry(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  rank : Int,
) -> Unit {
  if !rank_node_ids_by_rank.contains(rank) {
    rank_node_ids_by_rank[rank] = []
  }
}

///|
fn append_normalized_ordering_edge(
  source_id : String,
  target_id : String,
  successors_by_node_id : Map[String, Array[String]],
  predecessors_by_node_id : Map[String, Array[String]],
) -> Unit {
  if source_id == target_id {
    return
  }
  match successors_by_node_id.get(source_id) {
    Some(successors) => successors.push(target_id)
    None => successors_by_node_id[source_id] = [target_id]
  }
  match predecessors_by_node_id.get(target_id) {
    Some(predecessors) => predecessors.push(source_id)
    None => predecessors_by_node_id[target_id] = [source_id]
  }
}

///|
fn build_virtual_ordering_state(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  rank_by_node_id : Map[String, Int],
  max_rank : Int,
  order_index_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> LayeredVirtualOrderingState {
  let normalized_rank_node_ids_by_rank = clone_rank_node_ids_by_rank(
    rank_node_ids_by_rank, max_rank,
  )
  let normalized_rank_by_node_id : Map[String, Int] = {}
  let normalized_order_index_by_node_id : Map[String, Int] = {}
  let normalized_predecessors_by_node_id : Map[String, Array[String]] = {}
  let normalized_successors_by_node_id : Map[String, Array[String]] = {}
  let virtual_by_node_id : Map[String, Bool] = {}

  for rank in 0..<=max_rank {
    match normalized_rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for position, node_id in node_ids {
          normalized_rank_by_node_id[node_id] = rank
          normalized_order_index_by_node_id[node_id] = option_int_or(
            order_index_by_node_id.get(node_id),
            rank * 10000 + position,
          )
          normalized_predecessors_by_node_id[node_id] = []
          normalized_successors_by_node_id[node_id] = []
          virtual_by_node_id[node_id] = false
        }
      None => ()
    }
  }

  let mut edge_serial = 0
  for source_id, direct_successors in successors_by_node_id {
    let source_rank = option_int_or(rank_by_node_id.get(source_id), -1)
    if source_rank < 0 {
      continue
    }
    let source_order = option_int_or(order_index_by_node_id.get(source_id), 0)
    for target_id in direct_successors {
      let target_rank = option_int_or(rank_by_node_id.get(target_id), -1)
      if target_rank <= source_rank {
        continue
      }
      let target_order = option_int_or(
        order_index_by_node_id.get(target_id),
        source_order,
      )
      let rank_span = target_rank - source_rank
      let mut previous_id = source_id
      if rank_span > 1 {
        for offset in 1..<rank_span {
          let virtual_rank = source_rank + offset
          let virtual_id = "__elk_virtual_\{edge_serial}_\{offset}"
          ensure_rank_node_ids_entry(
            normalized_rank_node_ids_by_rank, virtual_rank,
          )
          match normalized_rank_node_ids_by_rank.get(virtual_rank) {
            Some(node_ids) => node_ids.push(virtual_id)
            None => ()
          }
          let interpolated_order = (
              source_order * (rank_span - offset) + target_order * offset
            ) *
            1000 /
            rank_span
          normalized_rank_by_node_id[virtual_id] = virtual_rank
          normalized_order_index_by_node_id[virtual_id] = interpolated_order
          normalized_predecessors_by_node_id[virtual_id] = []
          normalized_successors_by_node_id[virtual_id] = []
          virtual_by_node_id[virtual_id] = true
          append_normalized_ordering_edge(
            previous_id, virtual_id, normalized_successors_by_node_id, normalized_predecessors_by_node_id,
          )
          previous_id = virtual_id
        }
      }
      append_normalized_ordering_edge(
        previous_id, target_id, normalized_successors_by_node_id, normalized_predecessors_by_node_id,
      )
      edge_serial += 1
    }
  }

  let mut dense_order = 0
  for rank in 0..<=max_rank {
    match normalized_rank_node_ids_by_rank.get(rank) {
      Some(node_ids) => {
        node_ids.sort_by((left, right) => {
          let left_order = option_int_or(
            normalized_order_index_by_node_id.get(left),
            0,
          )
          let right_order = option_int_or(
            normalized_order_index_by_node_id.get(right),
            0,
          )
          if left_order != right_order {
            left_order.compare(right_order)
          } else {
            left.compare(right)
          }
        })
        for node_id in node_ids {
          normalized_order_index_by_node_id[node_id] = dense_order
          dense_order += 1
        }
      }
      None => ()
    }
  }

  {
    rank_node_ids_by_rank: normalized_rank_node_ids_by_rank,
    rank_by_node_id: normalized_rank_by_node_id,
    order_index_by_node_id: normalized_order_index_by_node_id,
    predecessors_by_node_id: normalized_predecessors_by_node_id,
    successors_by_node_id: normalized_successors_by_node_id,
    virtual_by_node_id,
  }
}

///|
fn filter_real_rank_node_ids_by_rank(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  virtual_by_node_id : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let real_rank_node_ids_by_rank : Map[Int, Array[String]] = {}
  for rank in 0..<=max_rank {
    let real_node_ids : Array[String] = []
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for node_id in node_ids {
          if !option_bool_or(virtual_by_node_id.get(node_id), false) {
            real_node_ids.push(node_id)
          }
        }
      None => ()
    }
    real_rank_node_ids_by_rank[rank] = real_node_ids
  }
  real_rank_node_ids_by_rank
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
fn node_neighbor_order_key(
  node_id : String,
  neighbor_by_node_id : Map[String, Array[String]],
  rank_position_by_node_id : Map[String, Int],
) -> (Bool, Int, Int) {
  let positions : Array[Int] = []
  let mut sum = 0
  match neighbor_by_node_id.get(node_id) {
    Some(neighbors) =>
      for neighbor_id in neighbors {
        match rank_position_by_node_id.get(neighbor_id) {
          Some(position) => {
            positions.push(position)
            sum += position
          }
          None => ()
        }
      }
    None => ()
  }
  if positions.length() == 0 {
    (false, 0, 0)
  } else {
    positions.sort()
    let count = positions.length()
    let median_scaled = if count % 2 == 1 {
      positions[count / 2] * 1000
    } else {
      (positions[count / 2 - 1] + positions[count / 2]) * 500
    }
    let mean_scaled = sum * 1000 / count
    (true, median_scaled, mean_scaled)
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
    let (left_has_center, left_median, left_mean) = node_neighbor_order_key(
      left, neighbor_by_node_id, rank_position_by_node_id,
    )
    let (right_has_center, right_median, right_mean) = node_neighbor_order_key(
      right, neighbor_by_node_id, rank_position_by_node_id,
    )
    if left_has_center && right_has_center && left_median != right_median {
      return left_median.compare(right_median)
    }
    if left_has_center && right_has_center && left_mean != right_mean {
      return left_mean.compare(right_mean)
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
fn build_optimized_rank_node_ids_by_rank(
  base_rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
  rank_by_node_id : Map[String, Int],
  node_count : Int,
  edge_count : Int,
) -> Map[Int, Array[String]] {
  let optimized_rank_node_ids_by_rank = clone_rank_node_ids_by_rank(
    base_rank_node_ids_by_rank, max_rank,
  )
  optimize_rank_order(
    optimized_rank_node_ids_by_rank, max_rank, predecessors_by_node_id, successors_by_node_id,
    order_index_by_node_id,
  )
  maybe_refine_rank_order_by_swaps(
    optimized_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
    node_count, edge_count,
  )
  optimized_rank_node_ids_by_rank
}

///|
fn rank_order_crossing_score(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Int {
  layered_crossing_count(
    rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
}

///|
fn select_lower_crossing_rank_order(
  base_rank_node_ids_by_rank : Map[Int, Array[String]],
  alternate_rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  rank_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
) -> Map[Int, Array[String]] {
  let base_score = rank_order_crossing_score(
    base_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  let alternate_score = rank_order_crossing_score(
    alternate_rank_node_ids_by_rank, max_rank, rank_by_node_id, successors_by_node_id,
  )
  if alternate_score < base_score {
    alternate_rank_node_ids_by_rank
  } else {
    base_rank_node_ids_by_rank
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

///|
priv enum ElkLayeredRankSeedStrategy {
  LegacyLaneSeed
  NativeFeedback
}

///|
priv struct ElkLayeredRankSeedState {
  rank_by_node_id : Map[String, Int]
  max_rank : Int
  lane_by_node_id : Map[String, Int]
  order_index_by_node_id : Map[String, Int]
  successors_by_node_id : Map[String, Array[String]]
  predecessors_by_node_id : Map[String, Array[String]]
}

///|
fn select_elk_layered_rank_seed_strategy(
  graph : MermaidGraph,
) -> ElkLayeredRankSeedStrategy {
  if graph.nodes.length() > 16 || graph.edges.length() > 30 {
    LegacyLaneSeed
  } else {
    NativeFeedback
  }
}

///|
fn build_legacy_lane_rank_seed_state(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  subgraph_entry_by_id : Map[String, String],
  subgraph_exit_by_id : Map[String, String],
  nodes_in_order : Array[MermaidNode],
  node_ids_in_order : Array[String],
  base_order_index_by_node_id : Map[String, Int],
  horizontal : Bool,
  compact_fanin : Bool,
) -> ElkLayeredRankSeedState {
  let legacy_lane_state = @layout_engine_graph_lane_core.compute_legacy_lane_state(
    graph, nodes_in_order, false, false, horizontal, compact_fanin, false, false,
  )
  let rank_by_node_id = legacy_lane_state.flow_rank_by_node_id()
  let max_rank = legacy_lane_state.flow_max_rank()
  let lane_by_node_id = legacy_lane_state.flow_lane_by_node_id()
  let order_index_by_node_id = base_order_index_by_node_id
  let (successors_by_node_id, predecessors_by_node_id) = build_layered_neighbor_state_from_rank_seed(
    graph, use_subgraph_redirects, subgraph_entry_by_id, subgraph_exit_by_id, node_ids_in_order,
    rank_by_node_id, order_index_by_node_id,
  )
  {
    rank_by_node_id,
    max_rank,
    lane_by_node_id,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  }
}

///|
fn build_native_feedback_rank_seed_state(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  subgraph_entry_by_id : Map[String, String],
  subgraph_exit_by_id : Map[String, String],
  nodes_in_order : Array[MermaidNode],
) -> ElkLayeredRankSeedState {
  let (
    rank_by_node_id,
    max_rank,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  ) = build_layered_rank_state(
    graph, use_subgraph_redirects, subgraph_entry_by_id, subgraph_exit_by_id, nodes_in_order,
  )
  {
    rank_by_node_id,
    max_rank,
    lane_by_node_id: order_index_by_node_id,
    order_index_by_node_id,
    successors_by_node_id,
    predecessors_by_node_id,
  }
}

///|
fn build_elk_layered_rank_seed_state(
  graph : MermaidGraph,
  strategy : ElkLayeredRankSeedStrategy,
  use_subgraph_redirects : Bool,
  subgraph_entry_by_id : Map[String, String],
  subgraph_exit_by_id : Map[String, String],
  nodes_in_order : Array[MermaidNode],
  node_ids_in_order : Array[String],
  base_order_index_by_node_id : Map[String, Int],
  horizontal : Bool,
  compact_fanin : Bool,
) -> ElkLayeredRankSeedState {
  match strategy {
    LegacyLaneSeed =>
      build_legacy_lane_rank_seed_state(
        graph, use_subgraph_redirects, subgraph_entry_by_id, subgraph_exit_by_id,
        nodes_in_order, node_ids_in_order, base_order_index_by_node_id, horizontal,
        compact_fanin,
      )
    NativeFeedback =>
      build_native_feedback_rank_seed_state(
        graph, use_subgraph_redirects, subgraph_entry_by_id, subgraph_exit_by_id,
        nodes_in_order,
      )
  }
}

///|
priv enum ElkLayeredRankOrderStrategy {
  SeedOrderOnly
  OptimizedSeedOrder
  OptimizedSeedWithVirtualCandidate
}

///|
fn select_elk_layered_rank_order_strategy(
  graph : MermaidGraph,
  rank_seed_strategy : ElkLayeredRankSeedStrategy,
) -> ElkLayeredRankOrderStrategy {
  if rank_seed_strategy is LegacyLaneSeed {
    SeedOrderOnly
  } else if graph.nodes.length() <= 16 && graph.edges.length() <= 30 {
    OptimizedSeedWithVirtualCandidate
  } else {
    OptimizedSeedOrder
  }
}

///|
priv enum ElkLayeredMinorPlacementStrategy {
  LaneSeeded
  RelaxedNeighbor
}

///|
fn select_elk_layered_minor_placement_strategy(
  rank_seed_strategy : ElkLayeredRankSeedStrategy,
) -> ElkLayeredMinorPlacementStrategy {
  if rank_seed_strategy is LegacyLaneSeed {
    LaneSeeded
  } else {
    RelaxedNeighbor
  }
}

///|
fn build_minor_coord_by_strategy(
  strategy : ElkLayeredMinorPlacementStrategy,
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  lane_by_node_id : Map[String, Int],
  padding : Int,
  minor_step : Int,
  max_rank_minor_span : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  horizontal : Bool,
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
) -> Map[String, Int] {
  match strategy {
    LaneSeeded =>
      build_minor_coord_by_lane_seed(
        rank_node_ids_by_rank, max_rank, lane_by_node_id, padding, minor_step,
      )
    RelaxedNeighbor =>
      build_minor_coord_by_node_id(
        rank_node_ids_by_rank, max_rank, padding, minor_step, max_rank_minor_span,
        predecessors_by_node_id, successors_by_node_id, horizontal, width_by_node_id,
        height_by_node_id,
      )
  }
}

///|
fn build_rank_node_ids_by_rank_for_order_strategy(
  strategy : ElkLayeredRankOrderStrategy,
  graph : MermaidGraph,
  base_rank_node_ids_by_rank : Map[Int, Array[String]],
  rank_by_node_id : Map[String, Int],
  max_rank : Int,
  order_index_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
  predecessors_by_node_id : Map[String, Array[String]],
) -> Map[Int, Array[String]] {
  let optimized_base_rank_node_ids_by_rank = build_optimized_rank_node_ids_by_rank(
    base_rank_node_ids_by_rank,
    max_rank,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    rank_by_node_id,
    rank_by_node_id.length(),
    graph.edges.length(),
  )
  match strategy {
    SeedOrderOnly => base_rank_node_ids_by_rank
    OptimizedSeedOrder => optimized_base_rank_node_ids_by_rank
    OptimizedSeedWithVirtualCandidate => {
      let virtual_ordering_state = build_virtual_ordering_state(
        base_rank_node_ids_by_rank, rank_by_node_id, max_rank, order_index_by_node_id,
        successors_by_node_id,
      )
      let optimized_virtual_rank_node_ids_by_rank = build_optimized_rank_node_ids_by_rank(
        virtual_ordering_state.rank_node_ids_by_rank,
        max_rank,
        virtual_ordering_state.predecessors_by_node_id,
        virtual_ordering_state.successors_by_node_id,
        virtual_ordering_state.order_index_by_node_id,
        virtual_ordering_state.rank_by_node_id,
        virtual_ordering_state.rank_by_node_id.length(),
        graph.edges.length(),
      )
      let real_virtual_rank_node_ids_by_rank = filter_real_rank_node_ids_by_rank(
        optimized_virtual_rank_node_ids_by_rank,
        max_rank,
        virtual_ordering_state.virtual_by_node_id,
      )
      select_lower_crossing_rank_order(
        optimized_base_rank_node_ids_by_rank, real_virtual_rank_node_ids_by_rank,
        max_rank, rank_by_node_id, successors_by_node_id,
      )
    }
  }
}

///|
fn rank_seed_order_crossing_score(
  graph : MermaidGraph,
  rank_seed_strategy : ElkLayeredRankSeedStrategy,
  rank_seed_state : ElkLayeredRankSeedState,
  nodes_in_order : Array[MermaidNode],
  base_order_index_by_node_id : Map[String, Int],
) -> Int {
  let rank_order_strategy = select_elk_layered_rank_order_strategy(
    graph, rank_seed_strategy,
  )
  let base_rank_node_ids_by_rank = build_rank_node_ids_by_lane(
    nodes_in_order,
    rank_seed_state.rank_by_node_id,
    rank_seed_state.lane_by_node_id,
    base_order_index_by_node_id,
    rank_seed_state.max_rank,
  )
  let rank_node_ids_by_rank = build_rank_node_ids_by_rank_for_order_strategy(
    rank_order_strategy,
    graph,
    base_rank_node_ids_by_rank,
    rank_seed_state.rank_by_node_id,
    rank_seed_state.max_rank,
    rank_seed_state.order_index_by_node_id,
    rank_seed_state.successors_by_node_id,
    rank_seed_state.predecessors_by_node_id,
  )
  rank_order_crossing_score(
    rank_node_ids_by_rank,
    rank_seed_state.max_rank,
    rank_seed_state.rank_by_node_id,
    rank_seed_state.successors_by_node_id,
  )
}

///|
fn select_large_graph_rank_seed_state_by_score(
  graph : MermaidGraph,
  legacy_state : ElkLayeredRankSeedState,
  native_state : ElkLayeredRankSeedState,
  nodes_in_order : Array[MermaidNode],
  base_order_index_by_node_id : Map[String, Int],
) -> (ElkLayeredRankSeedStrategy, ElkLayeredRankSeedState) {
  let legacy_score = rank_seed_order_crossing_score(
    graph,
    LegacyLaneSeed,
    legacy_state,
    nodes_in_order,
    base_order_index_by_node_id,
  )
  let native_score = rank_seed_order_crossing_score(
    graph,
    NativeFeedback,
    native_state,
    nodes_in_order,
    base_order_index_by_node_id,
  )
  if native_score < legacy_score {
    (NativeFeedback, native_state)
  } else {
    (LegacyLaneSeed, legacy_state)
  }
}

///|
/// Runs the ELK layered flow pipeline for non-state flowcharts.
fn run_elk_layered_flow_backend(
  request : GraphLayoutBackendRequest,
  routing_policy : GraphBackendRoutingPolicy,
) -> GraphLayoutBackendResult {
  let setup_state = run_elk_layered_setup_phase(request)
  let graph = setup_state.graph
  let options = setup_state.options
  let use_subgraph_redirects = setup_state.use_subgraph_redirects
  let subgraph_entry_by_id = setup_state.subgraph_entry_by_id
  let subgraph_exit_by_id = setup_state.subgraph_exit_by_id
  let nodes_in_order = setup_state.nodes_in_order
  let horizontal = setup_state.horizontal
  let reverse = setup_state.reverse
  let base_order_index_by_node_id = setup_state.base_order_index_by_node_id
  let node_ids_in_order = setup_state.node_ids_in_order
  let default_rank_seed_strategy = select_elk_layered_rank_seed_strategy(graph)
  let (rank_seed_strategy, rank_seed_state) = if default_rank_seed_strategy
    is LegacyLaneSeed {
    let legacy_state = build_elk_layered_rank_seed_state(
      graph,
      LegacyLaneSeed,
      use_subgraph_redirects,
      subgraph_entry_by_id,
      subgraph_exit_by_id,
      nodes_in_order,
      node_ids_in_order,
      base_order_index_by_node_id,
      horizontal,
      setup_state.compact_fanin,
    )
    let native_state = build_elk_layered_rank_seed_state(
      graph,
      NativeFeedback,
      use_subgraph_redirects,
      subgraph_entry_by_id,
      subgraph_exit_by_id,
      nodes_in_order,
      node_ids_in_order,
      base_order_index_by_node_id,
      horizontal,
      setup_state.compact_fanin,
    )
    select_large_graph_rank_seed_state_by_score(
      graph, legacy_state, native_state, nodes_in_order, base_order_index_by_node_id,
    )
  } else {
    (
      NativeFeedback,
      build_elk_layered_rank_seed_state(
        graph,
        NativeFeedback,
        use_subgraph_redirects,
        subgraph_entry_by_id,
        subgraph_exit_by_id,
        nodes_in_order,
        node_ids_in_order,
        base_order_index_by_node_id,
        horizontal,
        setup_state.compact_fanin,
      ),
    )
  }
  let rank_by_node_id = rank_seed_state.rank_by_node_id
  let max_rank = rank_seed_state.max_rank
  let lane_by_node_id = rank_seed_state.lane_by_node_id
  let order_index_by_node_id = rank_seed_state.order_index_by_node_id
  let successors_by_node_id = rank_seed_state.successors_by_node_id
  let predecessors_by_node_id = rank_seed_state.predecessors_by_node_id
  let rank_order_strategy = select_elk_layered_rank_order_strategy(
    graph, rank_seed_strategy,
  )
  let minor_placement_strategy = select_elk_layered_minor_placement_strategy(
    rank_seed_strategy,
  )
  let base_rank_node_ids_by_rank = build_rank_node_ids_by_lane(
    nodes_in_order, rank_by_node_id, lane_by_node_id, base_order_index_by_node_id,
    max_rank,
  )
  let rank_node_ids_by_rank = build_rank_node_ids_by_rank_for_order_strategy(
    rank_order_strategy, graph, base_rank_node_ids_by_rank, rank_by_node_id, max_rank,
    order_index_by_node_id, successors_by_node_id, predecessors_by_node_id,
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
  let minor_coord_by_node_id = build_minor_coord_by_strategy(
    minor_placement_strategy, rank_node_ids_by_rank, max_rank, lane_by_node_id, padding,
    minor_step, max_rank_minor_span, predecessors_by_node_id, successors_by_node_id,
    horizontal, width_by_node_id, height_by_node_id,
  )
  let rank_pair_label_major_gap = build_rank_pair_label_major_gap(
    graph, use_subgraph_redirects, subgraph_entry_by_id, subgraph_exit_by_id, rank_by_node_id,
    horizontal,
  )
  let major_center_by_rank = build_major_center_by_rank(
    max_rank, reverse, padding, base_major_step, rank_pair_label_major_gap,
  )
  let (x_by_node_id, y_by_node_id) = build_axis_coords_by_node_id(
    rank_node_ids_by_rank, max_rank, major_center_by_rank, minor_coord_by_node_id,
    padding, horizontal,
  )
  let (positioned_nodes, positioned_by_id) = build_positioned_nodes_from_axis_coords(
    graph, nodes_in_order, width_by_node_id, height_by_node_id, x_by_node_id, y_by_node_id,
    padding,
  )
  let node_horizontal_by_id = build_node_horizontal_by_id(
    positioned_nodes, horizontal,
  )
  let (max_right, max_bottom) = positioned_nodes_layout_extent(
    positioned_nodes, padding,
  )
  let positioned_graph = finalize_elk_layered_positioned_graph(
    graph, padding, horizontal, reverse, node_spacing, layer_spacing, use_subgraph_redirects,
    subgraph_exit_by_id, subgraph_entry_by_id, routing_policy, positioned_nodes,
    positioned_by_id, node_horizontal_by_id, max_right, max_bottom,
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
