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
  match token.to_upper() {
    "TD" => Some(TD)
    "TB" => Some(TB)
    "LR" => Some(LR)
    "BT" => Some(BT)
    "RL" => Some(RL)
    _ => None
  }
}

///|
fn parse_delimited_token(
  token : String,
  open : String,
  close : String,
  shape : NodeShape,
) -> MermaidNode? {
  match token.find(open) {
    Some(start) =>
      if !token.has_suffix(close) {
        None
      } else {
        let close_offset = token.length() - close.length()
        if close_offset < start + open.length() {
          None
        } else {
          let raw_id = trim_owned((try! token[:start]).to_string())
          let raw_label = trim_owned(
            (try! token[start + open.length():close_offset]).to_string(),
          )
          let id = if raw_id == "" {
            raw_label.to_lower().replace_all(old=" ", new="_")
          } else {
            raw_id
          }
          Some({ id, label: raw_label, shape })
        }
      }
    None => None
  }
}

///|
fn parse_node_token(raw_token : String) -> MermaidNode {
  let token = trim_owned(raw_token)

  if token == "" {
    return { id: "unnamed", label: "unnamed", shape: Rectangle }
  }

  match parse_delimited_token(token, "(((", ")))", DoubleCircle) {
    Some(node) => node
    None =>
      match parse_delimited_token(token, "[[", "]]", Subroutine) {
        Some(node) => node
        None =>
          match parse_delimited_token(token, "{{", "}}", Hexagon) {
            Some(node) => node
            None =>
              match parse_delimited_token(token, "([", "])", Stadium) {
                Some(node) => node
                None =>
                  match parse_delimited_token(token, "[(", ")]", Cylinder) {
                    Some(node) => node
                    None =>
                      match
                        parse_delimited_token(token, "[/", "\\]", Trapezoid) {
                        Some(node) => node
                        None =>
                          match
                            parse_delimited_token(
                              token,
                              "[\\",
                              "/]",
                              TrapezoidAlt,
                            ) {
                            Some(node) => node
                            None =>
                              match
                                parse_delimited_token(
                                  token,
                                  ">",
                                  "]",
                                  Asymmetric,
                                ) {
                                Some(node) => node
                                None =>
                                  match
                                    parse_delimited_token(
                                      token,
                                      "((",
                                      "))",
                                      Circle,
                                    ) {
                                    Some(node) => node
                                    None =>
                                      match
                                        parse_delimited_token(
                                          token,
                                          "[",
                                          "]",
                                          Rectangle,
                                        ) {
                                        Some(node) => node
                                        None =>
                                          match
                                            parse_delimited_token(
                                              token,
                                              "(",
                                              ")",
                                              Rounded,
                                            ) {
                                            Some(node) => node
                                            None =>
                                              match
                                                parse_delimited_token(
                                                  token,
                                                  "{",
                                                  "}",
                                                  Diamond,
                                                ) {
                                                Some(node) => node
                                                None =>
                                                  {
                                                    id: token,
                                                    label: token,
                                                    shape: Rectangle,
                                                  }
                                              }
                                          }
                                      }
                                  }
                              }
                          }
                      }
                  }
              }
          }
      }
  }
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
  if !ids.any(found => found == id) {
    ids.push(id)
  }
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
  if subgraph_stack.length() == 0 || touched_node_ids.length() == 0 {
    return
  }
  let last_index = subgraph_stack.length() - 1
  let current = subgraph_stack[last_index]
  let node_ids = current.node_ids.copy()
  for node_id in touched_node_ids {
    push_unique_id(node_ids, node_id)
  }
  subgraph_stack[last_index] = {
    id: current.id,
    label: current.label,
    node_ids,
    children: current.children,
    direction: current.direction,
  }
}

///|
fn append_child_subgraph(
  subgraph_stack : Array[MermaidSubgraph],
  child : MermaidSubgraph,
) -> Unit {
  if subgraph_stack.length() == 0 {
    return
  }
  let last_index = subgraph_stack.length() - 1
  let current = subgraph_stack[last_index]
  let children = current.children.copy()
  children.push(child)
  subgraph_stack[last_index] = {
    id: current.id,
    label: current.label,
    node_ids: current.node_ids,
    children,
    direction: current.direction,
  }
}

///|
fn set_current_subgraph_direction(
  subgraph_stack : Array[MermaidSubgraph],
  direction : Direction,
) -> Unit {
  if subgraph_stack.length() == 0 {
    return
  }
  let last_index = subgraph_stack.length() - 1
  let current = subgraph_stack[last_index]
  subgraph_stack[last_index] = {
    id: current.id,
    label: current.label,
    node_ids: current.node_ids,
    children: current.children,
    direction: Some(direction),
  }
}
