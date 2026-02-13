///|
fn parse_state_token(
  token : String,
  is_source : Bool,
  nodes : Map[String, MermaidNode],
  start_counter : Int,
  end_counter : Int,
) -> (String, Int, Int) {
  let trimmed = @parser_common_engine_core.trim_owned(token)
  if trimmed == "[*]" {
    if is_source {
      let next = start_counter + 1
      let id = "state_start_\{next}"
      @parser_common_engine_core.ensure_node(nodes, {
        id,
        label: "",
        shape: StateStart,
      })
      (id, next, end_counter)
    } else {
      let next = end_counter + 1
      let id = "state_end_\{next}"
      @parser_common_engine_core.ensure_node(nodes, {
        id,
        label: "",
        shape: StateEnd,
      })
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
    @parser_common_engine_core.ensure_node(nodes, node)
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
        @parser_common_engine_core.ensure_node(nodes, {
          id,
          label,
          shape: Rounded,
        })
        @parser_common_engine_core.append_nodes_to_current_subgraph(
          composite_stack,
          [id],
        )
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
      @parser_common_engine_core.ensure_node(nodes, node)
      @parser_common_engine_core.append_nodes_to_current_subgraph(
        composite_stack,
        [node.id],
      )
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
  @parser_common_engine_core.append_nodes_to_current_subgraph(composite_stack, [
    node_id,
  ])
}

///|
fn parse_state_description_line(
  state_id : String,
  description : String,
  nodes : Map[String, MermaidNode],
) -> Bool {
  let id = @parser_common_engine_core.trim_owned(state_id)
  let label = @parser_common_engine_core.trim_owned(description)
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
    if line.has_prefix("direction ") {
      let token = @parser_common_engine_core.trim_owned(
        (try! line[10:]).to_string(),
      )
      match @parser_common_engine_core.parse_direction_token_strict(token) {
        Some(parsed_direction) =>
          if composite_stack.length() > 0 {
            @parser_common_engine_core.set_current_subgraph_direction(
              composite_stack, parsed_direction,
            )
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
            @parser_common_engine_core.append_child_subgraph(
              composite_stack, completed,
            )
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
      (lhs, ":", rhs) => (lhs.trim().to_string(), Some(rhs.trim().to_string()))
      _ => (line, None)
    }

    match find_edge_operator(transition_line) {
      Some(found) => {
        let left = @parser_common_engine_core.trim_owned(
          (try! transition_line[:found.index]).to_string(),
        )
        let right = @parser_common_engine_core.trim_owned(
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
        @parser_common_engine_core.append_nodes_to_current_subgraph(
          composite_stack,
          [source_id, target_id],
        )
      }
      None =>
        match edge_label {
          Some(description) =>
            if parse_state_description_line(transition_line, description, nodes) {
              append_state_node_to_current_composite(
                composite_stack,
                @parser_common_engine_core.trim_owned(transition_line),
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
test "strip_quotes" {
  assert_eq(strip_quotes("\"hello\""), "hello")
  assert_eq(strip_quotes("\"\""), "")
  assert_eq(strip_quotes("noquotes"), "noquotes")
  assert_eq(strip_quotes("\"partial"), "\"partial")
  assert_eq(strip_quotes(""), "")
}
