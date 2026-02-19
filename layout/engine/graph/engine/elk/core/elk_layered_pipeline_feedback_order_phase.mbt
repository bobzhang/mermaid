///|
priv struct FeedbackGreedyOrientationState {
  order_index_by_node_id : Map[String, Int]
  oriented_edges : Array[(String, String)]
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
fn pop_next_unmarked_node(
  node_ids : Array[String],
  mark_by_node_id : Map[String, Int],
) -> String? {
  while node_ids.length() > 0 {
    let node_id = node_ids[0]
    let _ = node_ids.remove(0)
    if option_int_or(mark_by_node_id.get(node_id), 0) == 0 {
      return Some(node_id)
    }
  }
  None
}

///|
let java_random_multiplier : UInt64 = 25214903917

///|
let java_random_addend : UInt64 = 11

///|
let java_random_mask : UInt64 = 0xffffffffffff

///|
fn java_random_state_from_seed(seed : Int) -> UInt64 {
  (seed.to_uint64() ^ 0x5deece66d) & java_random_mask
}

///|
fn java_random_next_bits(state : UInt64, bits : Int) -> (UInt64, Int) {
  let next_state = (state * java_random_multiplier + java_random_addend) &
    java_random_mask
  let value = (next_state >> (48 - bits)).to_int()
  (next_state, value)
}

///|
fn java_random_next_int(state : UInt64, bound : Int) -> (UInt64, Int) {
  if bound <= 0 {
    return (state, 0)
  }
  let bound_u = bound.to_uint64()
  if (bound_u & (bound_u - 1)) == 0 {
    let (next_state, bits) = java_random_next_bits(state, 31)
    let value = ((bound.to_int64() * bits.to_int64()) >> 31).to_int()
    return (next_state, value)
  }
  let mut next_state = state
  while true {
    let (candidate_state, bits) = java_random_next_bits(next_state, 31)
    next_state = candidate_state
    let value = bits % bound
    if bits - value + (bound - 1) >= 0 {
      return (next_state, value)
    }
  }
  (next_state, 0)
}

///|
fn choose_feedback_break_node_by_outflow(
  node_ids_in_order : Array[String],
  mark_by_node_id : Map[String, Int],
  indegree_by_node_id : Map[String, Int],
  outdegree_by_node_id : Map[String, Int],
  use_indegree_tie_sort : Bool,
  prefer_forward_order_on_tie : Bool,
  random_state : UInt64,
) -> (String?, UInt64) {
  let mut max_outflow = 0
  let mut has_candidate = false
  let mut break_candidates : Array[String] = []
  let node_order_index_by_node_id = build_order_index_by_id(node_ids_in_order)
  let mut min_candidate_indegree = 0
  let mut max_candidate_indegree = 0
  let mut has_indegree_range = false
  for node_id in node_ids_in_order {
    if option_int_or(mark_by_node_id.get(node_id), 0) != 0 {
      continue
    }
    let outflow = option_int_or(outdegree_by_node_id.get(node_id), 0) -
      option_int_or(indegree_by_node_id.get(node_id), 0)
    if !has_candidate || outflow > max_outflow {
      break_candidates = [node_id]
      max_outflow = outflow
      has_candidate = true
      let indegree = option_int_or(indegree_by_node_id.get(node_id), 0)
      min_candidate_indegree = indegree
      max_candidate_indegree = indegree
      has_indegree_range = true
    } else if outflow == max_outflow {
      break_candidates.push(node_id)
      let indegree = option_int_or(indegree_by_node_id.get(node_id), 0)
      if !has_indegree_range || indegree < min_candidate_indegree {
        min_candidate_indegree = indegree
      }
      if !has_indegree_range || indegree > max_candidate_indegree {
        max_candidate_indegree = indegree
      }
      has_indegree_range = true
    }
  }
  if break_candidates.length() == 0 {
    return (None, random_state)
  }
  if use_indegree_tie_sort && max_candidate_indegree != min_candidate_indegree {
    break_candidates.sort_by((left, right) => {
      let left_indegree = option_int_or(indegree_by_node_id.get(left), 0)
      let right_indegree = option_int_or(indegree_by_node_id.get(right), 0)
      if left_indegree != right_indegree {
        right_indegree.compare(left_indegree)
      } else if prefer_forward_order_on_tie {
        compare_node_ids_by_order(left, right, node_order_index_by_node_id)
      } else {
        compare_node_ids_by_order(right, left, node_order_index_by_node_id)
      }
    })
  }
  let (next_state, selected_index) = java_random_next_int(
    random_state,
    break_candidates.length(),
  )
  (Some(break_candidates[selected_index]), next_state)
}

///|
fn build_feedback_greedy_neighbors(
  node_ids : Array[String],
  resolved_edges : Array[(String, String)],
) -> (
  Array[(String, String)],
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Int],
  Map[String, Int],
) {
  let visible_node_id_set : Map[String, Bool] = {}
  let successors_by_node_id : Map[String, Array[String]] = {}
  let predecessors_by_node_id : Map[String, Array[String]] = {}
  let indegree_by_node_id : Map[String, Int] = {}
  let outdegree_by_node_id : Map[String, Int] = {}
  for node_id in node_ids {
    visible_node_id_set[node_id] = true
    successors_by_node_id[node_id] = []
    predecessors_by_node_id[node_id] = []
    indegree_by_node_id[node_id] = 0
    outdegree_by_node_id[node_id] = 0
  }

  let normalized_edges : Array[(String, String)] = []
  for edge in resolved_edges {
    let (source_id, target_id) = edge
    if source_id == target_id {
      continue
    }
    if !visible_node_id_set.contains(source_id) ||
      !visible_node_id_set.contains(target_id) {
      continue
    }
    normalized_edges.push((source_id, target_id))
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
    match successors_by_node_id.get(source_id) {
      Some(successors) => successors.push(target_id)
      None => ()
    }
    match predecessors_by_node_id.get(target_id) {
      Some(predecessors) => predecessors.push(source_id)
      None => ()
    }
  }

  (
    normalized_edges, successors_by_node_id, predecessors_by_node_id, indegree_by_node_id,
    outdegree_by_node_id,
  )
}

