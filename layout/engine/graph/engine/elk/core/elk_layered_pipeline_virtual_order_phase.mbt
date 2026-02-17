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
