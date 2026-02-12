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
fn trim_owned(s : String) -> String {
  @parser_common_engine_core.trim_owned(s)
}

///|
fn parse_direction_token_strict(token : String) -> Direction? {
  @parser_common_engine_core.parse_direction_token_strict(token)
}

///|
fn parse_node_token(raw_token : String) -> MermaidNode {
  @parser_common_engine_core.parse_node_token(raw_token)
}

///|
fn find_earliest_operator(
  line : String,
  operators : Array[EdgeOp],
) -> FoundEdgeOp? {
  let mut best : FoundEdgeOp? = None
  for op in operators {
    match line.find(op.symbol) {
      Some(index) =>
        match best {
          None => best = Some({ op, index })
          Some(current_best) =>
            if index < current_best.index ||
              (
                index == current_best.index &&
                op.symbol.length() > current_best.op.symbol.length()
              ) {
              best = Some({ op, index })
            }
        }
      None => ()
    }
  }
  best
}

///|
fn ensure_node(nodes : Map[String, MermaidNode], node : MermaidNode) -> Unit {
  @parser_common_engine_core.ensure_node(nodes, node)
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
    ensure_node(nodes, node)
    apply_class_assignment(class_assignments, node, class_name)
    resolved.push(node)
  }
  resolved
}

///|
fn push_unique_id(ids : Array[String], id : String) -> Unit {
  @parser_common_engine_core.push_unique_id(ids, id)
}

///|
fn push_unique_node_ids(
  ids : Array[String],
  nodes : Array[MermaidNode],
) -> Unit {
  for node in nodes {
    push_unique_id(ids, node.id)
  }
}

///|
fn append_nodes_to_current_subgraph(
  subgraph_stack : Array[MermaidSubgraph],
  touched_node_ids : Array[String],
) -> Unit {
  @parser_common_engine_core.append_nodes_to_current_subgraph(
    subgraph_stack, touched_node_ids,
  )
}

///|
fn append_child_subgraph(
  subgraph_stack : Array[MermaidSubgraph],
  child : MermaidSubgraph,
) -> Unit {
  @parser_common_engine_core.append_child_subgraph(subgraph_stack, child)
}

///|
fn set_current_subgraph_direction(
  subgraph_stack : Array[MermaidSubgraph],
  direction : Direction,
) -> Unit {
  @parser_common_engine_core.set_current_subgraph_direction(
    subgraph_stack, direction,
  )
}
