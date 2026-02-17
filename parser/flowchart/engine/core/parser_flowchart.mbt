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
    ("[[:space:]]*" "(?i:graph|flowchart)" "[[:space:]]*") => Some(TD)
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
fn subgraph_push_unique_id(ids : Array[String], id : String) -> Unit {
  if !ids.any(found => found == id) {
    ids.push(id)
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
    subgraph_push_unique_id(node_ids, node_id)
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
fn strip_node_metadata(raw_token : String) -> String {
  let token = raw_token.trim().to_string()
  match token.find("@{") {
    Some(index) =>
      if token.has_suffix("}") {
        @parser_common_engine_core.trim_owned((try! token[:index]).to_string())
      } else {
        token
      }
    None => token
  }
}

///|
fn parse_shape_alias(raw_shape : String) -> @model.NodeShape? {
  match raw_shape.trim().to_lower() {
    "circ" | "circle" => Some(Circle)
    "f-circ" | "filled-circle" | "filledcircle" | "junction" => Some(StateStart)
    "dbl-circ" | "double-circle" | "doublecircle" | "stop" => Some(DoubleCircle)
    _ => None
  }
}

///|
fn parse_node_shape_metadata(raw_token : String) -> @model.NodeShape? {
  let node_part = match raw_token.find(":::") {
    Some(index) => (try! raw_token[:index]).to_string()
    None => raw_token
  }
  let token = node_part.trim().to_string()
  match token.find("@{") {
    Some(start_index) => {
      let after = (try! token[start_index + 2:]).to_string()
      match after.find("}") {
        Some(end_index) => {
          let metadata = @parser_common_engine_core.trim_owned(
            (try! after[:end_index]).to_string(),
          )
          for entry in metadata.split(",") {
            let kv = entry.trim().to_string()
            if kv == "" {
              continue
            }
            match kv.find(":") {
              Some(colon_index) => {
                let key = @parser_common_engine_core.trim_owned(
                  (try! kv[:colon_index]).to_string(),
                )
                if key.to_lower() != "shape" {
                  continue
                }
                let value = @parser_common_engine_core.trim_owned(
                  (try! kv[colon_index + 1:]).to_string(),
                )
                return parse_shape_alias(value)
              }
              None => ()
            }
          }
          None
        }
        None => None
      }
    }
    None => None
  }
}

///|
fn split_node_and_class(raw_token : String) -> (String, String?) {
  lexmatch raw_token[:] {
    (token, ":::", class_name) => {
      let t = strip_node_metadata(token.trim().to_string())
      let c = class_name.trim().to_string()
      if c == "" {
        (t, None)
      } else {
        (t, Some(c))
      }
    }
    _ => (strip_node_metadata(raw_token.trim().to_string()), None)
  }
}

///|
fn parse_node_and_class(raw_token : String) -> (MermaidNode, String?) {
  let (token, class_name) = split_node_and_class(raw_token)
  let parsed = @parser_common_engine_core.parse_node_token(token)
  let node : MermaidNode = match parse_node_shape_metadata(raw_token) {
    Some(shape) => { id: parsed.id, label: parsed.label, shape }
    None => parsed
  }
  (node, class_name)
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
      let part = @parser_common_engine_core.trim_owned(
        (try! segment[start:i]).to_string(),
      )
      if part != "" {
        parts.push(part)
      }
      start = i + 1
    }
  }

  let tail = if start < segment.length() {
    @parser_common_engine_core.trim_owned((try! segment[start:]).to_string())
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
fn is_clean_flow_node_token(raw_token : String) -> Bool {
  let (token, _) = split_node_and_class(raw_token)
  if token == "" {
    return false
  }
  let parsed = @parser_common_engine_core.parse_node_token(token)
  if parsed.shape == Asymmetric &&
    @parser_common_engine_core.is_plain_identifier(parsed.id) &&
    token.has_suffix("]") {
    return true
  }
  let mut square_depth = 0
  let mut round_depth = 0
  let mut curly_depth = 0
  let mut in_single_quote = false
  let mut in_double_quote = false
  for i in 0..<token.length() {
    let unit = token[i]
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
    if square_depth == 0 &&
      round_depth == 0 &&
      curly_depth == 0 &&
      (unit == ' ' || unit == '\t') {
      return false
    }
  }

  match find_top_level_edge_operator(token, edge_operators()) {
    Some(_) => false
    None => true
  }
}

///|
fn is_clean_parallel_node_group(segment : String) -> Bool {
  let parts = split_parallel_node_segments(segment)
  if parts.length() == 0 {
    return false
  }

  for part in parts {
    let trimmed = part.trim().to_string()
    if trimmed == "" {
      return false
    }
    let (token, _) = split_node_and_class(trimmed)
    if !is_clean_flow_node_token(token) {
      return false
    }
  }
  true
}

///|
fn leading_node_token(raw_line : String) -> String {
  let line = @parser_common_engine_core.trim_owned(raw_line)
  if line == "" {
    return ""
  }

  let mut square_depth = 0
  let mut round_depth = 0
  let mut curly_depth = 0
  let mut in_single_quote = false
  let mut in_double_quote = false
  let mut end_index = line.length()

  for i in 0..<line.length() {
    let unit = line[i]
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
    if (unit == ' ' || unit == '\t') &&
      square_depth == 0 &&
      round_depth == 0 &&
      curly_depth == 0 {
      end_index = i
      break
    }
  }

  if end_index == 0 {
    ""
  } else {
    (try! line[:end_index]).to_string()
  }
}

///|
fn parse_leading_node_entry(line : String) -> (MermaidNode, String?)? {
  let trimmed = @parser_common_engine_core.trim_owned(line)
  if trimmed == "" {
    return None
  }

  let token = leading_node_token(trimmed)
  if token == "" {
    None
  } else {
    Some(parse_node_and_class(token))
  }
}

///|
fn ensure_leading_node_only(
  line : String,
  nodes : Map[String, MermaidNode],
  class_assignments : Map[String, String],
) -> Array[String] {
  let touched_node_ids : Array[String] = []
  match parse_leading_node_entry(line) {
    Some(entry) => {
      let touched = ensure_nodes_from_entries(nodes, class_assignments, [entry])
      push_unique_node_ids(touched_node_ids, touched)
    }
    None => ()
  }
  touched_node_ids
}

///|
fn flow_edge_operator_specs() -> Array[(String, EdgeStyle, Bool, Bool)] {
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
fn edge_operators() -> Array[EdgeOp] {
  let operators : Array[EdgeOp] = []
  for spec in flow_edge_operator_specs() {
    let (symbol, style, has_arrow_start, has_arrow_end) = spec
    operators.push({ symbol, style, has_arrow_start, has_arrow_end })
  }
  operators
}

///|
fn top_level_operator_at(
  line : String,
  index : Int,
  operators : Array[EdgeOp],
) -> EdgeOp? {
  let mut found : EdgeOp? = None
  for op in operators {
    let op_len = op.symbol.length()
    if index + op_len > line.length() {
      continue
    }
    let slice = (try! line[index:index + op_len]).to_string()
    if slice != op.symbol {
      continue
    }
    match found {
      Some(best) =>
        if op.symbol.length() > best.symbol.length() {
          found = Some(op)
        }
      None => found = Some(op)
    }
  }
  found
}

///|
fn find_top_level_edge_operator(
  line : String,
  operators : Array[EdgeOp],
) -> FoundEdgeOp? {
  let mut square_depth = 0
  let mut round_depth = 0
  let mut curly_depth = 0
  let mut in_single_quote = false
  let mut in_double_quote = false

  for i in 0..<line.length() {
    let unit = line[i]
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
    if square_depth != 0 || round_depth != 0 || curly_depth != 0 {
      continue
    }
    match top_level_operator_at(line, i, operators) {
      Some(op) => return Some({ op, index: i })
      None => ()
    }
  }
  None
}

///|
fn mid_label_left_marker(edge_symbol : String) -> String? {
  match edge_symbol {
    "<==>" => Some("<==")
    "<-.->" => Some("<-.")
    "<-->" => Some("<--")
    "==>" => Some("==")
    "-.->" => Some("-.")
    "-->" => Some("--")
    _ => None
  }
}

///|
fn top_level_last_index(text : String, marker : String) -> Int? {
  let mut square_depth = 0
  let mut round_depth = 0
  let mut curly_depth = 0
  let mut in_single_quote = false
  let mut in_double_quote = false
  let mut found : Int? = None

  for i in 0..<text.length() {
    let unit = text[i]
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
    if square_depth != 0 || round_depth != 0 || curly_depth != 0 {
      continue
    }
    let marker_len = marker.length()
    if i + marker_len > text.length() {
      continue
    }
    if (try! text[i:i + marker_len]).to_string() == marker {
      found = Some(i)
    }
  }
  found
}

///|
fn parse_mid_label_edge(
  line : String,
) -> (
  Array[(MermaidNode, String?)],
  EdgeOp,
  String,
  Array[(MermaidNode, String?)],
)? {
  let candidates : Array[EdgeOp] = []
  for op in edge_operators() {
    if op.has_arrow_end {
      candidates.push(op)
    }
  }
  match find_top_level_edge_operator(line, candidates) {
    Some(found) =>
      match mid_label_left_marker(found.op.symbol) {
        Some(marker) => {
          let lhs = @parser_common_engine_core.trim_owned(
            (try! line[:found.index]).to_string(),
          )
          let rhs = @parser_common_engine_core.trim_owned(
            (try! line[found.index + found.op.symbol.length():]).to_string(),
          )
          if !is_clean_parallel_node_group(rhs) {
            return None
          }
          match top_level_last_index(lhs, marker) {
            Some(marker_index) => {
              let source_segment = @parser_common_engine_core.trim_owned(
                (try! lhs[:marker_index]).to_string(),
              )
              let label = @parser_common_engine_core.trim_owned(
                (try! lhs[marker_index + marker.length():]).to_string(),
              )
              if label == "" || !is_clean_parallel_node_group(source_segment) {
                return None
              }
              Some(
                (
                  split_parallel_nodes_with_classes(source_segment),
                  found.op,
                  label,
                  split_parallel_nodes_with_classes(rhs),
                ),
              )
            }
            None => None
          }
        }
        None => None
      }
    None => None
  }
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
  debug_inspect(
    split_node_and_class("start@{shape: f-circ}"),
    content=(
      #|("start", None)
    ),
  )
  debug_inspect(
    split_node_and_class("accept@{shape: dbl-circ}:::final"),
    content=(
      #|("accept", Some("final"))
    ),
  )
}

///|
test "parse_node_shape_metadata" {
  assert_true(parse_node_shape_metadata("A@{shape: circ}") == Some(Circle))
  assert_true(
    parse_node_shape_metadata("start@{ shape: f-circ, label: \"J\" }") ==
    Some(StateStart),
  )
  assert_true(
    parse_node_shape_metadata("end@{shape: dbl-circ}:::done") ==
    Some(DoubleCircle),
  )
  assert_true(
    parse_node_shape_metadata("A@{shape: junction}") == Some(StateStart),
  )
  assert_true(parse_node_shape_metadata("A@{shape: unknown}") == None)
  assert_true(parse_node_shape_metadata("A") == None)
}

///|
test "parse_node_and_class applies shape metadata" {
  let (start_node, start_class) = parse_node_and_class("start@{shape: f-circ}")
  assert_eq(start_node.id, "start")
  assert_true(start_node.shape == StateStart)
  assert_eq(start_class, None)

  let (accept_node, accept_class) = parse_node_and_class(
    "accept@{shape: dbl-circ}:::final",
  )
  assert_eq(accept_node.id, "accept")
  assert_true(accept_node.shape == DoubleCircle)
  assert_eq(accept_class, Some("final"))

  let (normal_node, normal_class) = parse_node_and_class("q0@{shape: circ}")
  assert_eq(normal_node.id, "q0")
  assert_true(normal_node.shape == Circle)
  assert_eq(normal_class, None)
}

///|
test "parse_flow_direction" {
  // basic flowchart + direction
  assert_true(parse_flow_direction("flowchart LR") == Some(LR))
  assert_true(parse_flow_direction("graph TD") == Some(TD))
  // case-insensitive keyword
  assert_true(parse_flow_direction("Flowchart TB") == Some(TB))
  assert_true(parse_flow_direction("GRAPH RL") == Some(RL))
  // extra whitespace
  assert_true(parse_flow_direction("  flowchart   BT  ") == Some(BT))
  // tab replaced
  assert_true(parse_flow_direction("flowchart\tLR") == Some(LR))
  // missing direction defaults to TD
  assert_true(parse_flow_direction("flowchart") == Some(TD))
  assert_true(parse_flow_direction("flowchart ") == Some(TD))
  assert_true(parse_flow_direction("graph") == Some(TD))
  // invalid direction token
  assert_true(parse_flow_direction("flowchart XX") == None)
  // unrelated string
  assert_true(parse_flow_direction("sequenceDiagram") == None)
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
test "parse_flow_line parses metadata nodes and middle labels" {
  let nodes : Map[String, MermaidNode] = {}
  let edges : Array[MermaidEdge] = []
  let class_defs : Map[String, Map[String, String]] = {}
  let class_assignments : Map[String, String] = {}
  let node_styles : Map[String, Map[String, String]] = {}

  ignore(
    parse_flow_line(
      "start@{shape: f-circ} --- 0", nodes, edges, class_defs, class_assignments,
      node_styles,
    ),
  )
  assert_true(nodes.contains("start"))
  assert_true(nodes.contains("0"))
  assert_eq(edges.length(), 1)
  assert_eq(edges[0].source, "start")
  assert_eq(edges[0].target, "0")
  assert_eq(edges[0].label, None)

  ignore(
    parse_flow_line(
      "0 -- [a-b] --> 3", nodes, edges, class_defs, class_assignments, node_styles,
    ),
  )
  assert_true(nodes.contains("0"))
  assert_true(nodes.contains("3"))
  assert_eq(edges.length(), 2)
  assert_eq(edges[1].source, "0")
  assert_eq(edges[1].target, "3")
  assert_eq(edges[1].label, Some("[a-b]"))

  ignore(
    parse_flow_line(
      "5 --- #0@{shape: dbl-circ}", nodes, edges, class_defs, class_assignments,
      node_styles,
    ),
  )
  assert_true(nodes.contains("5"))
  assert_true(nodes.contains("#0"))
  assert_eq(edges.length(), 3)
  assert_eq(edges[2].source, "5")
  assert_eq(edges[2].target, "#0")
  assert_eq(edges[2].label, None)

  ignore(
    parse_flow_line(
      "A --> B", nodes, edges, class_defs, class_assignments, node_styles,
    ),
  )
  assert_true(nodes.contains("A"))
  assert_true(nodes.contains("B"))
  assert_eq(edges.length(), 4)
}

///|
test "parse_flow_line keeps malformed edge statements non-fatal" {
  let nodes : Map[String, MermaidNode] = {}
  let edges : Array[MermaidEdge] = []
  let class_defs : Map[String, Map[String, String]] = {}
  let class_assignments : Map[String, String] = {}
  let node_styles : Map[String, Map[String, String]] = {}

  ignore(
    parse_flow_line(
      "0 -- [a-b] -->", nodes, edges, class_defs, class_assignments, node_styles,
    ),
  )
  assert_true(nodes.contains("0"))
  assert_eq(edges.length(), 0)

  ignore(
    parse_flow_line(
      "A[Label contains --> text]", nodes, edges, class_defs, class_assignments,
      node_styles,
    ),
  )
  assert_eq(edges.length(), 0)
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
  let rest = @parser_common_engine_core.trim_owned((try! line[6:]).to_string())
  match rest.rev_find(" ") {
    Some(idx) => {
      let node_list = @parser_common_engine_core.trim_owned(
        (try! rest[:idx]).to_string(),
      )
      let class_name = @parser_common_engine_core.trim_owned(
        (try! rest[idx + 1:]).to_string(),
      )
      if class_name == "" || node_list == "" {
        return
      }
      for node_part in node_list.split(",") {
        let node_id = @parser_common_engine_core.trim_owned(
          node_part.to_string(),
        )
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
    .map(part => @parser_common_engine_core.trim_owned(part.to_string()))
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
  let rest = @parser_common_engine_core.trim_owned((try! line[9:]).to_string())
  if rest == "" {
    return None
  }

  match rest.find("[") {
    Some(open_idx) =>
      if rest.has_suffix("]") {
        let raw_id = @parser_common_engine_core.trim_owned(
          (try! rest[:open_idx]).to_string(),
        )
        let raw_label = @parser_common_engine_core.trim_owned(
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
  match parse_mid_label_edge(line) {
    Some((source_entries, op, label, target_entries)) => {
      let touched_node_ids : Array[String] = []
      let sources = ensure_nodes_from_entries(
        nodes, class_assignments, source_entries,
      )
      push_unique_node_ids(touched_node_ids, sources)
      let targets = ensure_nodes_from_entries(
        nodes, class_assignments, target_entries,
      )
      push_unique_node_ids(touched_node_ids, targets)
      append_edges(sources, targets, op, Some(label), edges)
      return touched_node_ids
    }
    None => ()
  }

  match find_top_level_edge_operator(line, edge_operators()) {
    Some(found) => {
      let touched_node_ids : Array[String] = []
      let left_segment = @parser_common_engine_core.trim_owned(
        (try! line[:found.index]).to_string(),
      )
      if !is_clean_parallel_node_group(left_segment) {
        return ensure_leading_node_only(line, nodes, class_assignments)
      }
      let mut current_sources = ensure_nodes_from_entries(
        nodes,
        class_assignments,
        split_parallel_nodes_with_classes(left_segment),
      )
      push_unique_node_ids(touched_node_ids, current_sources)

      let mut current_op = found.op
      let mut rhs = @parser_common_engine_core.trim_owned(
        (try! line[found.index + found.op.symbol.length():]).to_string(),
      )

      let mut done = false
      while !done {
        let (label, rhs_without_label) = parse_label_and_target(rhs)
        match
          find_top_level_edge_operator(rhs_without_label, edge_operators()) {
          Some(next_found) => {
            let target_segment = @parser_common_engine_core.trim_owned(
              (try! rhs_without_label[:next_found.index]).to_string(),
            )
            if !is_clean_parallel_node_group(target_segment) {
              done = true
              continue
            }
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
            rhs = @parser_common_engine_core.trim_owned(
              (try! rhs_without_label[next_found.index +
              next_found.op.symbol.length():]).to_string(),
            )
          }
          None => {
            if !is_clean_parallel_node_group(rhs_without_label) {
              done = true
              continue
            }
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
/// Parses flowchart body lines into a `MermaidGraph`.
pub fn parse_flowchart(
  lines : Array[String],
) -> MermaidGraph raise MermaidError {
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
        let token = @parser_common_engine_core.trim_owned(
          (try! line[10:]).to_string(),
        )
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
    diagram_kind: Flowchart,
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
