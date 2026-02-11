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
  s.trim().to_string()
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
fn parse_flow_direction(header : String) -> Direction? {
  let normalized = header.replace_all(old="\t", new=" ")
  lexmatch normalized[:] {
    ("[[:space:]]*" "(?i:graph|flowchart)" "[[:space:]]+" ("[^[:space:]]+" as dir) "[[:space:]]*") =>
      parse_direction_token_strict(dir.to_string())
    _ => None
  }
}

///|
fn preprocess_lines(text : String) -> Array[String] {
  let normalized = text.replace_all(old=";", new="\n")
  let lines : Array[String] = []
  for raw in normalized.split("\n") {
    let line = trim_owned(raw.to_string())
    if line == "" || line.has_prefix("%%") {
      continue
    }
    lines.push(line)
  }
  lines
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
fn split_node_and_class(raw_token : String) -> (String, String?) {
  lexmatch raw_token[:] {
    (token, ":::", class_name) => {
      let t = token.trim().to_string()
      let c = class_name.trim().to_string()
      if c == "" {
        (t, None)
      } else {
        (t, Some(c))
      }
    }
    _ => (raw_token.trim().to_string(), None)
  }
}

///|
fn parse_node_and_class(raw_token : String) -> (MermaidNode, String?) {
  let (token, class_name) = split_node_and_class(raw_token)
  (parse_node_token(token), class_name)
}

///|
fn split_parallel_node_segments(segment : String) -> Array[String] {
  let parts : Array[String] = []
  let mut start = 0
  let mut square_depth = 0
  let mut round_depth = 0
  let mut curly_depth = 0
  let mut in_single_quote = false
  let mut in_double_quote = false

  for i in 0..<segment.length() {
    let unit = segment[i]
    if unit == '"' && !in_single_quote {
      in_double_quote = !in_double_quote
      continue
    }
    if unit == '\'' && !in_double_quote {
      in_single_quote = !in_single_quote
      continue
    }
    if in_single_quote || in_double_quote {
      continue
    }
    if unit == '[' {
      square_depth = square_depth + 1
      continue
    }
    if unit == ']' {
      if square_depth > 0 {
        square_depth = square_depth - 1
      }
      continue
    }
    if unit == '(' {
      round_depth = round_depth + 1
      continue
    }
    if unit == ')' {
      if round_depth > 0 {
        round_depth = round_depth - 1
      }
      continue
    }
    if unit == '{' {
      curly_depth = curly_depth + 1
      continue
    }
    if unit == '}' {
      if curly_depth > 0 {
        curly_depth = curly_depth - 1
      }
      continue
    }
    if unit == '&' && square_depth == 0 && round_depth == 0 && curly_depth == 0 {
      let part = trim_owned((try! segment[start:i]).to_string())
      if part != "" {
        parts.push(part)
      }
      start = i + 1
    }
  }

  let tail = if start < segment.length() {
    trim_owned((try! segment[start:]).to_string())
  } else {
    ""
  }
  if tail != "" {
    parts.push(tail)
  }
  parts
}

///|
fn split_parallel_nodes_with_classes(
  segment : String,
) -> Array[(MermaidNode, String?)] {
  let entries : Array[(MermaidNode, String?)] = []
  for part in split_parallel_node_segments(segment) {
    entries.push(parse_node_and_class(part))
  }
  entries
}

///|
fn edge_operators() -> Array[EdgeOp] {
  [
    { symbol: "<==>", style: Thick, has_arrow_start: true, has_arrow_end: true },
    {
      symbol: "<-.->",
      style: Dotted,
      has_arrow_start: true,
      has_arrow_end: true,
    },
    { symbol: "<-->", style: Solid, has_arrow_start: true, has_arrow_end: true },
    { symbol: "==>", style: Thick, has_arrow_start: false, has_arrow_end: true },
    {
      symbol: "-.->",
      style: Dotted,
      has_arrow_start: false,
      has_arrow_end: true,
    },
    { symbol: "-->", style: Solid, has_arrow_start: false, has_arrow_end: true },
    {
      symbol: "===",
      style: Thick,
      has_arrow_start: false,
      has_arrow_end: false,
    },
    {
      symbol: "-.-",
      style: Dotted,
      has_arrow_start: false,
      has_arrow_end: false,
    },
    {
      symbol: "---",
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: false,
    },
  ]
}

///|
fn find_edge_operator(line : String) -> FoundEdgeOp? {
  for op in edge_operators() {
    match line.find(op.symbol) {
      Some(index) => return Some({ op, index })
      None => ()
    }
  }
  None
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
fn find_earliest_edge_operator(line : String) -> FoundEdgeOp? {
  find_earliest_operator(line, edge_operators())
}

///|
fn sequence_edge_operators() -> Array[EdgeOp] {
  [
    {
      symbol: "-->>",
      style: Dotted,
      has_arrow_start: false,
      has_arrow_end: true,
    },
    {
      symbol: "-->",
      style: Dotted,
      has_arrow_start: false,
      has_arrow_end: true,
    },
    {
      symbol: "--)",
      style: Dotted,
      has_arrow_start: false,
      has_arrow_end: true,
    },
    {
      symbol: "--x",
      style: Dotted,
      has_arrow_start: false,
      has_arrow_end: true,
    },
    { symbol: "->>", style: Solid, has_arrow_start: false, has_arrow_end: true },
    { symbol: "->", style: Solid, has_arrow_start: false, has_arrow_end: true },
    { symbol: "-)", style: Solid, has_arrow_start: false, has_arrow_end: true },
    { symbol: "-x", style: Solid, has_arrow_start: false, has_arrow_end: true },
  ]
}

///|
fn find_sequence_operator(line : String) -> FoundEdgeOp? {
  find_earliest_operator(line, sequence_edge_operators())
}

///|
fn parse_label_and_target(raw_rhs : String) -> (String?, String) {
  let rhs = raw_rhs.trim()
  if rhs lexmatch? ("\|", tail) {
    lexmatch tail {
      (label, "\|", target) =>
        // FIXME: why `\|` needed here, otherwise warning reported?
        (Some(label.trim().to_string()), target.trim().to_string())
      _ => (None, rhs.to_string())
    }
  } else {
    (None, rhs.to_string())
  }
}

///|
test "parse_label_and_target" {
  // label between pipes, target after
  debug_inspect(
    parse_label_and_target("| b | c"),
    content=(
      #|(Some("b"), "c")
    ),
  )
  // no pipe prefix → no label
  debug_inspect(
    parse_label_and_target("hello"),
    content=(
      #|(None, "hello")
    ),
  )
  // empty string
  debug_inspect(
    parse_label_and_target(""),
    content=(
      #|(None, "")
    ),
  )
  // leading pipe but no closing pipe → no label, original returned
  debug_inspect(
    parse_label_and_target("| no close"),
    content=(
      #|(None, "| no close")
    ),
  )
  // empty label between pipes
  debug_inspect(
    parse_label_and_target("|| target"),
    content=(
      #|(Some(""), "target")
    ),
  )
  // whitespace-only input
  debug_inspect(
    parse_label_and_target("   "),
    content=(
      #|(None, "")
    ),
  )
  // pipe with spaces around label and target
  debug_inspect(
    parse_label_and_target("  | yes |  B[Node]  "),
    content=(
      #|(Some("yes"), "B[Node]")
    ),
  )
  // no pipe, input has leading/trailing spaces
  debug_inspect(
    parse_label_and_target("  A[Start]  "),
    content=(
      #|(None, "A[Start]")
    ),
  )
}

///|
test "split_node_and_class" {
  debug_inspect(
    split_node_and_class("A:::myClass"),
    content=(
      #|("A", Some("myClass"))
    ),
  )
  debug_inspect(
    split_node_and_class("A"),
    content=(
      #|("A", None)
    ),
  )
  debug_inspect(
    split_node_and_class("A[Label]:::cls"),
    content=(
      #|("A[Label]", Some("cls"))
    ),
  )
  debug_inspect(
    split_node_and_class("A:::"),
    content=(
      #|("A", None)
    ),
  )
  debug_inspect(
    split_node_and_class("  B  ::: highlight "),
    content=(
      #|("B", Some("highlight"))
    ),
  )
}

///|
fn ensure_node(nodes : Map[String, MermaidNode], node : MermaidNode) -> Unit {
  if !nodes.contains(node.id) {
    nodes[node.id] = node
  }
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
fn parse_style_properties(text : String) -> Map[String, String] {
  let props : Map[String, String] = {}
  for part in text.split(",") {
    let normalized = part.trim()
    if normalized.length() == 0 {
      continue
    }
    lexmatch normalized {
      (key, ":", value) => {
        let k = key.trim().to_string()
        let v = value.trim().to_string()
        if k != "" && v != "" {
          props[k] = v
        }
      }
      _ => ()
    }
  }
  props
}

///|
fn parse_class_def_line(
  line : String,
  class_defs : Map[String, Map[String, String]],
) -> Unit {
  let rest = (try! line[9:]).trim()
  lexmatch rest {
    ("[^[:space:]]+" as class_name, tail) => {
      let cn = class_name.to_string()
      if cn != "" {
        class_defs[cn] = parse_style_properties(tail.trim().to_string())
      }
    }
    _ => ()
  }
}

///|
fn parse_class_line(
  line : String,
  class_assignments : Map[String, String],
) -> Unit {
  let rest = trim_owned((try! line[6:]).to_string())
  match rest.rev_find(" ") {
    Some(idx) => {
      let node_list = trim_owned((try! rest[:idx]).to_string())
      let class_name = trim_owned((try! rest[idx + 1:]).to_string())
      if class_name == "" || node_list == "" {
        return
      }
      for node_part in node_list.split(",") {
        let node_id = trim_owned(node_part.to_string())
        if node_id != "" {
          class_assignments[node_id] = class_name
        }
      }
    }
    None => ()
  }
}

///|
fn parse_style_line(
  line : String,
  node_styles : Map[String, Map[String, String]],
) -> Unit {
  let rest = (try! line[6:]).trim()
  lexmatch rest {
    ("[^[:space:]]+" as node_list, tail) => {
      let style_map = parse_style_properties(tail.trim().to_string())
      for node_part in node_list.to_string().split(",") {
        let node_id = node_part.trim().to_string()
        if node_id != "" {
          node_styles[node_id] = style_map.copy()
        }
      }
    }
    _ => ()
  }
}

///|
fn append_edges(
  source_nodes : Array[MermaidNode],
  target_nodes : Array[MermaidNode],
  op : EdgeOp,
  label : String?,
  edges : Array[MermaidEdge],
) -> Unit {
  for source_node in source_nodes {
    for target_node in target_nodes {
      edges.push({
        source: source_node.id,
        target: target_node.id,
        label,
        style: op.style,
        has_arrow_start: op.has_arrow_start,
        has_arrow_end: op.has_arrow_end,
        relation_operator: Some(op.symbol),
      })
    }
  }
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
fn is_subgraph_slug_char(unit : UInt16) -> Bool {
  unit is ('a'..='z') ||
  unit is ('A'..='Z') ||
  unit is ('0'..='9') ||
  unit == '_'
}

///|
fn is_subgraph_id_token(token : String) -> Bool {
  token[:] lexmatch? "[a-zA-Z0-9_\-]+"
}

///|
fn normalize_subgraph_id_from_label(label : String) -> String {
  let collapsed = label
    .split(" ")
    .map(part => trim_owned(part.to_string()))
    .filter(part => part != "")
    .iter()
    .join("_")
  let sb = StringBuilder::new()
  for i in 0..<collapsed.length() {
    if is_subgraph_slug_char(collapsed[i]) {
      sb.write_string((try! collapsed[i:i + 1]).to_string())
    }
  }
  let id = sb.to_string()
  if id == "" {
    "subgraph"
  } else {
    id
  }
}

///|
fn parse_subgraph_start_line(line : String) -> MermaidSubgraph? {
  if !line.has_prefix("subgraph ") {
    return None
  }
  let rest = trim_owned((try! line[9:]).to_string())
  if rest == "" {
    return None
  }

  match rest.find("[") {
    Some(open_idx) =>
      if rest.has_suffix("]") {
        let raw_id = trim_owned((try! rest[:open_idx]).to_string())
        let raw_label = trim_owned(
          (try! rest[open_idx + 1:rest.length() - 1]).to_string(),
        )
        if raw_id != "" && raw_label != "" && is_subgraph_id_token(raw_id) {
          return Some({
            id: raw_id,
            label: raw_label,
            node_ids: [],
            children: [],
            direction: None,
          })
        }
      }
    None => ()
  }

  Some({
    id: normalize_subgraph_id_from_label(rest),
    label: rest,
    node_ids: [],
    children: [],
    direction: None,
  })
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

///|
fn parse_flow_line(
  line : String,
  nodes : Map[String, MermaidNode],
  edges : Array[MermaidEdge],
  class_defs : Map[String, Map[String, String]],
  class_assignments : Map[String, String],
  node_styles : Map[String, Map[String, String]],
) -> Array[String] {
  if line.has_prefix("classDef ") {
    parse_class_def_line(line, class_defs)
    return []
  }
  if line.has_prefix("class ") {
    parse_class_line(line, class_assignments)
    return []
  }
  if line.has_prefix("style ") {
    parse_style_line(line, node_styles)
    return []
  }

  match find_earliest_edge_operator(line) {
    Some(found) => {
      let touched_node_ids : Array[String] = []
      let left_segment = trim_owned((try! line[:found.index]).to_string())
      let mut current_sources = ensure_nodes_from_entries(
        nodes,
        class_assignments,
        split_parallel_nodes_with_classes(left_segment),
      )
      push_unique_node_ids(touched_node_ids, current_sources)

      let mut current_op = found.op
      let mut rhs = trim_owned(
        (try! line[found.index + found.op.symbol.length():]).to_string(),
      )

      let mut done = false
      while !done {
        let (label, rhs_without_label) = parse_label_and_target(rhs)
        match find_earliest_edge_operator(rhs_without_label) {
          Some(next_found) => {
            let target_segment = trim_owned(
              (try! rhs_without_label[:next_found.index]).to_string(),
            )
            let next_targets = ensure_nodes_from_entries(
              nodes,
              class_assignments,
              split_parallel_nodes_with_classes(target_segment),
            )
            push_unique_node_ids(touched_node_ids, next_targets)
            append_edges(
              current_sources, next_targets, current_op, label, edges,
            )
            current_sources = next_targets
            current_op = next_found.op
            rhs = trim_owned(
              (try! rhs_without_label[next_found.index +
              next_found.op.symbol.length():]).to_string(),
            )
          }
          None => {
            let final_targets = ensure_nodes_from_entries(
              nodes,
              class_assignments,
              split_parallel_nodes_with_classes(rhs_without_label),
            )
            push_unique_node_ids(touched_node_ids, final_targets)
            append_edges(
              current_sources, final_targets, current_op, label, edges,
            )
            done = true
          }
        }
      }
      touched_node_ids
    }
    None =>
      if line.has_prefix("subgraph ") || line == "end" {
        []
      } else if line.has_prefix("direction ") {
        []
      } else {
        let standalone_entries = if line.contains("&") {
          split_parallel_nodes_with_classes(line)
        } else {
          [parse_node_and_class(line)]
        }
        let touched = ensure_nodes_from_entries(
          nodes, class_assignments, standalone_entries,
        )
        let touched_node_ids : Array[String] = []
        push_unique_node_ids(touched_node_ids, touched)
        touched_node_ids
      }
  }
}

///|
fn parse_state_token(
  token : String,
  is_source : Bool,
  nodes : Map[String, MermaidNode],
  start_counter : Int,
  end_counter : Int,
) -> (String, Int, Int) {
  let trimmed = trim_owned(token)
  if trimmed == "[*]" {
    if is_source {
      let next = start_counter + 1
      let id = "state_start_\{next}"
      ensure_node(nodes, { id, label: "", shape: StateStart })
      (id, next, end_counter)
    } else {
      let next = end_counter + 1
      let id = "state_end_\{next}"
      ensure_node(nodes, { id, label: "", shape: StateEnd })
      (id, start_counter, next)
    }
  } else {
    let parsed = parse_node_token(trimmed)
    let node = MermaidNode::{
      id: parsed.id,
      label: parsed.label,
      shape: if parsed.shape == Rectangle {
        Rounded
      } else {
        parsed.shape
      },
    }
    ensure_node(nodes, node)
    (node.id, start_counter, end_counter)
  }
}

///|
fn strip_quotes(s : StringView) -> String {
  lexmatch s {
    ("\"" (".*" as content) "\"") => content.to_string()
    _ => s.to_string()
  }
}

///|
fn parse_state_declaration(
  line : String,
  nodes : Map[String, MermaidNode],
  composite_stack : Array[MermaidSubgraph],
) -> Unit {
  if !line.has_prefix("state ") {
    return
  }
  let rest = (try! line[6:]).trim()
  lexmatch rest {
    (raw_label, " as ", id_part) => {
      let id = id_part.trim().to_string()
      let label = strip_quotes(raw_label.trim())
      if id != "" {
        ensure_node(nodes, { id, label, shape: Rounded })
        append_nodes_to_current_subgraph(composite_stack, [id])
      }
    }
    _ => {
      let rest_str = rest.to_string()
      let parsed = parse_node_token(rest_str)
      let node = MermaidNode::{
        id: parsed.id,
        label: parsed.label,
        shape: if parsed.shape == Rectangle {
          Rounded
        } else {
          parsed.shape
        },
      }
      ensure_node(nodes, node)
      append_nodes_to_current_subgraph(composite_stack, [node.id])
    }
  }
}

///|
fn parse_state_composite_start_line(line : String) -> MermaidSubgraph? {
  if !line.has_prefix("state ") || !line.has_suffix("{") {
    return None
  }
  let rest = (try! line[6:line.length() - 1]).trim()
  if rest.length() == 0 {
    return None
  }

  lexmatch rest {
    (raw_label, " as ", id_part) => {
      let id = id_part.trim().to_string()
      if id == "" || !is_plain_identifier(id) {
        return None
      }
      let label = strip_quotes(raw_label.trim())
      return Some({
        id,
        label: if label == "" {
          id
        } else {
          label
        },
        node_ids: [],
        children: [],
        direction: None,
      })
    }
    _ => ()
  }

  let rest_str = rest.to_string()
  if !is_plain_identifier(rest_str) {
    return None
  }
  Some({
    id: rest_str,
    label: rest_str,
    node_ids: [],
    children: [],
    direction: None,
  })
}

///|
fn append_state_node_to_current_composite(
  composite_stack : Array[MermaidSubgraph],
  node_id : String,
) -> Unit {
  if node_id == "" {
    return
  }
  append_nodes_to_current_subgraph(composite_stack, [node_id])
}

///|
fn parse_state_description_line(
  state_id : String,
  description : String,
  nodes : Map[String, MermaidNode],
) -> Bool {
  let id = trim_owned(state_id)
  let label = trim_owned(description)
  if id == "" || label == "" || !is_plain_identifier(id) {
    return false
  }

  match nodes.get(id) {
    Some(existing) => {
      let shape = if existing.shape == Rectangle {
        NodeShape::Rounded
      } else {
        existing.shape
      }
      nodes[id] = { id: existing.id, label, shape }
    }
    None => nodes[id] = { id, label, shape: Rounded }
  }
  true
}

///|
fn parse_state_diagram(lines : Array[String]) -> MermaidGraph {
  let nodes : Map[String, MermaidNode] = {}
  let edges : Array[MermaidEdge] = []
  let subgraphs : Array[MermaidSubgraph] = []
  let composite_stack : Array[MermaidSubgraph] = []
  let mut direction = Direction::TD
  let mut start_counter = 0
  let mut end_counter = 0

  for i in 1..<lines.length() {
    let line = lines[i]
    if line.has_prefix("direction ") {
      let token = trim_owned((try! line[10:]).to_string())
      match parse_direction_token_strict(token) {
        Some(parsed_direction) =>
          if composite_stack.length() > 0 {
            set_current_subgraph_direction(composite_stack, parsed_direction)
          } else {
            direction = parsed_direction
          }
        None => ()
      }
      continue
    }

    match parse_state_composite_start_line(line) {
      Some(composite) => {
        composite_stack.push(composite)
        continue
      }
      None => ()
    }

    if line == "}" {
      match composite_stack.pop() {
        Some(completed) =>
          if composite_stack.length() > 0 {
            append_child_subgraph(composite_stack, completed)
          } else {
            subgraphs.push(completed)
          }
        None => ()
      }
      continue
    }

    if line.has_prefix("state ") {
      parse_state_declaration(line, nodes, composite_stack)
      continue
    }
    if line == "{" {
      continue
    }

    let (transition_line, edge_label) = lexmatch line[:] {
      (lhs, ":", rhs) =>
        (lhs.trim().to_string(), Some(rhs.trim().to_string()))
      _ => (line, None)
    }

    match find_edge_operator(transition_line) {
      Some(found) => {
        let left = trim_owned((try! transition_line[:found.index]).to_string())
        let right = trim_owned(
          (try! transition_line[found.index + found.op.symbol.length():]).to_string(),
        )
        let (source_id, next_start, next_end) = parse_state_token(
          left, true, nodes, start_counter, end_counter,
        )
        start_counter = next_start
        end_counter = next_end
        let (target_id, final_start, final_end) = parse_state_token(
          right, false, nodes, start_counter, end_counter,
        )
        start_counter = final_start
        end_counter = final_end
        edges.push({
          source: source_id,
          target: target_id,
          label: edge_label,
          style: found.op.style,
          has_arrow_start: found.op.has_arrow_start,
          has_arrow_end: found.op.has_arrow_end,
          relation_operator: Some(found.op.symbol),
        })
        append_nodes_to_current_subgraph(composite_stack, [source_id, target_id])
      }
      None =>
        match edge_label {
          Some(description) =>
            if parse_state_description_line(transition_line, description, nodes) {
              append_state_node_to_current_composite(
                composite_stack,
                trim_owned(transition_line),
              )
            }
          None => ()
        }
    }
  }

  {
    direction,
    nodes,
    edges,
    subgraphs,
    class_defs: {},
    class_assignments: {},
    node_styles: {},
    sequence_actor_order: [],
    sequence_actor_kinds: {},
    sequence_blocks: [],
    sequence_notes: [],
    sequence_activation_commands: [],
  }
}

///|
fn parse_sequence_participant_declaration(
  line : String,
  nodes : Map[String, MermaidNode],
  actor_order : Array[String],
  actor_kinds : Map[String, SequenceParticipantKind],
) -> Bool {
  let lower_line = line.to_lower()
  let mut rest = ""
  let kind = if lower_line.has_prefix("participant ") {
    rest = trim_owned((try! line[12:]).to_string())
    SequenceParticipantKind::Participant
  } else if lower_line.has_prefix("actor ") {
    rest = trim_owned((try! line[6:]).to_string())
    Actor
  } else {
    return false
  }

  if rest == "" {
    return true
  }

  lexmatch rest[:] {
    (id_part, " (?i:as) ", label_part) => {
      let id = id_part.trim().to_string()
      let label = label_part.trim().to_string()
      if id != "" {
        if !nodes.contains(id) {
          actor_order.push(id)
        }
        nodes[id] = {
          id,
          label: if label == "" {
            id
          } else {
            label
          },
          shape: SequenceParticipant,
        }
        actor_kinds[id] = kind
      }
    }
    _ => {
      if !nodes.contains(rest) {
        actor_order.push(rest)
      }
      nodes[rest] = { id: rest, label: rest, shape: SequenceParticipant }
      actor_kinds[rest] = kind
    }
  }
  true
}

///|
fn ensure_sequence_participant(
  nodes : Map[String, MermaidNode],
  actor_order : Array[String],
  actor_kinds : Map[String, SequenceParticipantKind],
  actor_id : String,
) -> Unit {
  if !nodes.contains(actor_id) {
    actor_order.push(actor_id)
    nodes[actor_id] = {
      id: actor_id,
      label: actor_id,
      shape: SequenceParticipant,
    }
  }
  if !actor_kinds.contains(actor_id) {
    actor_kinds[actor_id] = Participant
  }
}

///|
fn sequence_label_for_keyword(
  line : String,
  lower_line : String,
  keyword : String,
) -> String? {
  if lower_line == keyword {
    return Some("")
  }
  if lower_line.has_prefix("\{keyword} ") {
    return Some(trim_owned((try! line[keyword.length():]).to_string()))
  }
  None
}

///|
fn parse_sequence_block_header(line : String) -> (SequenceBlockType, String)? {
  let lower_line = line.to_lower()
  match sequence_label_for_keyword(line, lower_line, "loop") {
    Some(label) => return Some((Loop, label))
    None => ()
  }
  match sequence_label_for_keyword(line, lower_line, "alt") {
    Some(label) => return Some((Alt, label))
    None => ()
  }
  match sequence_label_for_keyword(line, lower_line, "opt") {
    Some(label) => return Some((Opt, label))
    None => ()
  }
  match sequence_label_for_keyword(line, lower_line, "par") {
    Some(label) => return Some((Par, label))
    None => ()
  }
  match sequence_label_for_keyword(line, lower_line, "critical") {
    Some(label) => return Some((Critical, label))
    None => ()
  }
  match sequence_label_for_keyword(line, lower_line, "break") {
    Some(label) => return Some((Break, label))
    None => ()
  }
  match sequence_label_for_keyword(line, lower_line, "rect") {
    Some(label) => return Some((Rect, label))
    None => ()
  }
  None
}

///|
fn parse_sequence_divider_label(line : String) -> String? {
  let lower_line = line.to_lower()
  match sequence_label_for_keyword(line, lower_line, "else") {
    Some(label) => Some(label)
    None => sequence_label_for_keyword(line, lower_line, "and")
  }
}

///|
fn parse_sequence_note_line(
  line : String,
  nodes : Map[String, MermaidNode],
  actor_order : Array[String],
  actor_kinds : Map[String, SequenceParticipantKind],
  notes : Array[SequenceNote],
  after_index : Int,
) -> Bool {
  let lower_line = line.to_lower()
  if !lower_line.has_prefix("note ") {
    return false
  }

  lexmatch (try! line[5:]) {
    (placement_part, ":", text_part) => {
      let placement = placement_part.trim()
      let (position, raw_actors) = lexmatch placement {
        ("(?i:left of) ", rest) =>
          (SequenceNotePosition::Left, rest.trim().to_string())
        ("(?i:right of) ", rest) =>
          (Right, rest.trim().to_string())
        ("(?i:over) ", rest) => (Over, rest.trim().to_string())
        _ => return true
      }
      let text = text_part.trim().to_string()
      let actor_ids : Array[String] = []
      for raw_actor in raw_actors.split(",") {
        let actor_id = raw_actor.trim().to_string()
        if actor_id != "" {
          ensure_sequence_participant(nodes, actor_order, actor_kinds, actor_id)
          actor_ids.push(actor_id)
        }
      }
      if actor_ids.length() > 0 && text != "" {
        notes.push({ actor_ids, text, position, after_index })
      }
      true
    }
    _ => true
  }
}

///|
priv struct OpenSequenceBlock {
  block_type : SequenceBlockType
  label : String
  start_index : Int
  dividers : Array[SequenceBlockDivider]
}

///|
fn stack_set_open_block(
  stack : Array[OpenSequenceBlock],
  depth : Int,
  value : OpenSequenceBlock,
) -> Unit {
  if depth < stack.length() {
    stack[depth] = value
  } else {
    stack.push(value)
  }
}

///|
fn parse_sequence_message_line(
  line : String,
  nodes : Map[String, MermaidNode],
  actor_order : Array[String],
  actor_kinds : Map[String, SequenceParticipantKind],
  edges : Array[MermaidEdge],
) -> Bool {
  match find_sequence_operator(line) {
    Some(found) => {
      let source = trim_owned((try! line[:found.index]).to_string())
      let rhs = trim_owned(
        (try! line[found.index + found.op.symbol.length():]).to_string(),
      )
      let (raw_target, label) = lexmatch rhs[:] {
        (target_part, ":", label_part) => {
          let target = target_part.trim().to_string()
          let raw_label = label_part.trim().to_string()
          (target, if raw_label == "" { None } else { Some(raw_label) })
        }
        _ => (rhs, None)
      }
      let activation_mark = if raw_target.has_prefix("+") {
        "+"
      } else if raw_target.has_prefix("-") {
        "-"
      } else {
        ""
      }
      let target = if activation_mark == "" {
        raw_target
      } else {
        trim_owned((try! raw_target[1:]).to_string())
      }

      if source == "" || target == "" {
        return true
      }

      ensure_sequence_participant(nodes, actor_order, actor_kinds, source)
      ensure_sequence_participant(nodes, actor_order, actor_kinds, target)
      let relation_operator = if activation_mark == "" {
        found.op.symbol
      } else {
        "\{found.op.symbol}\{activation_mark}"
      }
      edges.push({
        source,
        target,
        label,
        style: found.op.style,
        has_arrow_start: found.op.has_arrow_start,
        has_arrow_end: found.op.has_arrow_end,
        relation_operator: Some(relation_operator),
      })
      true
    }
    None => false
  }
}

///|
fn parse_sequence_diagram(lines : Array[String]) -> MermaidGraph {
  let nodes : Map[String, MermaidNode] = {}
  let edges : Array[MermaidEdge] = []
  let actor_order : Array[String] = []
  let actor_kinds : Map[String, SequenceParticipantKind] = {}
  let blocks : Array[SequenceBlock] = []
  let notes : Array[SequenceNote] = []
  let activation_commands : Array[SequenceActivationCommand] = []
  let open_blocks : Array[OpenSequenceBlock] = []
  let mut open_depth = 0

  for i in 1..<lines.length() {
    let line = lines[i]

    if parse_sequence_participant_declaration(
        line, nodes, actor_order, actor_kinds,
      ) {
      continue
    }

    if parse_sequence_note_line(
        line,
        nodes,
        actor_order,
        actor_kinds,
        notes,
        edges.length() - 1,
      ) {
      continue
    }

    let lower_line = line.to_lower()
    if lower_line.has_prefix("activate ") ||
      lower_line.has_prefix("deactivate ") {
      continue
    }

    match parse_sequence_block_header(line) {
      Some((block_type, label)) => {
        stack_set_open_block(open_blocks, open_depth, {
          block_type,
          label,
          start_index: edges.length(),
          dividers: [],
        })
        open_depth = open_depth + 1
        continue
      }
      None => ()
    }

    match parse_sequence_divider_label(line) {
      Some(label) =>
        if open_depth > 0 {
          let top_index = open_depth - 1
          let top = open_blocks[top_index]
          let next_dividers : Array[SequenceBlockDivider] = []
          for divider in top.dividers {
            next_dividers.push(divider)
          }
          next_dividers.push({ index: edges.length(), label })
          open_blocks[top_index] = {
            block_type: top.block_type,
            label: top.label,
            start_index: top.start_index,
            dividers: next_dividers,
          }
          continue
        }
      None => ()
    }

    if line == "end" && open_depth > 0 {
      open_depth = open_depth - 1
      let completed = open_blocks[open_depth]
      blocks.push({
        block_type: completed.block_type,
        label: completed.label,
        start_index: completed.start_index,
        end_index: (edges.length() - 1).max(completed.start_index),
        dividers: completed.dividers,
      })
      continue
    }

    if lower_line.has_prefix("autonumber") {
      continue
    }

    ignore(
      parse_sequence_message_line(line, nodes, actor_order, actor_kinds, edges),
    )
  }

  {
    direction: LR,
    nodes,
    edges,
    subgraphs: [],
    class_defs: {},
    class_assignments: {},
    node_styles: {},
    sequence_actor_order: actor_order,
    sequence_actor_kinds: actor_kinds,
    sequence_blocks: blocks,
    sequence_notes: notes,
    sequence_activation_commands: activation_commands,
  }
}

///|
fn parse_relation_parts(line : String) -> (String, String, String, String?)? {
  let (body, label) = lexmatch line[:] {
    (head, ":", raw_label) => {
      let h = head.trim().to_string()
      let rl = raw_label.trim().to_string()
      (h, if rl == "" { None } else { Some(rl) })
    }
    _ => (line, None)
  }
  let parts = body
    .split(" ")
    .map(part => trim_owned(part.to_string()))
    .filter(part => part != "")
    .to_array()
  if parts.length() < 3 {
    return None
  }

  let source = parts[0]
  let mut operator_index = -1
  for i, part in parts {
    if !(part.has_prefix("\"") && part.has_suffix("\"")) &&
      (part.contains("-") || part.contains(".")) {
      operator_index = i
      break
    }
  }
  if operator_index <= 0 || operator_index >= parts.length() - 1 {
    return None
  }

  let operator = parts[operator_index]
  let mut target = ""
  for i in (operator_index + 1)..<parts.length() {
    let candidate = parts[i]
    if !(candidate.has_prefix("\"") && candidate.has_suffix("\"")) {
      target = candidate
      break
    }
  }

  if source == "" || target == "" {
    return None
  }
  Some((source, operator, target, label))
}

///|
fn edge_style_for_operator(operator : String) -> EdgeStyle {
  if operator.contains(".") {
    Dotted
  } else if operator.contains("=") {
    Thick
  } else {
    Solid
  }
}

///|
fn collapse_spaces(text : String) -> String {
  text
  .split(" ")
  .map(part => trim_owned(part.to_string()))
  .filter(part => part != "")
  .iter()
  .join(" ")
}

///|
fn normalize_er_attribute(raw : String) -> String {
  let normalized = collapse_spaces(raw)
  if normalized == "" {
    return ""
  }

  let mut body = normalized
  let mut comment = ""
  match normalized.find("\"") {
    Some(quote_idx) => {
      body = trim_owned((try! normalized[:quote_idx]).to_string())
      comment = trim_owned((try! normalized[quote_idx:]).to_string())
    }
    None => ()
  }

  let parts = body
    .split(" ")
    .map(part => trim_owned(part.to_string()))
    .filter(part => part != "")
    .to_array()
  if parts.length() < 2 {
    return normalized
  }

  let key = parts[parts.length() - 1].to_upper()
  if key is ("PK" | "UK" | "FK") {
    let core : Array[String] = []
    for i in 0..<(parts.length() - 1) {
      core.push(parts[i])
    }
    let core_text = core.iter().join(" ")
    let reordered = if core_text == "" { key } else { "\{key} \{core_text}" }
    if comment == "" {
      reordered
    } else {
      "\{reordered} \{comment}"
    }
  } else {
    normalized
  }
}

///|
fn normalize_class_member(raw : String) -> String {
  let trimmed = collapse_spaces(raw)
  if trimmed == "" {
    return ""
  }
  if trimmed.has_prefix("<<") && trimmed.has_suffix(">>") {
    return trimmed
  }

  let visibility = if trimmed.has_prefix("+") {
    "+"
  } else if trimmed.has_prefix("-") {
    "-"
  } else if trimmed.has_prefix("#") {
    "#"
  } else if trimmed.has_prefix("~") {
    "~"
  } else {
    ""
  }
  let body = if visibility == "" {
    trimmed
  } else {
    trim_owned((try! trimmed[1:]).to_string())
  }
  if body == "" {
    return trimmed
  }

  if body.contains("(") && body.contains(")") {
    match (body.find("("), body.find(")")) {
      (Some(open_idx), Some(close_idx)) => {
        let name = trim_owned((try! body[:open_idx]).to_string())
        let return_type = trim_owned((try! body[close_idx + 1:]).to_string())
        if name == "" {
          return trimmed
        }
        let rendered = if return_type == "" {
          name
        } else {
          "\{name}: \{return_type}"
        }
        let marked = "\{rendered} ()"
        return if visibility == "" { marked } else { "\{visibility}\{marked}" }
      }
      _ => ()
    }
  }

  let parts = body
    .split(" ")
    .map(part => trim_owned(part.to_string()))
    .filter(part => part != "")
    .to_array()
  if parts.length() >= 2 {
    let ty = parts[0]
    let name = parts[1:].iter().join(" ")
    let rendered = "\{name}: \{ty}"
    if visibility == "" {
      rendered
    } else {
      "\{visibility}\{rendered}"
    }
  } else {
    trimmed
  }
}

///|
fn append_detail(
  details : Map[String, Array[String]],
  node_id : String,
  detail : String,
) -> Unit {
  if node_id == "" || detail == "" {
    return
  }
  let rows = details.get_or_init(node_id, () => [])
  rows.push(detail)
}

///|
fn apply_details_to_nodes(
  nodes : Map[String, MermaidNode],
  details : Map[String, Array[String]],
) -> Unit {
  for entry in details.to_array() {
    let (node_id, rows) = entry
    if rows.length() == 0 {
      continue
    }
    match nodes.get(node_id) {
      Some(node) => {
        let detail_text = rows.iter().join("\n")
        nodes[node_id] = {
          id: node.id,
          label: "\{node.label}\n\{detail_text}",
          shape: node.shape,
        }
      }
      None => ()
    }
  }
}

///|
fn is_plain_identifier(text : String) -> Bool {
  text != "" &&
  !text.contains(" ") &&
  !text.has_prefix("+") &&
  !text.has_prefix("-")
}

///|
fn append_relation_edge(
  source : String,
  operator : String,
  target : String,
  label : String?,
  default_shape : NodeShape,
  nodes : Map[String, MermaidNode],
  edges : Array[MermaidEdge],
) -> Unit {
  ensure_node(nodes, { id: source, label: source, shape: default_shape })
  ensure_node(nodes, { id: target, label: target, shape: default_shape })
  edges.push({
    source,
    target,
    label,
    style: edge_style_for_operator(operator),
    has_arrow_start: operator.contains("<"),
    has_arrow_end: operator.contains(">"),
    relation_operator: Some(operator),
  })
}

///|
fn parse_class_declaration(line : String) -> (String, Bool)? {
  if !line.has_prefix("class ") {
    return None
  }
  let mut rest = trim_owned((try! line[6:]).to_string())
  let opens_block = rest.has_suffix("{")
  if rest.has_suffix("{") {
    rest = trim_owned((try! rest[:rest.length() - 1]).to_string())
  }
  if rest == "" {
    None
  } else {
    Some((rest, opens_block))
  }
}

///|
fn parse_inline_class_declaration(line : String) -> (String, String?)? {
  if !line.has_prefix("class ") || !line.has_suffix("}") {
    return None
  }
  match line.find("{") {
    Some(open_idx) => {
      let class_id = trim_owned((try! line[6:open_idx]).to_string())
      let inline_detail = trim_owned(
        (try! line[open_idx + 1:line.length() - 1]).to_string(),
      )
      if class_id == "" {
        None
      } else if inline_detail == "" {
        Some((class_id, None))
      } else {
        Some((class_id, Some(inline_detail)))
      }
    }
    None => None
  }
}

///|
fn parse_class_diagram(lines : Array[String]) -> MermaidGraph {
  let nodes : Map[String, MermaidNode] = {}
  let edges : Array[MermaidEdge] = []
  let details : Map[String, Array[String]] = {}
  let mut current_class : String? = None

  for i in 1..<lines.length() {
    let line = lines[i]
    if line == "{" {
      continue
    }

    match current_class {
      Some(class_id) => {
        if line == "}" {
          current_class = None
          continue
        }
        append_detail(details, class_id, normalize_class_member(line))
        continue
      }
      None => ()
    }

    match parse_inline_class_declaration(line) {
      Some((class_id, inline_detail)) => {
        ensure_node(nodes, { id: class_id, label: class_id, shape: ClassEntity })
        match inline_detail {
          Some(detail) =>
            append_detail(details, class_id, normalize_class_member(detail))
          None => ()
        }
        continue
      }
      None => ()
    }

    match parse_class_declaration(line) {
      Some((class_id, opens_block)) => {
        ensure_node(nodes, { id: class_id, label: class_id, shape: ClassEntity })
        if opens_block {
          current_class = Some(class_id)
        }
        continue
      }
      None => ()
    }

    match parse_relation_parts(line) {
      Some((source, operator, target, label)) => {
        append_relation_edge(
          source,
          operator,
          target,
          label,
          ClassEntity,
          nodes,
          edges,
        )
        continue
      }
      None => ()
    }

    lexmatch line[:] {
      (candidate_part, ":", detail_part) => {
        let candidate = candidate_part.trim().to_string()
        let detail = normalize_class_member(detail_part.trim().to_string())
        if is_plain_identifier(candidate) {
          ensure_node(nodes, {
            id: candidate,
            label: candidate,
            shape: ClassEntity,
          })
          append_detail(details, candidate, detail)
        }
      }
      _ => ()
    }
  }

  apply_details_to_nodes(nodes, details)

  {
    direction: TD,
    nodes,
    edges,
    subgraphs: [],
    class_defs: {},
    class_assignments: {},
    node_styles: {},
    sequence_actor_order: [],
    sequence_actor_kinds: {},
    sequence_blocks: [],
    sequence_notes: [],
    sequence_activation_commands: [],
  }
}

///|
fn parse_er_entity_declaration_line(
  line : String,
  nodes : Map[String, MermaidNode],
) -> String? {
  if !line.has_suffix("{") {
    return None
  }
  let id = trim_owned((try! line[:line.length() - 1]).to_string())
  if id == "" {
    return None
  }
  ensure_node(nodes, { id, label: id, shape: ErEntity })
  Some(id)
}

///|
fn parse_er_diagram(lines : Array[String]) -> MermaidGraph {
  let nodes : Map[String, MermaidNode] = {}
  let edges : Array[MermaidEdge] = []
  let details : Map[String, Array[String]] = {}
  let mut current_entity : String? = None

  for i in 1..<lines.length() {
    let line = lines[i]
    if line == "{" {
      continue
    }

    match current_entity {
      Some(entity_id) => {
        if line == "}" {
          current_entity = None
          continue
        }
        append_detail(details, entity_id, normalize_er_attribute(line))
        continue
      }
      None => ()
    }

    match parse_er_entity_declaration_line(line, nodes) {
      Some(entity_id) => {
        match nodes.get(entity_id) {
          Some(node) =>
            nodes[entity_id] = {
              id: node.id,
              label: node.label,
              shape: ErEntity,
            }
          None => ()
        }
        current_entity = Some(entity_id)
        continue
      }
      None => ()
    }

    match parse_relation_parts(line) {
      Some((source, operator, target, label)) =>
        append_relation_edge(
          source,
          operator,
          target,
          label,
          ErEntity,
          nodes,
          edges,
        )
      None => ()
    }
  }

  apply_details_to_nodes(nodes, details)

  {
    direction: TD,
    nodes,
    edges,
    subgraphs: [],
    class_defs: {},
    class_assignments: {},
    node_styles: {},
    sequence_actor_order: [],
    sequence_actor_kinds: {},
    sequence_blocks: [],
    sequence_notes: [],
    sequence_activation_commands: [],
  }
}

///|
fn parse_flowchart(lines : Array[String]) -> MermaidGraph raise MermaidError {
  let nodes : Map[String, MermaidNode] = {}
  let edges : Array[MermaidEdge] = []
  let subgraphs : Array[MermaidSubgraph] = []
  let subgraph_stack : Array[MermaidSubgraph] = []
  let class_defs : Map[String, Map[String, String]] = {}
  let class_assignments : Map[String, String] = {}
  let node_styles : Map[String, Map[String, String]] = {}
  let known_node_ids : Map[String, Bool] = {}
  let direction = match parse_flow_direction(lines[0]) {
    Some(found) => found
    None =>
      raise ParseFailure(
        "Invalid mermaid header: \"\{lines[0]}\". Expected \"graph TD\", \"flowchart LR\", \"stateDiagram-v2\", etc.",
      )
  }

  for i in 1..<lines.length() {
    let line = lines[i]

    if line.has_prefix("direction ") {
      if subgraph_stack.length() > 0 {
        let token = trim_owned((try! line[10:]).to_string())
        match parse_direction_token_strict(token) {
          Some(parsed_direction) =>
            set_current_subgraph_direction(subgraph_stack, parsed_direction)
          None => ()
        }
      }
      continue
    }

    match parse_subgraph_start_line(line) {
      Some(subgraph) => {
        subgraph_stack.push(subgraph)
        continue
      }
      None => ()
    }

    if line == "end" {
      match subgraph_stack.pop() {
        Some(completed) =>
          if subgraph_stack.length() > 0 {
            append_child_subgraph(subgraph_stack, completed)
          } else {
            subgraphs.push(completed)
          }
        None => ()
      }
      continue
    }

    let touched_node_ids = parse_flow_line(
      line, nodes, edges, class_defs, class_assignments, node_styles,
    )
    let newly_defined_node_ids : Array[String] = []
    for node_id in touched_node_ids {
      if known_node_ids.contains(node_id) {
        continue
      }
      if nodes.contains(node_id) {
        known_node_ids[node_id] = true
        newly_defined_node_ids.push(node_id)
      }
    }
    append_nodes_to_current_subgraph(subgraph_stack, newly_defined_node_ids)
  }

  {
    direction,
    nodes,
    edges,
    subgraphs,
    class_defs,
    class_assignments,
    node_styles,
    sequence_actor_order: [],
    sequence_actor_kinds: {},
    sequence_blocks: [],
    sequence_notes: [],
    sequence_activation_commands: [],
  }
}

///|
/// Parse Mermaid text into the normalized in-memory graph model used by
/// both SVG and ASCII renderers.
///
/// Supported headers:
/// - `graph` / `flowchart`
/// - `stateDiagram` / `stateDiagram-v2`
/// - `sequenceDiagram`
/// - `classDiagram`
/// - `erDiagram`
pub fn parse_mermaid(text : String) -> MermaidGraph raise MermaidError {
  let lines = preprocess_lines(text)
  if lines.length() == 0 {
    raise ParseFailure("Mermaid input is empty")
  }
  let header = lines[0].replace_all(old="\t", new=" ").to_lower()
  if header.has_prefix("graph ") || header.has_prefix("flowchart ") {
    return parse_flowchart(lines)
  }
  if header == "statediagram" || header == "statediagram-v2" {
    return parse_state_diagram(lines)
  }
  if header == "sequencediagram" {
    return parse_sequence_diagram(lines)
  }
  if header == "classdiagram" {
    return parse_class_diagram(lines)
  }
  if header == "erdiagram" {
    return parse_er_diagram(lines)
  }
  raise ParseFailure("Unsupported Mermaid header: \{lines[0]}")
}
