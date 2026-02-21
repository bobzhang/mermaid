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
priv struct NodeEdgeSlotOrderKey {
  has_center : Bool
  edge_slot_sum : Double
  edge_slot_count : Int
}

///|
fn empty_node_edge_slot_order_key() -> NodeEdgeSlotOrderKey {
  { has_center: false, edge_slot_sum: 0.0, edge_slot_count: 0 }
}

///|
fn build_node_id_set(node_ids : Array[String]) -> Map[String, Bool] {
  let node_id_set : Map[String, Bool] = {}
  for node_id in node_ids {
    node_id_set[node_id] = true
  }
  node_id_set
}

///|
fn edge_slot_offset_within_fixed_node(
  edge_index : Int,
  edge_count : Int,
  descending_in_fixed_node : Bool,
) -> Double {
  if edge_count <= 0 {
    0.0
  } else if descending_in_fixed_node {
    (edge_count - edge_index).to_double() / (edge_count + 1).to_double()
  } else {
    (edge_index + 1).to_double() / (edge_count + 1).to_double()
  }
}

///|
fn collect_connected_free_nodes(
  fixed_node_id : String,
  connected_node_ids_by_fixed_node_id : Map[String, Array[String]],
  free_node_id_set : Map[String, Bool],
) -> Array[String] {
  let connected_free_node_ids : Array[String] = []
  match connected_node_ids_by_fixed_node_id.get(fixed_node_id) {
    Some(connected_node_ids) =>
      for node_id in connected_node_ids {
        if option_bool_or(free_node_id_set.get(node_id), false) {
          connected_free_node_ids.push(node_id)
        }
      }
    None => ()
  }
  connected_free_node_ids
}

