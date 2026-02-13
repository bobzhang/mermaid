///|
/// Trims whitespace and returns an owned copy of the string.
pub fn trim_owned(s : String) -> String {
  s.trim().to_string()
}

///|
/// Inserts a node into the map if it does not already exist.
pub fn ensure_node(
  nodes : Map[String, @model.MermaidNode],
  node : @model.MermaidNode,
) -> Unit {
  if !nodes.contains(node.id) {
    nodes[node.id] = node
  }
}

///|
/// Returns true if the text is a plain identifier with no spaces or sign prefixes.
pub fn is_plain_identifier(text : String) -> Bool {
  text != "" &&
  !text.contains(" ") &&
  !text.has_prefix("+") &&
  !text.has_prefix("-")
}

///|
/// Parses a direction token strictly (TD, TB, LR, BT, RL).
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
/// Parses a node token with open/close delimiters into a `MermaidNode`.
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
/// Parses a raw token string into a `MermaidNode` with shape detection.
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
/// Finds the earliest occurrence among operator symbols in a line.
pub fn find_earliest_operator_indices(
  line : String,
  operator_symbols : Array[String],
) -> (Int, Int)? {
  let mut best : (Int, Int)? = None
  for i in 0..<operator_symbols.length() {
    let symbol = operator_symbols[i]
    match line.find(symbol) {
      Some(index) =>
        match best {
          None => best = Some((i, index))
          Some((best_operator_index, best_index)) =>
            if index < best_index ||
              (
                index == best_index &&
                symbol.length() > operator_symbols[best_operator_index].length()
              ) {
              best = Some((i, index))
            }
        }
      None => ()
    }
  }
  best
}

///|
/// Finds the first matching operator symbol by priority order.
pub fn find_first_operator_indices(
  line : String,
  operator_symbols : Array[String],
) -> (Int, Int)? {
  for i in 0..<operator_symbols.length() {
    match line.find(operator_symbols[i]) {
      Some(index) => return Some((i, index))
      None => ()
    }
  }
  None
}

///|
/// Returns the edge operator specifications for flowchart parsing.
pub fn flow_edge_operator_specs() -> Array[
  (String, @model.EdgeStyle, Bool, Bool),
] {
  [
    ("<==>", Thick, true, true),
    ("<-.->", Dotted, true, true),
    ("<-->", Solid, true, true),
    ("==>", Thick, false, true),
    ("-.->", Dotted, false, true),
    ("-->", Solid, false, true),
    ("===", Thick, false, false),
    ("-.-", Dotted, false, false),
    ("---", Solid, false, false),
  ]
}

///|
/// Pushes an ID into the array if not already present.
pub fn push_unique_id(ids : Array[String], id : String) -> Unit {
  if !ids.any(found => found == id) {
    ids.push(id)
  }
}

///|
/// Appends touched node IDs to the current subgraph on the stack.
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
/// Appends a child subgraph to the current subgraph on the stack.
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
/// Sets the layout direction of the current subgraph on the stack.
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

///|
test "find_earliest_operator_indices" {
  let operators = ["-->", "---", "==>"]
  debug_inspect(
    find_earliest_operator_indices("A --> B", operators),
    content=(
      #|Some((0, 2))
    ),
  )
  debug_inspect(
    find_earliest_operator_indices("A --- B --> C", operators),
    content=(
      #|Some((1, 2))
    ),
  )
  debug_inspect(
    find_earliest_operator_indices("A ==>", operators),
    content=(
      #|Some((2, 2))
    ),
  )
  debug_inspect(
    find_earliest_operator_indices("A ~~ B", operators),
    content=(
      #|None
    ),
  )
}

///|
test "find_first_operator_indices" {
  let operators = ["-->", "---", "==>"]
  debug_inspect(
    find_first_operator_indices("A --- B --> C", operators),
    content=(
      #|Some((0, 8))
    ),
  )
  debug_inspect(
    find_first_operator_indices("A ==>", operators),
    content=(
      #|Some((2, 2))
    ),
  )
  debug_inspect(
    find_first_operator_indices("A ~~ B", operators),
    content=(
      #|None
    ),
  )
}

///|
test "flow_edge_operator_specs" {
  let specs = flow_edge_operator_specs()
  inspect(specs.length(), content="9")
  inspect(
    specs.any(spec => {
      let (symbol, _, _, _) = spec
      symbol == "<==>"
    }),
    content="true",
  )
}
