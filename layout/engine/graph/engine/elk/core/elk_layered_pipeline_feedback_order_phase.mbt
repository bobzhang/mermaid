///|
priv struct FeedbackGreedyOrientationState {
  order_index_by_node_id : Map[String, Int]
  oriented_edges : Array[(String, String)]
}

///|
priv struct FeedbackIncidentEdge {
  endpoint_id : String
  endpoint_is_target : Bool
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
  random_state : UInt64,
) -> (String?, UInt64) {
  let mut max_outflow = -2147483648
  let mut break_candidates : Array[String] = []
  for node_id in node_ids_in_order {
    if option_int_or(mark_by_node_id.get(node_id), 0) != 0 {
      continue
    }
    let outflow = option_int_or(outdegree_by_node_id.get(node_id), 0) -
      option_int_or(indegree_by_node_id.get(node_id), 0)
    if outflow > max_outflow {
      break_candidates = [node_id]
      max_outflow = outflow
    } else if outflow == max_outflow {
      break_candidates.push(node_id)
    }
  }
  if break_candidates.length() == 0 {
    return (None, random_state)
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
  Map[String, Array[FeedbackIncidentEdge]],
  Map[String, Int],
  Map[String, Int],
) {
  let visible_node_id_set : Map[String, Bool] = {}
  let successors_by_node_id : Map[String, Array[String]] = {}
  let predecessors_by_node_id : Map[String, Array[String]] = {}
  let incident_edges_by_node_id : Map[String, Array[FeedbackIncidentEdge]] = {}
  let indegree_by_node_id : Map[String, Int] = {}
  let outdegree_by_node_id : Map[String, Int] = {}
  for node_id in node_ids {
    visible_node_id_set[node_id] = true
    successors_by_node_id[node_id] = []
    predecessors_by_node_id[node_id] = []
    incident_edges_by_node_id[node_id] = []
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
    match incident_edges_by_node_id.get(source_id) {
      Some(incident_edges) =>
        incident_edges.push({ endpoint_id: target_id, endpoint_is_target: true })
      None => ()
    }
    match incident_edges_by_node_id.get(target_id) {
      Some(incident_edges) =>
        incident_edges.push({
          endpoint_id: source_id,
          endpoint_is_target: false,
        })
      None => ()
    }
  }

  (
    normalized_edges, successors_by_node_id, predecessors_by_node_id, incident_edges_by_node_id,
    indegree_by_node_id, outdegree_by_node_id,
  )
}

///|
fn update_feedback_greedy_neighbors_after_mark(
  node_id : String,
  mark_by_node_id : Map[String, Int],
  indegree_by_node_id : Map[String, Int],
  outdegree_by_node_id : Map[String, Int],
  incident_edges_by_node_id : Map[String, Array[FeedbackIncidentEdge]],
  sources : Array[String],
  sinks : Array[String],
) -> Unit {
  match incident_edges_by_node_id.get(node_id) {
    Some(incident_edges) =>
      for incident_edge in incident_edges {
        let endpoint_id = incident_edge.endpoint_id
        if option_int_or(mark_by_node_id.get(endpoint_id), 0) != 0 {
          continue
        }
        if incident_edge.endpoint_is_target {
          indegree_by_node_id[endpoint_id] = option_int_or(
              indegree_by_node_id.get(endpoint_id),
              0,
            ) -
            1
          if option_int_or(indegree_by_node_id.get(endpoint_id), 0) <= 0 &&
            option_int_or(outdegree_by_node_id.get(endpoint_id), 0) > 0 {
            sources.push(endpoint_id)
          }
        } else {
          outdegree_by_node_id[endpoint_id] = option_int_or(
              outdegree_by_node_id.get(endpoint_id),
              0,
            ) -
            1
          if option_int_or(outdegree_by_node_id.get(endpoint_id), 0) <= 0 &&
            option_int_or(indegree_by_node_id.get(endpoint_id), 0) > 0 {
            sinks.push(endpoint_id)
          }
        }
      }
    None => ()
  }
}

///|
fn build_feedback_component_dfs_node_ids_in_order(
  node_ids_in_order : Array[String],
  incident_edges_by_node_id : Map[String, Array[FeedbackIncidentEdge]],
) -> Array[String] {
  let visited_by_node_id : Map[String, Bool] = {}
  let reordered_node_ids : Array[String] = []

  fn dfs_visit(node_id : String) -> Unit {
    if option_bool_or(visited_by_node_id.get(node_id), false) {
      return
    }
    visited_by_node_id[node_id] = true
    reordered_node_ids.push(node_id)
    match incident_edges_by_node_id.get(node_id) {
      Some(incident_edges) =>
        for incident_edge in incident_edges {
          dfs_visit(incident_edge.endpoint_id)
        }
      None => ()
    }
  }

  for node_id in node_ids_in_order {
    dfs_visit(node_id)
  }
  reordered_node_ids
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
priv struct FeedbackOrientedEdge {
  source_id : String
  target_id : String
  model_order : Int
  reversed : Bool
}

///|
fn build_oriented_edges_from_feedback_marks(
  normalized_edges : Array[(String, String)],
  mark_by_node_id : Map[String, Int],
) -> Array[FeedbackOrientedEdge] {
  let oriented_edges : Array[FeedbackOrientedEdge] = []
  for model_order, edge in normalized_edges {
    let (source_id, target_id) = edge
    let source_mark = option_int_or(mark_by_node_id.get(source_id), 0)
    let target_mark = option_int_or(mark_by_node_id.get(target_id), 0)
    if source_mark > target_mark {
      oriented_edges.push({
        source_id: target_id,
        target_id: source_id,
        model_order,
        reversed: true,
      })
    } else {
      oriented_edges.push({ source_id, target_id, model_order, reversed: false })
    }
  }
  oriented_edges
}

///|
fn reorder_feedback_oriented_edges_by_model_order(
  oriented_edges : Array[FeedbackOrientedEdge],
  order_index_by_node_id : Map[String, Int],
) -> Array[(String, String)] {
  let edge_entries_by_source_id : Map[String, Array[FeedbackOrientedEdge]] = {}
  let source_ids : Array[String] = []
  let target_model_order_by_pair : Map[String, Int] = {}
  for edge in oriented_edges {
    let source_id = edge.source_id
    if !edge_entries_by_source_id.contains(source_id) {
      edge_entries_by_source_id[source_id] = []
      source_ids.push(source_id)
    }
    match edge_entries_by_source_id.get(source_id) {
      Some(entries) => entries.push(edge)
      None => ()
    }
    if !edge.reversed {
      let pair_key = "\{source_id}\t\{edge.target_id}"
      let previous_model_order = option_int_or(
        target_model_order_by_pair.get(pair_key),
        2147483647,
      )
      if edge.model_order < previous_model_order {
        target_model_order_by_pair[pair_key] = edge.model_order
      }
    }
  }
  source_ids.sort_by((left, right) => {
    compare_node_ids_by_order(left, right, order_index_by_node_id)
  })

  let sorted_oriented_edges : Array[(String, String)] = []
  for source_id in source_ids {
    match edge_entries_by_source_id.get(source_id) {
      Some(entries) => {
        let sorted_entries = entries.copy()
        sorted_entries.sort_by((left, right) => {
          let left_pair_key = "\{left.source_id}\t\{left.target_id}"
          let right_pair_key = "\{right.source_id}\t\{right.target_id}"
          let left_target_model_order = option_int_or(
            target_model_order_by_pair.get(left_pair_key),
            left.model_order,
          )
          let right_target_model_order = option_int_or(
            target_model_order_by_pair.get(right_pair_key),
            right.model_order,
          )
          if left_target_model_order != right_target_model_order {
            return left_target_model_order.compare(right_target_model_order)
          }
          if left.model_order != right.model_order {
            return left.model_order.compare(right.model_order)
          }
          left.target_id.compare(right.target_id)
        })
        for edge in sorted_entries {
          sorted_oriented_edges.push((edge.source_id, edge.target_id))
        }
      }
      None => ()
    }
  }
  sorted_oriented_edges
}

///|
fn compute_feedback_order_orientation_state(
  node_ids : Array[String],
  resolved_edges : Array[(String, String)],
  base_order_index_by_node_id : Map[String, Int],
) -> FeedbackGreedyOrientationState {
  let (
    normalized_edges,
    _,
    _,
    incident_edges_by_node_id,
    indegree_by_node_id,
    outdegree_by_node_id,
  ) = build_feedback_greedy_neighbors(node_ids, resolved_edges)

  let node_ids_in_order = node_ids.copy()
  node_ids_in_order.sort_by((left, right) => {
    compare_node_ids_by_order(left, right, base_order_index_by_node_id)
  })
  let traversal_node_ids_in_order = build_feedback_component_dfs_node_ids_in_order(
    node_ids_in_order, incident_edges_by_node_id,
  )

  let mark_by_node_id : Map[String, Int] = {}
  let sinks : Array[String] = []
  let sources : Array[String] = []
  for node_id in traversal_node_ids_in_order {
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
  let mut unprocessed_count = traversal_node_ids_in_order.length()
  while unprocessed_count > 0 {
    while sinks.length() > 0 {
      let sink_id = sinks[0]
      let _ = sinks.remove(0)
      mark_by_node_id[sink_id] = next_right
      next_right -= 1
      update_feedback_greedy_neighbors_after_mark(
        sink_id, mark_by_node_id, indegree_by_node_id, outdegree_by_node_id, incident_edges_by_node_id,
        sources, sinks,
      )
      unprocessed_count -= 1
    }

    while sources.length() > 0 {
      let source_id = sources[0]
      let _ = sources.remove(0)
      mark_by_node_id[source_id] = next_left
      next_left += 1
      update_feedback_greedy_neighbors_after_mark(
        source_id, mark_by_node_id, indegree_by_node_id, outdegree_by_node_id, incident_edges_by_node_id,
        sources, sinks,
      )
      unprocessed_count -= 1
    }

    if unprocessed_count <= 0 {
      break
    }

    let (break_node_id, next_state) = choose_feedback_break_node_by_outflow(
      traversal_node_ids_in_order, mark_by_node_id, indegree_by_node_id, outdegree_by_node_id,
      random_state,
    )
    random_state = next_state
    match break_node_id {
      Some(node_id) => {
        mark_by_node_id[node_id] = next_left
        next_left += 1
        update_feedback_greedy_neighbors_after_mark(
          node_id, mark_by_node_id, indegree_by_node_id, outdegree_by_node_id, incident_edges_by_node_id,
          sources, sinks,
        )
        unprocessed_count -= 1
      }
      None => break
    }
  }

  shift_negative_marks_to_positive_order(
    traversal_node_ids_in_order, mark_by_node_id,
  )

  let ordered_node_ids = traversal_node_ids_in_order.copy()
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
  {
    order_index_by_node_id,
    oriented_edges: reorder_feedback_oriented_edges_by_model_order(
      oriented_edges, order_index_by_node_id,
    ),
  }
}