///|
fn compare_node_edge_slot_order_key(
  left : NodeEdgeSlotOrderKey,
  right : NodeEdgeSlotOrderKey,
) -> Int {
  if left.has_center && right.has_center {
    (left.edge_slot_sum / left.edge_slot_count.to_double()).compare(
      right.edge_slot_sum / right.edge_slot_count.to_double(),
    )
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
fn sort_rank_nodes_by_fixed_layer_edge_slots(
  free_node_ids : Array[String],
  fixed_node_ids : Array[String],
  connected_node_ids_by_fixed_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
  preserve_current_order_on_tie : Bool,
  descending_in_fixed_node : Bool,
) -> Bool {
  let original_free_node_ids = free_node_ids.copy()
  let free_rank_position_by_node_id : Map[String, Int] = {}
  for index in 0..<free_node_ids.length() {
    free_rank_position_by_node_id[free_node_ids[index]] = index
  }
  let free_node_id_set = build_node_id_set(free_node_ids)
  let edge_slot_key_by_node_id : Map[String, NodeEdgeSlotOrderKey] = {}
  for node_id in free_node_ids {
    edge_slot_key_by_node_id[node_id] = empty_node_edge_slot_order_key()
  }
  for fixed_index, fixed_node_id in fixed_node_ids {
    let connected_free_node_ids = collect_connected_free_nodes(
      fixed_node_id, connected_node_ids_by_fixed_node_id, free_node_id_set,
    )
    let edge_count = connected_free_node_ids.length()
    if edge_count == 0 {
      continue
    }
    for edge_index, free_node_id in connected_free_node_ids {
      let previous_key = match edge_slot_key_by_node_id.get(free_node_id) {
        Some(value) => value
        None => empty_node_edge_slot_order_key()
      }
      edge_slot_key_by_node_id[free_node_id] = {
        has_center: true,
        edge_slot_sum: previous_key.edge_slot_sum +
        fixed_index.to_double() +
        edge_slot_offset_within_fixed_node(
          edge_index, edge_count, descending_in_fixed_node,
        ),
        edge_slot_count: previous_key.edge_slot_count + 1,
      }
    }
  }
  free_node_ids.sort_by((left, right) => {
    let left_key = match edge_slot_key_by_node_id.get(left) {
      Some(value) => value
      None => empty_node_edge_slot_order_key()
    }
    let right_key = match edge_slot_key_by_node_id.get(right) {
      Some(value) => value
      None => empty_node_edge_slot_order_key()
    }
    let compare_by_edge_slots = compare_node_edge_slot_order_key(
      left_key, right_key,
    )
    if compare_by_edge_slots != 0 {
      compare_by_edge_slots
    } else if preserve_current_order_on_tie {
      option_int_or(
        free_rank_position_by_node_id.get(left),
        option_int_or(order_index_by_node_id.get(left), 0),
      ).compare(
        option_int_or(
          free_rank_position_by_node_id.get(right),
          option_int_or(order_index_by_node_id.get(right), 0),
        ),
      )
    } else {
      option_int_or(order_index_by_node_id.get(left), 0).compare(
        option_int_or(order_index_by_node_id.get(right), 0),
      )
    }
  })
  let mut changed = false
  for index in 0..<free_node_ids.length() {
    if free_node_ids[index] != original_free_node_ids[index] {
      changed = true
      break
    }
  }
  changed
}

///|
fn sweep_rank_order_once_from_input_with_kernel(
  sweep_input : ElkLayeredCrossingSweepInput,
  sweep_kernel : ElkLayeredCrossingSweepKernel,
  forward_sweep : Bool,
) -> Bool {
  if sweep_input.max_rank <= 0 {
    return false
  }
  let mut changed = false
  match sweep_kernel {
    NeighborMeanBidirectional =>
      if forward_sweep {
        for rank in 1..<=sweep_input.max_rank {
          // Keep the layer-sweep state coherent: each rank update should observe
          // already-updated neighbor order from earlier ranks in the same pass.
          let forward_positions = rank_position_by_node_id(
            sweep_input.rank_node_ids_by_rank,
            sweep_input.max_rank,
          )
          match sweep_input.rank_node_ids_by_rank.get(rank) {
            Some(node_ids) =>
              if sort_rank_nodes_by_neighbors(
                  node_ids,
                  sweep_input.predecessors_by_node_id,
                  forward_positions,
                  sweep_input.order_index_by_node_id,
                  sweep_input.preserve_current_order_on_tie,
                ) {
                changed = true
              }
            None => ()
          }
        }
      } else {
        let mut rank = sweep_input.max_rank - 1
        while true {
          let backward_positions = rank_position_by_node_id(
            sweep_input.rank_node_ids_by_rank,
            sweep_input.max_rank,
          )
          match sweep_input.rank_node_ids_by_rank.get(rank) {
            Some(node_ids) =>
              if sort_rank_nodes_by_neighbors(
                  node_ids,
                  sweep_input.successors_by_node_id,
                  backward_positions,
                  sweep_input.order_index_by_node_id,
                  sweep_input.preserve_current_order_on_tie,
                ) {
                changed = true
              }
            None => ()
          }
          if rank == 0 {
            break
          }
          rank = rank - 1
        }
      }
    NeighborMeanEdgeSlotBidirectional =>
      if forward_sweep {
        for rank in 1..<=sweep_input.max_rank {
          match sweep_input.rank_node_ids_by_rank.get(rank - 1) {
            Some(fixed_node_ids) =>
              match sweep_input.rank_node_ids_by_rank.get(rank) {
                Some(free_node_ids) =>
                  if sort_rank_nodes_by_fixed_layer_edge_slots(
                      free_node_ids,
                      fixed_node_ids,
                      sweep_input.successors_by_node_id,
                      sweep_input.order_index_by_node_id,
                      sweep_input.preserve_current_order_on_tie,
                      false,
                    ) {
                    changed = true
                  }
                None => ()
              }
            None => ()
          }
        }
      } else {
        let mut rank = sweep_input.max_rank - 1
        while true {
          match sweep_input.rank_node_ids_by_rank.get(rank + 1) {
            Some(fixed_node_ids) =>
              match sweep_input.rank_node_ids_by_rank.get(rank) {
                Some(free_node_ids) =>
                  if sort_rank_nodes_by_fixed_layer_edge_slots(
                      free_node_ids,
                      fixed_node_ids,
                      sweep_input.predecessors_by_node_id,
                      sweep_input.order_index_by_node_id,
                      sweep_input.preserve_current_order_on_tie,
                      true,
                    ) {
                    changed = true
                  }
                None => ()
              }
            None => ()
          }
          if rank == 0 {
            break
          }
          rank = rank - 1
        }
      }
  }
  changed
}
