///|

///|
priv struct ElkLayeredCrossingSweepInput {
  rank_node_ids_by_rank : Map[Int, Array[String]]
  max_rank : Int
  predecessors_by_node_id : Map[String, Array[String]]
  successors_by_node_id : Map[String, Array[String]]
  order_index_by_node_id : Map[String, Int]
  preserve_current_order_on_tie : Bool
}

///|
fn build_crossing_sweep_input(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
  preserve_current_order_on_tie : Bool,
) -> ElkLayeredCrossingSweepInput {
  {
    rank_node_ids_by_rank,
    max_rank,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    preserve_current_order_on_tie,
  }
}

///|
fn crossing_preserve_current_order_on_tie(
  node_count : Int,
  edge_count : Int,
  config : ElkLayeredCrossingOptimizationConfig,
) -> Bool {
  node_count > config.preserve_order_node_threshold ||
  edge_count > config.preserve_order_edge_threshold
}

///|
fn build_crossing_sweep_input_from_phase_input(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  input : ElkLayeredCrossingPhaseInput,
  config : ElkLayeredCrossingOptimizationConfig,
) -> ElkLayeredCrossingSweepInput {
  build_crossing_sweep_input(
    rank_node_ids_by_rank,
    input.max_rank,
    input.predecessors_by_node_id,
    input.successors_by_node_id,
    input.order_index_by_node_id,
    crossing_preserve_current_order_on_tie(
      input.node_count,
      input.edge_count,
      config,
    ),
  )
}

///|
priv struct NodeNeighborOrderKey {
  has_center : Bool
  neighbor_position_sum : Int
  neighbor_position_count : Int
}

///|
fn empty_neighbor_order_key() -> NodeNeighborOrderKey {
  { has_center: false, neighbor_position_sum: 0, neighbor_position_count: 0 }
}

///|
fn node_neighbor_order_key(
  node_id : String,
  neighbor_by_node_id : Map[String, Array[String]],
  rank_position_by_node_id : Map[String, Int],
) -> NodeNeighborOrderKey {
  let mut count = 0
  let mut sum = 0
  match neighbor_by_node_id.get(node_id) {
    Some(neighbors) =>
      for neighbor_id in neighbors {
        match rank_position_by_node_id.get(neighbor_id) {
          Some(position) => {
            count += 1
            sum += position
          }
          None => ()
        }
      }
    None => ()
  }
  if count == 0 {
    empty_neighbor_order_key()
  } else {
    {
      has_center: true,
      neighbor_position_sum: sum,
      neighbor_position_count: count,
    }
  }
}

///|
fn compare_neighbor_order_key(
  left : NodeNeighborOrderKey,
  right : NodeNeighborOrderKey,
) -> Int {
  if left.has_center && right.has_center {
    let left_scaled = left.neighbor_position_sum * right.neighbor_position_count
    let right_scaled = right.neighbor_position_sum *
      left.neighbor_position_count
    left_scaled.compare(right_scaled)
  } else if left.has_center != right.has_center {
    if left.has_center {
      -1
    } else {
      1
    }
  } else {
    0
  }
}

///|
fn sort_rank_nodes_by_neighbors(
  node_ids : Array[String],
  neighbor_by_node_id : Map[String, Array[String]],
  rank_position_by_node_id : Map[String, Int],
  order_index_by_node_id : Map[String, Int],
  preserve_current_order_on_tie : Bool,
) -> Unit {
  let neighbor_key_by_node_id : Map[String, NodeNeighborOrderKey] = {}
  for node_id in node_ids {
    neighbor_key_by_node_id[node_id] = node_neighbor_order_key(
      node_id, neighbor_by_node_id, rank_position_by_node_id,
    )
  }
  node_ids.sort_by((left, right) => {
    let left_key = match neighbor_key_by_node_id.get(left) {
      Some(value) => value
      None => empty_neighbor_order_key()
    }
    let right_key = match neighbor_key_by_node_id.get(right) {
      Some(value) => value
      None => empty_neighbor_order_key()
    }
    let neighbor_order_compare = compare_neighbor_order_key(left_key, right_key)
    if neighbor_order_compare != 0 {
      neighbor_order_compare
    } else if preserve_current_order_on_tie {
      option_int_or(
        rank_position_by_node_id.get(left),
        option_int_or(order_index_by_node_id.get(left), 0),
      ).compare(
        option_int_or(
          rank_position_by_node_id.get(right),
          option_int_or(order_index_by_node_id.get(right), 0),
        ),
      )
    } else {
      option_int_or(order_index_by_node_id.get(left), 0).compare(
        option_int_or(order_index_by_node_id.get(right), 0),
      )
    }
  })
}

///|
fn optimize_rank_order_with_sweep_passes_and_kernel(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
  preserve_current_order_on_tie : Bool,
  sweep_pass_count : Int,
  sweep_kernel : ElkLayeredCrossingSweepKernel,
) -> Unit {
  optimize_rank_order_with_sweep_passes_from_input(
    build_crossing_sweep_input(
      rank_node_ids_by_rank, max_rank, predecessors_by_node_id, successors_by_node_id,
      order_index_by_node_id, preserve_current_order_on_tie,
    ),
    sweep_pass_count,
    sweep_kernel,
  )
}

///|
fn optimize_rank_order_with_sweep_passes_from_input(
  sweep_input : ElkLayeredCrossingSweepInput,
  sweep_pass_count : Int,
  sweep_kernel : ElkLayeredCrossingSweepKernel,
) -> Unit {
  if sweep_input.max_rank <= 0 {
    return
  }
  let mut pass = 0
  while pass < sweep_pass_count {
    sweep_rank_order_once_from_input_with_kernel(sweep_input, sweep_kernel)
    pass += 1
  }
}

///|
fn sweep_rank_order_once_from_input_with_kernel(
  sweep_input : ElkLayeredCrossingSweepInput,
  sweep_kernel : ElkLayeredCrossingSweepKernel,
) -> Unit {
  if sweep_input.max_rank <= 0 {
    return
  }
  match sweep_kernel {
    NeighborMeanBidirectional => {
      for rank in 1..<=sweep_input.max_rank {
        // Keep the layer-sweep state coherent: each rank update should observe
        // already-updated neighbor order from earlier ranks in the same pass.
        let forward_positions = rank_position_by_node_id(
          sweep_input.rank_node_ids_by_rank,
          sweep_input.max_rank,
        )
        match sweep_input.rank_node_ids_by_rank.get(rank) {
          Some(node_ids) =>
            sort_rank_nodes_by_neighbors(
              node_ids,
              sweep_input.predecessors_by_node_id,
              forward_positions,
              sweep_input.order_index_by_node_id,
              sweep_input.preserve_current_order_on_tie,
            )
          None => ()
        }
      }

      let mut rank = sweep_input.max_rank - 1
      while true {
        let backward_positions = rank_position_by_node_id(
          sweep_input.rank_node_ids_by_rank,
          sweep_input.max_rank,
        )
        match sweep_input.rank_node_ids_by_rank.get(rank) {
          Some(node_ids) =>
            sort_rank_nodes_by_neighbors(
              node_ids,
              sweep_input.successors_by_node_id,
              backward_positions,
              sweep_input.order_index_by_node_id,
              sweep_input.preserve_current_order_on_tie,
            )
          None => ()
        }
        if rank == 0 {
          break
        }
        rank = rank - 1
      }
    }
  }
}
