///|
fn adjust_neighbor_degree_after_removal(
  neighbors : Array[String]?,
  degree_by_node_id : Map[String, Int],
  active_by_node_id : Map[String, Bool],
) -> Unit {
  match neighbors {
    Some(found) =>
      for neighbor_id in found {
        if !option_bool_or(active_by_node_id.get(neighbor_id), false) {
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
    if !option_bool_or(active_by_node_id.get(node_id), false) {
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
    if !option_bool_or(active_by_node_id.get(node_id), false) {
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
        if !option_bool_or(active_by_node_id.get(node_id), false) {
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
        if !option_bool_or(active_by_node_id.get(node_id), false) {
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
fn build_feedback_neighbors_by_node_id(
  node_ids : Array[String],
  resolved_edges : Array[(String, String)],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let successors_by_node_id : Map[String, Array[String]] = {}
  let predecessors_by_node_id : Map[String, Array[String]] = {}
  for node_id in node_ids {
    successors_by_node_id[node_id] = []
    predecessors_by_node_id[node_id] = []
  }
  for edge in resolved_edges {
    let (source_id, target_id) = edge
    if !successors_by_node_id.contains(source_id) ||
      !successors_by_node_id.contains(target_id) {
      continue
    }
    match successors_by_node_id.get(source_id) {
      Some(successors) => successors.push(target_id)
      None => ()
    }
    match predecessors_by_node_id.get(target_id) {
      Some(predecessors) => predecessors.push(source_id)
      None => ()
    }
  }
  (successors_by_node_id, predecessors_by_node_id)
}

///|
fn collect_reachable_node_ids(
  start_node_id : String,
  neighbors_by_node_id : Map[String, Array[String]],
) -> Map[String, Bool] {
  let visited_by_node_id : Map[String, Bool] = {}
  if !neighbors_by_node_id.contains(start_node_id) {
    return visited_by_node_id
  }
  let queue_node_ids : Array[String] = [start_node_id]
  visited_by_node_id[start_node_id] = true
  let mut queue_head = 0
  while queue_head < queue_node_ids.length() {
    let node_id = queue_node_ids[queue_head]
    queue_head += 1
    match neighbors_by_node_id.get(node_id) {
      Some(neighbors) =>
        for neighbor_id in neighbors {
          if visited_by_node_id.contains(neighbor_id) {
            continue
          }
          visited_by_node_id[neighbor_id] = true
          queue_node_ids.push(neighbor_id)
        }
      None => ()
    }
  }
  visited_by_node_id
}

///|
fn build_scc_index_by_node_id(
  node_ids : Array[String],
  resolved_edges : Array[(String, String)],
  order_index_by_node_id : Map[String, Int],
) -> Map[String, Int] {
  let (successors_by_node_id, predecessors_by_node_id) = build_feedback_neighbors_by_node_id(
    node_ids, resolved_edges,
  )
  let ordered_node_ids : Array[String] = []
  for node_id in node_ids {
    ordered_node_ids.push(node_id)
  }
  ordered_node_ids.sort_by((left, right) => {
    compare_node_ids_by_order(left, right, order_index_by_node_id)
  })
  let assigned_by_node_id : Map[String, Bool] = {}
  let scc_index_by_node_id : Map[String, Int] = {}
  let mut next_scc_index = 0
  for node_id in ordered_node_ids {
    if option_bool_or(assigned_by_node_id.get(node_id), false) {
      continue
    }
    let forward_reachable_by_node_id = collect_reachable_node_ids(
      node_id, successors_by_node_id,
    )
    let backward_reachable_by_node_id = collect_reachable_node_ids(
      node_id, predecessors_by_node_id,
    )
    let component_node_ids : Array[String] = []
    for candidate_id in ordered_node_ids {
      if option_bool_or(assigned_by_node_id.get(candidate_id), false) {
        continue
      }
      if !forward_reachable_by_node_id.contains(candidate_id) ||
        !backward_reachable_by_node_id.contains(candidate_id) {
        continue
      }
      component_node_ids.push(candidate_id)
    }
    if component_node_ids.length() == 0 {
      component_node_ids.push(node_id)
    }
    for component_node_id in component_node_ids {
      assigned_by_node_id[component_node_id] = true
      scc_index_by_node_id[component_node_id] = next_scc_index
    }
    next_scc_index += 1
  }
  scc_index_by_node_id
}

///|
fn collect_root_node_ids_for_orientation(
  node_ids : Array[String],
  resolved_edges : Array[(String, String)],
  order_index_by_node_id : Map[String, Int],
) -> Array[String] {
  let indegree_by_node_id : Map[String, Int] = {}
  for node_id in node_ids {
    indegree_by_node_id[node_id] = 0
  }
  for edge in resolved_edges {
    let (_, target_id) = edge
    if !indegree_by_node_id.contains(target_id) {
      continue
    }
    indegree_by_node_id[target_id] = option_int_or(
        indegree_by_node_id.get(target_id),
        0,
      ) +
      1
  }

  let roots : Array[String] = []
  for node_id in node_ids {
    if option_int_or(indegree_by_node_id.get(node_id), 0) == 0 {
      roots.push(node_id)
    }
  }
  if roots.length() > 0 {
    roots.sort_by((left, right) => {
      compare_node_ids_by_order(left, right, order_index_by_node_id)
    })
    return roots
  }

  let mut has_min_indegree = false
  let mut min_indegree = 0
  for node_id in node_ids {
    let indegree = option_int_or(indegree_by_node_id.get(node_id), 0)
    if !has_min_indegree || indegree < min_indegree {
      has_min_indegree = true
      min_indegree = indegree
    }
  }
  for node_id in node_ids {
    if option_int_or(indegree_by_node_id.get(node_id), 0) == min_indegree {
      roots.push(node_id)
    }
  }
  roots.sort_by((left, right) => {
    compare_node_ids_by_order(left, right, order_index_by_node_id)
  })
  roots
}

///|
fn build_root_distance_by_node_id(
  node_ids : Array[String],
  resolved_edges : Array[(String, String)],
  order_index_by_node_id : Map[String, Int],
) -> Map[String, Int] {
  let successors_by_node_id : Map[String, Array[String]] = {}
  for node_id in node_ids {
    successors_by_node_id[node_id] = []
  }
  for edge in resolved_edges {
    let (source_id, target_id) = edge
    if !successors_by_node_id.contains(source_id) ||
      !successors_by_node_id.contains(target_id) {
      continue
    }
    match successors_by_node_id.get(source_id) {
      Some(successors) => successors.push(target_id)
      None => ()
    }
  }

  let root_node_ids = collect_root_node_ids_for_orientation(
    node_ids, resolved_edges, order_index_by_node_id,
  )
  let root_distance_by_node_id : Map[String, Int] = {}
  let queue_node_ids : Array[String] = []
  for root_id in root_node_ids {
    if root_distance_by_node_id.contains(root_id) {
      continue
    }
    root_distance_by_node_id[root_id] = 0
    queue_node_ids.push(root_id)
  }

  let mut queue_head = 0
  while queue_head < queue_node_ids.length() {
    let node_id = queue_node_ids[queue_head]
    queue_head += 1
    let node_distance = option_int_or(root_distance_by_node_id.get(node_id), 0)
    match successors_by_node_id.get(node_id) {
      Some(successors) =>
        for successor_id in successors {
          if root_distance_by_node_id.contains(successor_id) {
            continue
          }
          root_distance_by_node_id[successor_id] = node_distance + 1
          queue_node_ids.push(successor_id)
        }
      None => ()
    }
  }

  root_distance_by_node_id
}

///|
fn compare_node_ids_by_orientation_priority(
  left_node_id : String,
  right_node_id : String,
  root_distance_by_node_id : Map[String, Int],
  order_index_by_node_id : Map[String, Int],
) -> Int {
  match
    (
      root_distance_by_node_id.get(left_node_id),
      root_distance_by_node_id.get(right_node_id),
    ) {
    (Some(left_distance), Some(right_distance)) =>
      if left_distance != right_distance {
        left_distance.compare(right_distance)
      } else {
        compare_node_ids_by_order(
          left_node_id, right_node_id, order_index_by_node_id,
        )
      }
    (Some(_), None) => -1
    (None, Some(_)) => 1
    (None, None) =>
      compare_node_ids_by_order(
        left_node_id, right_node_id, order_index_by_node_id,
      )
  }
}

///|
fn orient_edges_by_feedback_order(
  node_ids : Array[String],
  resolved_edges : Array[(String, String)],
  order_index_by_node_id : Map[String, Int],
) -> Array[(String, String)] {
  let scc_index_by_node_id = build_scc_index_by_node_id(
    node_ids, resolved_edges, order_index_by_node_id,
  )
  let root_distance_by_node_id = build_root_distance_by_node_id(
    node_ids, resolved_edges, order_index_by_node_id,
  )
  let acyclic_edges : Array[(String, String)] = []
  for edge in resolved_edges {
    let (source_id, target_id) = edge
    if source_id == target_id {
      continue
    }
    if !order_index_by_node_id.contains(source_id) ||
      !order_index_by_node_id.contains(target_id) {
      continue
    }
    let source_scc_index = option_int_or(
      scc_index_by_node_id.get(source_id),
      -1,
    )
    let target_scc_index = option_int_or(
      scc_index_by_node_id.get(target_id),
      -1,
    )
    if source_scc_index >= 0 &&
      target_scc_index >= 0 &&
      source_scc_index != target_scc_index {
      acyclic_edges.push((source_id, target_id))
      continue
    }
    if compare_node_ids_by_orientation_priority(
        source_id, target_id, root_distance_by_node_id, order_index_by_node_id,
      ) <
      0 {
      acyclic_edges.push((source_id, target_id))
    } else {
      acyclic_edges.push((target_id, source_id))
    }
  }
  acyclic_edges
}

///|