///|
fn update_feedback_greedy_neighbors_after_mark(
  node_id : String,
  mark_by_node_id : Map[String, Int],
  indegree_by_node_id : Map[String, Int],
  outdegree_by_node_id : Map[String, Int],
  successors_by_node_id : Map[String, Array[String]],
  predecessors_by_node_id : Map[String, Array[String]],
  sources : Array[String],
  sinks : Array[String],
) -> Unit {
  match successors_by_node_id.get(node_id) {
    Some(successors) =>
      for successor_id in successors {
        if option_int_or(mark_by_node_id.get(successor_id), 0) != 0 {
          continue
        }
        indegree_by_node_id[successor_id] = option_int_or(
            indegree_by_node_id.get(successor_id),
            0,
          ) -
          1
        if option_int_or(indegree_by_node_id.get(successor_id), 0) <= 0 &&
          option_int_or(outdegree_by_node_id.get(successor_id), 0) > 0 {
          sources.push(successor_id)
        }
      }
    None => ()
  }

  match predecessors_by_node_id.get(node_id) {
    Some(predecessors) =>
      for predecessor_id in predecessors {
        if option_int_or(mark_by_node_id.get(predecessor_id), 0) != 0 {
          continue
        }
        outdegree_by_node_id[predecessor_id] = option_int_or(
            outdegree_by_node_id.get(predecessor_id),
            0,
          ) -
          1
        if option_int_or(outdegree_by_node_id.get(predecessor_id), 0) <= 0 &&
          option_int_or(indegree_by_node_id.get(predecessor_id), 0) > 0 {
          sinks.push(predecessor_id)
        }
      }
    None => ()
  }
}

///|
fn shift_negative_marks_to_positive_order(
  node_ids : Array[String],
  mark_by_node_id : Map[String, Int],
) -> Unit {
  let shift_base = node_ids.length() + 1
  for node_id in node_ids {
    let mark = option_int_or(mark_by_node_id.get(node_id), 0)
    if mark < 0 {
      mark_by_node_id[node_id] = mark + shift_base
    }
  }
}

///|
fn build_oriented_edges_from_feedback_marks(
  normalized_edges : Array[(String, String)],
  mark_by_node_id : Map[String, Int],
) -> Array[(String, String)] {
  let oriented_edges : Array[(String, String)] = []
  for edge in normalized_edges {
    let (source_id, target_id) = edge
    let source_mark = option_int_or(mark_by_node_id.get(source_id), 0)
    let target_mark = option_int_or(mark_by_node_id.get(target_id), 0)
    if source_mark > target_mark {
      oriented_edges.push((target_id, source_id))
    } else {
      oriented_edges.push((source_id, target_id))
    }
  }
  oriented_edges
}

