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
fn build_rank_neighbors_from_oriented_edges(
  node_ids : Array[String],
  oriented_edges : Array[(String, String)],
  rank_by_node_id : Map[String, Int],
  order_index_by_node_id : Map[String, Int],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let successors_by_node_id : Map[String, Array[String]] = {}
  let predecessors_by_node_id : Map[String, Array[String]] = {}
  for node_id in node_ids {
    successors_by_node_id[node_id] = []
    predecessors_by_node_id[node_id] = []
  }
  for edge in oriented_edges {
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
fn build_longest_path_rank_by_node_id_from_oriented_edges(
  node_ids : Array[String],
  oriented_edges : Array[(String, String)],
  order_index_by_node_id : Map[String, Int],
) -> (Map[String, Int], Int) {
  let rank_by_node_id : Map[String, Int] = {}
  let indegree_by_node_id : Map[String, Int] = {}
  let successors_by_node_id : Map[String, Array[String]] = {}
  for node_id in node_ids {
    rank_by_node_id[node_id] = 0
    indegree_by_node_id[node_id] = 0
    successors_by_node_id[node_id] = []
  }
  for edge in oriented_edges {
    let (source_id, target_id) = edge
    match successors_by_node_id.get(source_id) {
      Some(successors) => successors.push(target_id)
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
  (rank_by_node_id, max_rank)
}

///|
fn build_incident_oriented_edges_by_node_id(
  node_ids : Array[String],
  oriented_edges : Array[(String, String)],
) -> (
  Map[String, Array[(String, String)]],
  Map[String, Array[(String, String)]],
) {
  let incoming_edges_by_node_id : Map[String, Array[(String, String)]] = {}
  let outgoing_edges_by_node_id : Map[String, Array[(String, String)]] = {}
  for node_id in node_ids {
    incoming_edges_by_node_id[node_id] = []
    outgoing_edges_by_node_id[node_id] = []
  }
  for edge in oriented_edges {
    let (source_id, target_id) = edge
    if source_id == target_id {
      continue
    }
    if !incoming_edges_by_node_id.contains(source_id) ||
      !incoming_edges_by_node_id.contains(target_id) {
      continue
    }
    match outgoing_edges_by_node_id.get(source_id) {
      Some(edges) => edges.push(edge)
      None => ()
    }
    match incoming_edges_by_node_id.get(target_id) {
      Some(edges) => edges.push(edge)
      None => ()
    }
  }
  (incoming_edges_by_node_id, outgoing_edges_by_node_id)
}

///|
fn recompute_max_rank(rank_by_node_id : Map[String, Int]) -> Int {
  let mut max_rank = 0
  for _, rank in rank_by_node_id {
    if rank > max_rank {
      max_rank = rank
    }
  }
  max_rank
}

///|
fn apply_elk_network_simplex_balance(
  node_ids : Array[String],
  oriented_edges : Array[(String, String)],
  rank_by_node_id : Map[String, Int],
  max_rank : Int,
) -> (Map[String, Int], Int) {
  let (incoming_edges_by_node_id, outgoing_edges_by_node_id) = build_incident_oriented_edges_by_node_id(
    node_ids, oriented_edges,
  )
  let layer_fill_count : Array[Int] = []
  for _ in 0..<=max_rank {
    layer_fill_count.push(0)
  }
  for node_id in node_ids {
    let layer = option_int_or(rank_by_node_id.get(node_id), 0)
    if layer >= 0 && layer < layer_fill_count.length() {
      layer_fill_count[layer] = layer_fill_count[layer] + 1
    }
  }

  for node_id in node_ids {
    let incoming_edges = match incoming_edges_by_node_id.get(node_id) {
      Some(edges) => edges
      None => []
    }
    let outgoing_edges = match outgoing_edges_by_node_id.get(node_id) {
      Some(edges) => edges
      None => []
    }
    if incoming_edges.length() != outgoing_edges.length() {
      continue
    }
    let current_layer = option_int_or(rank_by_node_id.get(node_id), 0)
    if current_layer < 0 || current_layer >= layer_fill_count.length() {
      continue
    }

    let mut min_incoming_span = 2147483647
    for edge in incoming_edges {
      let (source_id, target_id) = edge
      let source_layer = option_int_or(rank_by_node_id.get(source_id), 0)
      let target_layer = option_int_or(rank_by_node_id.get(target_id), 0)
      let span = target_layer - source_layer
      if span < min_incoming_span {
        min_incoming_span = span
      }
    }
    if min_incoming_span == 2147483647 {
      min_incoming_span = -1
    }

    let mut min_outgoing_span = 2147483647
    for edge in outgoing_edges {
      let (source_id, target_id) = edge
      let source_layer = option_int_or(rank_by_node_id.get(source_id), 0)
      let target_layer = option_int_or(rank_by_node_id.get(target_id), 0)
      let span = target_layer - source_layer
      if span < min_outgoing_span {
        min_outgoing_span = span
      }
    }
    if min_outgoing_span == 2147483647 {
      min_outgoing_span = -1
    }

    let mut next_layer = current_layer
    let scan_start = current_layer - min_incoming_span + 1
    let scan_end = current_layer + min_outgoing_span
    if scan_start < scan_end {
      for candidate_layer in scan_start..<scan_end {
        if candidate_layer < 0 || candidate_layer >= layer_fill_count.length() {
          continue
        }
        if layer_fill_count[candidate_layer] < layer_fill_count[next_layer] {
          next_layer = candidate_layer
        }
      }
    }

    if layer_fill_count[next_layer] < layer_fill_count[current_layer] {
      layer_fill_count[current_layer] = layer_fill_count[current_layer] - 1
      layer_fill_count[next_layer] = layer_fill_count[next_layer] + 1
      rank_by_node_id[node_id] = next_layer
    }
  }

  (rank_by_node_id, recompute_max_rank(rank_by_node_id))
}

///|
fn build_tight_incoming_shift_closure(
  seed_node_id : String,
  node_ids : Array[String],
  incoming_edges_by_node_id : Map[String, Array[(String, String)]],
  rank_by_node_id : Map[String, Int],
) -> Array[String] {
  if !rank_by_node_id.contains(seed_node_id) {
    return []
  }
  let in_shift_set_by_node_id : Map[String, Bool] = {}
  in_shift_set_by_node_id[seed_node_id] = true
  let queue : Array[String] = [seed_node_id]
  while queue.length() > 0 {
    let node_id = queue[0]
    let _ = queue.remove(0)
    let node_rank = option_int_or(rank_by_node_id.get(node_id), 0)
    if node_rank <= 0 {
      return []
    }
    match incoming_edges_by_node_id.get(node_id) {
      Some(incoming_edges) =>
        for edge in incoming_edges {
          let (source_id, _target_id) = edge
          let source_rank = option_int_or(rank_by_node_id.get(source_id), 0)
          if node_rank - source_rank != 1 ||
            option_bool_or(in_shift_set_by_node_id.get(source_id), false) {
            continue
          }
          in_shift_set_by_node_id[source_id] = true
          queue.push(source_id)
        }
      None => ()
    }
  }
  let shift_node_ids : Array[String] = []
  for node_id in node_ids {
    if option_bool_or(in_shift_set_by_node_id.get(node_id), false) {
      shift_node_ids.push(node_id)
    }
  }
  shift_node_ids
}

///|
fn rank_shift_delta(
  shift_node_ids : Array[String],
  oriented_edges : Array[(String, String)],
) -> Int {
  let in_shift_set_by_node_id : Map[String, Bool] = {}
  for node_id in shift_node_ids {
    in_shift_set_by_node_id[node_id] = true
  }
  let mut delta = 0
  for edge in oriented_edges {
    let (source_id, target_id) = edge
    let source_in_shift_set = option_bool_or(
      in_shift_set_by_node_id.get(source_id),
      false,
    )
    let target_in_shift_set = option_bool_or(
      in_shift_set_by_node_id.get(target_id),
      false,
    )
    if !source_in_shift_set && target_in_shift_set {
      delta += 1
    } else if source_in_shift_set && !target_in_shift_set {
      delta -= 1
    }
  }
  delta
}

///|
fn rank_sum_for_node_ids(
  node_ids : Array[String],
  rank_by_node_id : Map[String, Int],
) -> Int {
  let mut rank_sum = 0
  for node_id in node_ids {
    rank_sum += option_int_or(rank_by_node_id.get(node_id), 0)
  }
  rank_sum
}

///|
fn has_incoming_cross_boundary(
  shift_node_ids : Array[String],
  oriented_edges : Array[(String, String)],
) -> Bool {
  let in_shift_set_by_node_id : Map[String, Bool] = {}
  for node_id in shift_node_ids {
    in_shift_set_by_node_id[node_id] = true
  }
  for edge in oriented_edges {
    let (source_id, target_id) = edge
    if !option_bool_or(in_shift_set_by_node_id.get(source_id), false) &&
      option_bool_or(in_shift_set_by_node_id.get(target_id), false) {
      return true
    }
  }
  false
}

///|
fn apply_elk_vertical_rank_tie_refinement(
  node_ids : Array[String],
  oriented_edges : Array[(String, String)],
  rank_by_node_id : Map[String, Int],
  max_rank : Int,
) -> (Map[String, Int], Int) {
  let (incoming_edges_by_node_id, _outgoing_edges_by_node_id) = build_incident_oriented_edges_by_node_id(
    node_ids, oriented_edges,
  )
  let max_iterations = node_ids.length() * 10
  let mut iteration = 0
  while iteration < max_iterations {
    let mut best_delta = -2147483647
    let mut best_rank_sum = -2147483647
    let best_shift_node_ids : Array[String] = []
    for seed_node_id in node_ids {
      let shift_node_ids = build_tight_incoming_shift_closure(
        seed_node_id, node_ids, incoming_edges_by_node_id, rank_by_node_id,
      )
      if shift_node_ids.length() == 0 {
        continue
      }
      let delta = rank_shift_delta(shift_node_ids, oriented_edges)
      if delta < 0 {
        continue
      }
      let rank_sum = rank_sum_for_node_ids(shift_node_ids, rank_by_node_id)
      if delta > best_delta || (delta == best_delta && rank_sum > best_rank_sum) {
        best_delta = delta
        best_rank_sum = rank_sum
        best_shift_node_ids.clear()
        for node_id in shift_node_ids {
          best_shift_node_ids.push(node_id)
        }
      }
    }
    if best_shift_node_ids.length() == 0 {
      break
    }
    if best_delta == 0 &&
      (
        !has_incoming_cross_boundary(best_shift_node_ids, oriented_edges) ||
        best_rank_sum <= 0
      ) {
      break
    }
    for node_id in best_shift_node_ids {
      let rank = option_int_or(rank_by_node_id.get(node_id), 0)
      if rank > 0 {
        rank_by_node_id[node_id] = rank - 1
      }
    }
    iteration += 1
  }
  let recomputed_max_rank = recompute_max_rank(rank_by_node_id)
  if recomputed_max_rank > max_rank {
    (rank_by_node_id, recomputed_max_rank)
  } else {
    (rank_by_node_id, max_rank.max(recomputed_max_rank))
  }
}

///|
fn build_native_feedback_rank_by_node_id(
  node_ids : Array[String],
  nodes_in_order : Array[MermaidNode],
  oriented_edges : Array[(String, String)],
  order_index_by_node_id : Map[String, Int],
  horizontal : Bool,
) -> (Map[String, Int], Int) {
  let (simplex_rank_by_node_id, simplex_max_rank, simplex_ok) = @layout_engine_graph_lane_core.collect_dagre_network_simplex_ranks_from_directed_edges(
    nodes_in_order, oriented_edges,
  )
  if simplex_ok {
    let mut all_nodes_present = true
    for node_id in node_ids {
      if !simplex_rank_by_node_id.contains(node_id) {
        all_nodes_present = false
        break
      }
    }
    if all_nodes_present {
      let (balanced_rank_by_node_id, balanced_max_rank) = apply_elk_network_simplex_balance(
        node_ids, oriented_edges, simplex_rank_by_node_id, simplex_max_rank,
      )
      if horizontal {
        return (balanced_rank_by_node_id, balanced_max_rank)
      }
      return apply_elk_vertical_rank_tie_refinement(
        node_ids, oriented_edges, balanced_rank_by_node_id, balanced_max_rank,
      )
    }
  }
  build_longest_path_rank_by_node_id_from_oriented_edges(
    node_ids, oriented_edges, order_index_by_node_id,
  )
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
  let feedback_orientation_state = compute_feedback_order_orientation_state(
    node_ids, resolved_edges, base_order_index_by_node_id,
  )
  let order_index_by_node_id = feedback_orientation_state.order_index_by_node_id
  let acyclic_edges = feedback_orientation_state.oriented_edges

  let (rank_by_node_id, max_rank) = build_native_feedback_rank_by_node_id(
    node_ids,
    nodes_in_order,
    acyclic_edges,
    order_index_by_node_id,
    @layout_engine_graph_internal_core.layout_direction_is_horizontal(
      graph.direction,
    ),
  )
  let (successors_by_node_id, predecessors_by_node_id) = build_rank_neighbors_from_oriented_edges(
    node_ids, acyclic_edges, rank_by_node_id, order_index_by_node_id,
  )
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
