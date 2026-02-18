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
test "elk layered feedback orientation uses root-distance before order for back edges" {
  let node_ids = ["SRC", "SNK", "M3"]
  let resolved_edges = [("SRC", "M3"), ("M3", "SNK"), ("SNK", "M3")]
  let order_index_by_node_id : Map[String, Int] = {
    "SRC": 0,
    "SNK": 1,
    "M3": 2,
  }
  let oriented_edges = orient_edges_by_feedback_order(
    node_ids, resolved_edges, order_index_by_node_id,
  )
  assert_eq(wb_count_oriented_edge(oriented_edges, "M3", "SNK"), 2)
  assert_eq(wb_count_oriented_edge(oriented_edges, "SNK", "M3"), 0)
}

///|
test "elk layered feedback orientation falls back to order priority inside same root-distance tier" {
  let node_ids = ["A", "B", "C"]
  let resolved_edges = [("A", "B"), ("B", "C"), ("C", "A")]
  let order_index_by_node_id : Map[String, Int] = { "A": 0, "B": 1, "C": 2 }
  let oriented_edges = orient_edges_by_feedback_order(
    node_ids, resolved_edges, order_index_by_node_id,
  )
  assert_eq(wb_count_oriented_edge(oriented_edges, "A", "B"), 1)
  assert_eq(wb_count_oriented_edge(oriented_edges, "B", "C"), 1)
  assert_eq(wb_count_oriented_edge(oriented_edges, "A", "C"), 1)
}

///|
test "elk layered feedback root-distance builder follows forward reachability from roots" {
  let node_ids = ["SRC", "A", "B"]
  let resolved_edges = [("SRC", "A"), ("A", "B"), ("B", "A")]
  let order_index_by_node_id : Map[String, Int] = { "SRC": 0, "A": 1, "B": 2 }
  let root_distance_by_node_id = build_root_distance_by_node_id(
    node_ids, resolved_edges, order_index_by_node_id,
  )
  assert_eq(option_int_or(root_distance_by_node_id.get("SRC"), -1), 0)
  assert_eq(option_int_or(root_distance_by_node_id.get("A"), -1), 1)
  assert_eq(option_int_or(root_distance_by_node_id.get("B"), -1), 2)
}
