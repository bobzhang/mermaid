///|
priv struct ElkLayeredCrossingPhaseInput {
  rank_node_ids_by_rank : Map[Int, Array[String]]
  max_rank : Int
  predecessors_by_node_id : Map[String, Array[String]]
  successors_by_node_id : Map[String, Array[String]]
  order_index_by_node_id : Map[String, Int]
  rank_by_node_id : Map[String, Int]
  node_count : Int
  edge_count : Int
  ordering_edges : Array[(String, String)]
  // Reserved for future port-aware crossing objective alignment.
  port_order_slots_by_node_id : Map[String, Array[Int]]
}

///|
fn build_default_port_order_slots_by_node_id(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
) -> Map[String, Array[Int]] {
  let port_order_slots_by_node_id : Map[String, Array[Int]] = {}
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for node_id in node_ids {
          port_order_slots_by_node_id[node_id] = []
        }
      None => ()
    }
  }
  port_order_slots_by_node_id
}

///|
fn build_crossing_ordering_edges(
  successors_by_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
) -> Array[(String, String)] {
  let ordering_edges : Array[(String, String)] = []
  let source_ids : Array[String] = []
  for source_id, _ in successors_by_node_id {
    source_ids.push(source_id)
  }
  source_ids.sort_by((left, right) => {
    compare_node_ids_by_order(left, right, order_index_by_node_id)
  })
  for source_id in source_ids {
    match successors_by_node_id.get(source_id) {
      Some(target_ids) =>
        for target_id in target_ids {
          ordering_edges.push((source_id, target_id))
        }
      None => ()
    }
  }
  ordering_edges
}

///|
fn build_crossing_in_layer_successors_by_node_id(
  ordering_edges : Array[(String, String)],
  rank_by_node_id : Map[String, Int],
) -> Map[String, Array[String]] {
  let in_layer_successors_by_node_id : Map[String, Array[String]] = {}
  let seen_edge_by_key : Map[String, Bool] = {}
  for edge in ordering_edges {
    let source_id = edge.0
    let target_id = edge.1
    if source_id == target_id {
      continue
    }
    let source_rank = option_int_or(rank_by_node_id.get(source_id), -1)
    let target_rank = option_int_or(rank_by_node_id.get(target_id), -2)
    if source_rank != target_rank {
      continue
    }
    let edge_key = "\{source_id}\n\{target_id}"
    if seen_edge_by_key.contains(edge_key) {
      continue
    }
    seen_edge_by_key[edge_key] = true
    match in_layer_successors_by_node_id.get(source_id) {
      Some(successors) => successors.push(target_id)
      None => in_layer_successors_by_node_id[source_id] = [target_id]
    }
  }
  in_layer_successors_by_node_id
}

///|
fn build_crossing_phase_input(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
  rank_by_node_id : Map[String, Int],
  node_count : Int,
  edge_count : Int,
) -> ElkLayeredCrossingPhaseInput {
  {
    rank_node_ids_by_rank,
    max_rank,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    rank_by_node_id,
    node_count,
    edge_count,
    ordering_edges: build_crossing_ordering_edges(
      successors_by_node_id, order_index_by_node_id,
    ),
    port_order_slots_by_node_id: build_default_port_order_slots_by_node_id(
      rank_node_ids_by_rank, max_rank,
    ),
  }
}
