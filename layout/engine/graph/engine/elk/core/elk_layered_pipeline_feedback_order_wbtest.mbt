///|
fn wb_count_oriented_edge(
  oriented_edges : Array[(String, String)],
  source_id : String,
  target_id : String,
) -> Int {
  let mut count = 0
  for edge in oriented_edges {
    let (source, target) = edge
    if source == source_id && target == target_id {
      count += 1
    }
  }
  count
}

///|
fn wb_reversed_edge_count(
  original_edges : Array[(String, String)],
  oriented_edges : Array[(String, String)],
) -> Int {
  let oriented_edge_set : Map[String, Bool] = {}
  for edge in oriented_edges {
    let (source_id, target_id) = edge
    oriented_edge_set[source_id + "->" + target_id] = true
  }
  let mut reversed_count = 0
  for edge in original_edges {
    let (source_id, target_id) = edge
    if source_id == target_id {
      continue
    }
    let forward_key = source_id + "->" + target_id
    let backward_key = target_id + "->" + source_id
    if !option_bool_or(oriented_edge_set.get(forward_key), false) &&
      option_bool_or(oriented_edge_set.get(backward_key), false) {
      reversed_count += 1
    }
  }
  reversed_count
}

///|
fn wb_is_acyclic_orientation(
  node_ids : Array[String],
  oriented_edges : Array[(String, String)],
) -> Bool {
  let indegree_by_node_id : Map[String, Int] = {}
  let successors_by_node_id : Map[String, Array[String]] = {}
  for node_id in node_ids {
    indegree_by_node_id[node_id] = 0
    successors_by_node_id[node_id] = []
  }
  for edge in oriented_edges {
    let (source_id, target_id) = edge
    if !indegree_by_node_id.contains(source_id) ||
      !indegree_by_node_id.contains(target_id) {
      continue
    }
    indegree_by_node_id[target_id] = option_int_or(
        indegree_by_node_id.get(target_id),
        0,
      ) +
      1
    match successors_by_node_id.get(source_id) {
      Some(successors) => successors.push(target_id)
      None => ()
    }
  }
  let queue : Array[String] = []
  for node_id in node_ids {
    if option_int_or(indegree_by_node_id.get(node_id), 0) == 0 {
      queue.push(node_id)
    }
  }
  let mut processed = 0
  while queue.length() > 0 {
    let node_id = queue[0]
    let _ = queue.remove(0)
    processed += 1
    match successors_by_node_id.get(node_id) {
      Some(successors) =>
        for successor_id in successors {
          indegree_by_node_id[successor_id] = option_int_or(
              indegree_by_node_id.get(successor_id),
              0,
            ) -
            1
          if option_int_or(indegree_by_node_id.get(successor_id), 0) == 0 {
            queue.push(successor_id)
          }
        }
      None => ()
    }
  }
  processed == node_ids.length()
}

///|
test "elk layered feedback orientation preserves inter-component edge direction" {
  let node_ids = ["A", "B", "C", "D"]
  let resolved_edges = [
    ("A", "B"),
    ("B", "A"),
    ("B", "C"),
    ("C", "D"),
    ("D", "C"),
  ]
  let order_index_by_node_id : Map[String, Int] = {
    "A": 0,
    "B": 3,
    "C": 1,
    "D": 2,
  }
  let oriented_edges = compute_feedback_order_orientation_state(
      node_ids, resolved_edges, order_index_by_node_id,
    ).oriented_edges
  assert_eq(wb_count_oriented_edge(oriented_edges, "B", "C"), 1)
  assert_eq(wb_count_oriented_edge(oriented_edges, "C", "B"), 0)
}

///|
test "elk layered feedback orientation breaks 3-cycle with one reversed edge" {
  let node_ids = ["A", "B", "C"]
  let resolved_edges = [("A", "B"), ("B", "C"), ("C", "A")]
  let order_index_by_node_id : Map[String, Int] = { "A": 0, "B": 1, "C": 2 }
  let oriented_edges = compute_feedback_order_orientation_state(
      node_ids, resolved_edges, order_index_by_node_id,
    ).oriented_edges
  assert_true(wb_is_acyclic_orientation(node_ids, oriented_edges))
  assert_eq(wb_reversed_edge_count(resolved_edges, oriented_edges), 1)
}

///|
test "elk layered feedback orientation state keeps long-span kernel acyclic" {
  let node_ids = ["N0", "N1", "N2", "N3", "N4", "N5", "N6"]
  let resolved_edges = [
    ("N0", "N1"),
    ("N1", "N2"),
    ("N2", "N3"),
    ("N3", "N4"),
    ("N4", "N5"),
    ("N5", "N6"),
    ("N0", "N4"),
    ("N1", "N5"),
    ("N2", "N6"),
    ("N6", "N3"),
  ]
  let base_order_index_by_node_id : Map[String, Int] = {
    "N0": 0,
    "N1": 1,
    "N2": 2,
    "N3": 3,
    "N4": 4,
    "N5": 5,
    "N6": 6,
  }
  let orientation_state = compute_feedback_order_orientation_state(
    node_ids, resolved_edges, base_order_index_by_node_id,
  )
  assert_true(
    wb_is_acyclic_orientation(node_ids, orientation_state.oriented_edges),
  )
  assert_true(
    orientation_state.oriented_edges.length() == resolved_edges.length(),
  )
}
