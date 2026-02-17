///|
fn option_int_or(value : Int?, fallback : Int) -> Int {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
fn int_abs(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
fn collect_top_level_group_index_by_node_id(
  subgraph : MermaidSubgraph,
  top_level_group_index : Int,
  top_level_group_index_by_node_id : Map[String, Int],
) -> Unit {
  for node_id in subgraph.node_ids {
    if !top_level_group_index_by_node_id.contains(node_id) {
      top_level_group_index_by_node_id[node_id] = top_level_group_index
    }
  }
  for child in subgraph.children {
    collect_top_level_group_index_by_node_id(
      child, top_level_group_index, top_level_group_index_by_node_id,
    )
  }
}
