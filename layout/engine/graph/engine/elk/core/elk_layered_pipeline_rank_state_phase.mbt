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
