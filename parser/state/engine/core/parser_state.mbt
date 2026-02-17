///|
fn parse_state_token(
  token : String,
  is_source : Bool,
  nodes : Map[String, MermaidNode],
  start_counter : Int,
  end_counter : Int,
) -> (String, Int, Int) {
  let trimmed = token.trim().to_string()
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
    let parsed = @parser_common_engine_core.parse_node_token(trimmed)
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
fn push_unique_id(ids : Array[String], id : String) -> Unit {
  if !ids.any(found => found == id) {
    ids.push(id)
  }
}

///|
fn ensure_node(nodes : Map[String, MermaidNode], node : MermaidNode) -> Unit {
  if !nodes.contains(node.id) {
    nodes[node.id] = node
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

///|
fn parse_state_declaration(
  line : String,
  nodes : Map[String, MermaidNode],
  composite_stack : Array[MermaidSubgraph],
) -> Bool {
  let rest = lexmatch line[:] {
    ("state ", state_rest) => state_rest.trim()
    _ => return false
  }
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
      let parsed = @parser_common_engine_core.parse_node_token(rest_str)
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
  true
}

///|
fn parse_state_composite_start_line(line : String) -> MermaidSubgraph? {
  let rest = if line is [.. "state ", .. raw_rest, .. "{"] {
    raw_rest.trim()
  } else {
    return None
  }
  if rest.length() == 0 {
    return None
  }

  lexmatch rest {
    (raw_label, " as ", id_part) => {
      let id = id_part.trim().to_string()
      if id == "" || !@parser_common_engine_core.is_plain_identifier(id) {
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
  if !@parser_common_engine_core.is_plain_identifier(rest_str) {
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
  let id = state_id.trim().to_string()
  let label = description.trim().to_string()
  if id == "" ||
    label == "" ||
    !@parser_common_engine_core.is_plain_identifier(id) {
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
fn parse_state_standalone_line(
  line : String,
  nodes : Map[String, MermaidNode],
  composite_stack : Array[MermaidSubgraph],
) -> Bool {
  let candidate = line.trim().to_string()
  if candidate == "" ||
    !@parser_common_engine_core.is_plain_identifier(candidate) {
    return false
  }

  ensure_node(nodes, { id: candidate, label: candidate, shape: Rounded })
  append_state_node_to_current_composite(composite_stack, candidate)
  true
}

///|
/// Parses state diagram body lines into a `MermaidGraph`.
pub fn parse_state_diagram(lines : Array[String]) -> MermaidGraph {
  let nodes : Map[String, MermaidNode] = {}
  let edges : Array[MermaidEdge] = []
  let subgraphs : Array[MermaidSubgraph] = []
  let composite_stack : Array[MermaidSubgraph] = []
  let mut direction = Direction::TD
  let mut start_counter = 0
  let mut end_counter = 0

  for i in 1..<lines.length() {
    let line = lines[i]
    lexmatch line[:] {
      ("direction ", direction_token) => {
        let token = direction_token.to_string().trim().to_string()
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
      _ => ()
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

    if parse_state_declaration(line, nodes, composite_stack) {
      continue
    }
    if line == "{" {
      continue
    }

    let (transition_line, edge_label) = lexmatch line[:] {
      (lhs, ":", rhs) => (lhs.trim().to_string(), Some(rhs.trim().to_string()))
      _ => (line, None)
    }

    match find_edge_operator(transition_line) {
      Some(found) => {
        let left = (try! transition_line[:found.index])
          .to_string()
          .trim()
          .to_string()
        let right = (try! transition_line[found.index + found.op.symbol.length():])
          .to_string()
          .trim()
          .to_string()
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
                transition_line.trim().to_string(),
              )
            }
          None =>
            ignore(parse_state_standalone_line(line, nodes, composite_stack))
        }
    }
  }

  {
    diagram_kind: State,
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
test "strip_quotes" {
  assert_eq(strip_quotes("\"hello\""), "hello")
  assert_eq(strip_quotes("\"\""), "")
  assert_eq(strip_quotes("noquotes"), "noquotes")
  assert_eq(strip_quotes("\"partial"), "\"partial")
  assert_eq(strip_quotes(""), "")
}
