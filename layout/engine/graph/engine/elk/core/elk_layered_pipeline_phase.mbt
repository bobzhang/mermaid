///|
fn option_int_or(value : Int?, fallback : Int) -> Int {
  @layout_engine_graph_internal_core.option_int_or(value, fallback)
}

///|
fn option_bool_or(value : Bool?, fallback : Bool) -> Bool {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
fn node_is_active(
  active_by_node_id : Map[String, Bool],
  node_id : String,
) -> Bool {
  option_bool_or(active_by_node_id.get(node_id), false)
}

///|
fn resolve_edge_endpoint_id(
  node_id : String,
  use_subgraph_redirects : Bool,
  redirects : Map[String, String],
) -> String {
  if use_subgraph_redirects {
    match redirects.get(node_id) {
      Some(found) => found
      None => node_id
    }
  } else {
    node_id
  }
}

///|
fn merge_style(
  target : Map[String, String],
  style : Map[String, String]?,
) -> Unit {
  match style {
    Some(found) =>
      for entry in found.to_array() {
        let (key, value) = entry
        target[key] = value
      }
    None => ()
  }
}

///|
fn resolve_inline_style(
  graph : MermaidGraph,
  node_id : String,
) -> Map[String, String]? {
  let resolved : Map[String, String] = {}
  let class_style = match graph.class_assignments.get(node_id) {
    Some(class_name) => graph.class_defs.get(class_name)
    None => None
  }
  merge_style(resolved, class_style)
  merge_style(resolved, graph.node_styles.get(node_id))
  if resolved.length() == 0 {
    None
  } else {
    Some(resolved)
  }
}

///|
fn build_order_index_by_node_id(
  nodes_in_order : Array[MermaidNode],
) -> Map[String, Int] {
  let order_index_by_node_id : Map[String, Int] = {}
  for i, node in nodes_in_order {
    order_index_by_node_id[node.id] = i
  }
  order_index_by_node_id
}

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
