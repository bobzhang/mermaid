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
