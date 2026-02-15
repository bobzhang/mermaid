///|
priv struct EdgeOp {
  symbol : String
  style : EdgeStyle
  has_arrow_start : Bool
  has_arrow_end : Bool
}

///|
priv struct FoundEdgeOp {
  op : EdgeOp
  index : Int
}

///|
fn apply_class_assignment(
  class_assignments : Map[String, String],
  node : MermaidNode,
  class_name : String?,
) -> Unit {
  match class_name {
    Some(name) => class_assignments[node.id] = name
    None => ()
  }
}

///|
fn ensure_nodes_from_entries(
  nodes : Map[String, MermaidNode],
  class_assignments : Map[String, String],
  entries : Array[(MermaidNode, String?)],
) -> Array[MermaidNode] {
  let resolved : Array[MermaidNode] = []
  for entry in entries {
    let (node, class_name) = entry
    @parser_common_engine_core.ensure_node(nodes, node)
    apply_class_assignment(class_assignments, node, class_name)
    resolved.push(node)
  }
  resolved
}

///|
fn push_unique_node_ids(
  ids : Array[String],
  nodes : Array[MermaidNode],
) -> Unit {
  for node in nodes {
    @parser_common_engine_core.push_unique_id(ids, node.id)
  }
}
