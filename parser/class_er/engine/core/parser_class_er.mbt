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
    .map(part => @parser_common_engine_core.trim_owned(part.to_string()))
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
  .map(part => @parser_common_engine_core.trim_owned(part.to_string()))
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
      body = @parser_common_engine_core.trim_owned(
        (try! normalized[:quote_idx]).to_string(),
      )
      comment = @parser_common_engine_core.trim_owned(
        (try! normalized[quote_idx:]).to_string(),
      )
    }
    None => ()
  }

  let parts = body
    .split(" ")
    .map(part => @parser_common_engine_core.trim_owned(part.to_string()))
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
    @parser_common_engine_core.trim_owned((try! trimmed[1:]).to_string())
  }
  if body == "" {
    return trimmed
  }

  if body.contains("(") && body.contains(")") {
    match (body.find("("), body.find(")")) {
      (Some(open_idx), Some(close_idx)) => {
        let name = @parser_common_engine_core.trim_owned(
          (try! body[:open_idx]).to_string(),
        )
        let return_type = @parser_common_engine_core.trim_owned(
          (try! body[close_idx + 1:]).to_string(),
        )
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
    .map(part => @parser_common_engine_core.trim_owned(part.to_string()))
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
fn append_relation_edge(
  source : String,
  operator : String,
  target : String,
  label : String?,
  default_shape : NodeShape,
  nodes : Map[String, MermaidNode],
  edges : Array[MermaidEdge],
) -> Unit {
  @parser_common_engine_core.ensure_node(nodes, {
    id: source,
    label: source,
    shape: default_shape,
  })
  @parser_common_engine_core.ensure_node(nodes, {
    id: target,
    label: target,
    shape: default_shape,
  })
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
  let mut rest = @parser_common_engine_core.trim_owned(
    (try! line[6:]).to_string(),
  )
  let opens_block = rest.has_suffix("{")
  if rest.has_suffix("{") {
    rest = @parser_common_engine_core.trim_owned(
      (try! rest[:rest.length() - 1]).to_string(),
    )
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
      let class_id = @parser_common_engine_core.trim_owned(
        (try! line[6:open_idx]).to_string(),
      )
      let inline_detail = @parser_common_engine_core.trim_owned(
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
/// Parses class diagram body lines into a `MermaidGraph`.
pub fn parse_class_diagram(lines : Array[String]) -> MermaidGraph {
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
        @parser_common_engine_core.ensure_node(nodes, {
          id: class_id,
          label: class_id,
          shape: ClassEntity,
        })
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
        @parser_common_engine_core.ensure_node(nodes, {
          id: class_id,
          label: class_id,
          shape: ClassEntity,
        })
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
        if @parser_common_engine_core.is_plain_identifier(candidate) {
          @parser_common_engine_core.ensure_node(nodes, {
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
  let id = @parser_common_engine_core.trim_owned(
    (try! line[:line.length() - 1]).to_string(),
  )
  if id == "" {
    return None
  }
  @parser_common_engine_core.ensure_node(nodes, {
    id,
    label: id,
    shape: ErEntity,
  })
  Some(id)
}

///|
/// Parses ER diagram body lines into a `MermaidGraph`.
pub fn parse_er_diagram(lines : Array[String]) -> MermaidGraph {
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
test "parse_relation_parts" {
  // basic relation: A -- B
  let r1 = parse_relation_parts("A -- B")
  assert_eq(r1, Some(("A", "--", "B", None)))
  // relation with label
  let r2 = parse_relation_parts("A -- B : label text")
  assert_eq(r2, Some(("A", "--", "B", Some("label text"))))
  // dotted relation
  let r3 = parse_relation_parts("A .. B")
  assert_eq(r3, Some(("A", "..", "B", None)))
  // arrow relation
  let r4 = parse_relation_parts("A --> B")
  assert_eq(r4, Some(("A", "-->", "B", None)))
  // too few parts
  assert_eq(parse_relation_parts("A B"), None)
  assert_eq(parse_relation_parts("A"), None)
  // empty label after colon is None
  let r5 = parse_relation_parts("A -- B :")
  assert_eq(r5, Some(("A", "--", "B", None)))
}
