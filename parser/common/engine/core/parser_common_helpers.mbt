///|
pub fn trim_owned(s : String) -> String {
  s.trim().to_string()
}

///|
pub fn ensure_node(
  nodes : Map[String, @model.MermaidNode],
  node : @model.MermaidNode,
) -> Unit {
  if !nodes.contains(node.id) {
    nodes[node.id] = node
  }
}

///|
pub fn is_plain_identifier(text : String) -> Bool {
  text != "" &&
  !text.contains(" ") &&
  !text.has_prefix("+") &&
  !text.has_prefix("-")
}

///|
pub fn parse_direction_token_strict(token : String) -> @model.Direction? {
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
pub fn parse_delimited_token(
  token : String,
  open : String,
  close : String,
  shape : @model.NodeShape,
) -> @model.MermaidNode? {
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
pub fn parse_node_token(raw_token : String) -> @model.MermaidNode {
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
pub fn push_unique_id(ids : Array[String], id : String) -> Unit {
  if !ids.any(found => found == id) {
    ids.push(id)
  }
}

///|
pub fn append_nodes_to_current_subgraph(
  subgraph_stack : Array[@model.MermaidSubgraph],
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
pub fn append_child_subgraph(
  subgraph_stack : Array[@model.MermaidSubgraph],
  child : @model.MermaidSubgraph,
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
pub fn set_current_subgraph_direction(
  subgraph_stack : Array[@model.MermaidSubgraph],
  direction : @model.Direction,
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