///|
fn compute_feedback_order_orientation_state(
  node_ids : Array[String],
  resolved_edges : Array[(String, String)],
  base_order_index_by_node_id : Map[String, Int],
  use_indegree_tie_sort : Bool,
  prefer_forward_order_on_tie : Bool,
) -> FeedbackGreedyOrientationState {
  let (
    normalized_edges,
    successors_by_node_id,
    predecessors_by_node_id,
    indegree_by_node_id,
    outdegree_by_node_id,
  ) = build_feedback_greedy_neighbors(node_ids, resolved_edges)

  let node_ids_in_order = node_ids.copy()
  node_ids_in_order.sort_by((left, right) => {
    compare_node_ids_by_order(left, right, base_order_index_by_node_id)
  })

  let mark_by_node_id : Map[String, Int] = {}
  let sinks : Array[String] = []
  let sources : Array[String] = []
  for node_id in node_ids_in_order {
    mark_by_node_id[node_id] = 0
    let indegree = option_int_or(indegree_by_node_id.get(node_id), 0)
    let outdegree = option_int_or(outdegree_by_node_id.get(node_id), 0)
    if outdegree == 0 {
      sinks.push(node_id)
    } else if indegree == 0 {
      sources.push(node_id)
    }
  }

  let mut next_right = -1
  let mut next_left = 1
  let mut random_state = java_random_state_from_seed(1)
  let mut unprocessed_count = node_ids_in_order.length()
  while unprocessed_count > 0 {
    while pop_next_unmarked_node(sinks, mark_by_node_id) is Some(sink_id) {
      mark_by_node_id[sink_id] = next_right
      next_right -= 1
      update_feedback_greedy_neighbors_after_mark(
        sink_id, mark_by_node_id, indegree_by_node_id, outdegree_by_node_id, successors_by_node_id,
        predecessors_by_node_id, sources, sinks,
      )
      unprocessed_count -= 1
    }

    while pop_next_unmarked_node(sources, mark_by_node_id) is Some(source_id) {
      mark_by_node_id[source_id] = next_left
      next_left += 1
      update_feedback_greedy_neighbors_after_mark(
        source_id, mark_by_node_id, indegree_by_node_id, outdegree_by_node_id, successors_by_node_id,
        predecessors_by_node_id, sources, sinks,
      )
      unprocessed_count -= 1
    }

    if unprocessed_count <= 0 {
      break
    }

    let (break_node_id, next_state) = choose_feedback_break_node_by_outflow(
      node_ids_in_order, mark_by_node_id, indegree_by_node_id, outdegree_by_node_id,
      use_indegree_tie_sort, prefer_forward_order_on_tie, random_state,
    )
    random_state = next_state
    match break_node_id {
      Some(node_id) => {
        mark_by_node_id[node_id] = next_left
        next_left += 1
        update_feedback_greedy_neighbors_after_mark(
          node_id, mark_by_node_id, indegree_by_node_id, outdegree_by_node_id, successors_by_node_id,
          predecessors_by_node_id, sources, sinks,
        )
        unprocessed_count -= 1
      }
      None => break
    }
  }

  if unprocessed_count > 0 {
    for node_id in node_ids_in_order {
      if option_int_or(mark_by_node_id.get(node_id), 0) != 0 {
        continue
      }
      mark_by_node_id[node_id] = next_left
      next_left += 1
      unprocessed_count -= 1
    }
  }

  shift_negative_marks_to_positive_order(node_ids_in_order, mark_by_node_id)

  let ordered_node_ids = node_ids_in_order.copy()
  ordered_node_ids.sort_by((left, right) => {
    let left_mark = option_int_or(mark_by_node_id.get(left), 0)
    let right_mark = option_int_or(mark_by_node_id.get(right), 0)
    if left_mark != right_mark {
      left_mark.compare(right_mark)
    } else {
      compare_node_ids_by_order(left, right, base_order_index_by_node_id)
    }
  })
  let order_index_by_node_id = build_order_index_by_id(ordered_node_ids)
  let oriented_edges = build_oriented_edges_from_feedback_marks(
    normalized_edges, mark_by_node_id,
  )
  { order_index_by_node_id, oriented_edges }
}
