///|
fn parse_flow_direction(header : String) -> Direction? {
  let normalized = header.replace_all(old="\t", new=" ")
  lexmatch normalized[:] {
    (
      "[[:space:]]*"
      "(?i:graph|flowchart)"
      "[[:space:]]+"
      ("[^[:space:]]+" as dir)
      "[[:space:]]*"
    ) => parse_direction_token_strict(dir.to_string())
    _ => None
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
fn find_earliest_edge_operator(line : String) -> FoundEdgeOp? {
  find_earliest_operator(line, edge_operators())
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
test "parse_flow_direction" {
  // basic flowchart + direction
  assert_eq(parse_flow_direction("flowchart LR"), Some(LR))
  assert_eq(parse_flow_direction("graph TD"), Some(TD))
  // case-insensitive keyword
  assert_eq(parse_flow_direction("Flowchart TB"), Some(TB))
  assert_eq(parse_flow_direction("GRAPH RL"), Some(RL))
  // extra whitespace
  assert_eq(parse_flow_direction("  flowchart   BT  "), Some(BT))
  // tab replaced
  assert_eq(parse_flow_direction("flowchart\tLR"), Some(LR))
  // missing direction
  assert_eq(parse_flow_direction("flowchart"), None)
  assert_eq(parse_flow_direction("flowchart "), None)
  // invalid direction token
  assert_eq(parse_flow_direction("flowchart XX"), None)
  // unrelated string
  assert_eq(parse_flow_direction("sequenceDiagram"), None)
}

///|
test "parse_style_properties" {
  // basic key:value
  let props = parse_style_properties("fill: red, stroke: blue")
  assert_eq(props.get("fill"), Some("red"))
  assert_eq(props.get("stroke"), Some("blue"))
  // single property
  let props2 = parse_style_properties("color: green")
  assert_eq(props2.get("color"), Some("green"))
  // empty string
  let props3 = parse_style_properties("")
  assert_eq(props3.length(), 0)
  // trailing comma (empty part ignored)
  let props4 = parse_style_properties("fill: red,")
  assert_eq(props4.length(), 1)
  // no colon (no match, skipped)
  let props5 = parse_style_properties("invalidprop")
  assert_eq(props5.length(), 0)
  // whitespace around key/value
  let props6 = parse_style_properties("  fill :  red  ")
  assert_eq(props6.get("fill"), Some("red"))
}

///|
test "is_subgraph_id_token" {
  assert_true(is_subgraph_id_token("abc"))
  assert_true(is_subgraph_id_token("ABC123"))
  assert_true(is_subgraph_id_token("my_id"))
  assert_true(is_subgraph_id_token("a-b"))
  assert_true(is_subgraph_id_token("A"))
  assert_false(is_subgraph_id_token(""))
  assert_false(is_subgraph_id_token("has space"))
  assert_false(is_subgraph_id_token("a.b"))
  assert_false(is_subgraph_id_token("a:b"))
  assert_false(is_subgraph_id_token("a[b]"))
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
