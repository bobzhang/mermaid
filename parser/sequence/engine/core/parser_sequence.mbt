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
fn parse_sequence_participant_declaration(
  line : String,
  nodes : Map[String, MermaidNode],
  actor_order : Array[String],
  actor_kinds : Map[String, SequenceParticipantKind],
) -> Bool {
  let lower_line = line.to_lower()
  let mut rest = ""
  let kind = if lower_line.has_prefix("participant ") {
    rest = @parser_common_engine_core.trim_owned((try! line[12:]).to_string())
    SequenceParticipantKind::Participant
  } else if lower_line.has_prefix("actor ") {
    rest = @parser_common_engine_core.trim_owned((try! line[6:]).to_string())
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
fn parse_sequence_block_header(line : String) -> (SequenceBlockType, String)? {
  lexmatch line[:] {
    "(?i:loop)" => Some((Loop, ""))
    ("(?i:loop) ", rest) => Some((Loop, rest.trim().to_string()))
    "(?i:alt)" => Some((Alt, ""))
    ("(?i:alt) ", rest) => Some((Alt, rest.trim().to_string()))
    "(?i:opt)" => Some((Opt, ""))
    ("(?i:opt) ", rest) => Some((Opt, rest.trim().to_string()))
    "(?i:par)" => Some((Par, ""))
    ("(?i:par) ", rest) => Some((Par, rest.trim().to_string()))
    "(?i:critical)" => Some((Critical, ""))
    ("(?i:critical) ", rest) => Some((Critical, rest.trim().to_string()))
    "(?i:break)" => Some((Break, ""))
    ("(?i:break) ", rest) => Some((Break, rest.trim().to_string()))
    "(?i:rect)" => Some((Rect, ""))
    ("(?i:rect) ", rest) => Some((Rect, rest.trim().to_string()))
    _ => None
  }
}

///|
fn parse_sequence_divider_label(line : String) -> String? {
  lexmatch line[:] {
    "(?i:else)" => Some("")
    ("(?i:else) ", rest) => Some(rest.trim().to_string())
    "(?i:and)" => Some("")
    ("(?i:and) ", rest) => Some(rest.trim().to_string())
    _ => None
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
        ("(?i:right of) ", rest) => (Right, rest.trim().to_string())
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
  match find_earliest_operator(line, sequence_edge_operators()) {
    Some(found) => {
      let source = @parser_common_engine_core.trim_owned(
        (try! line[:found.index]).to_string(),
      )
      let rhs = @parser_common_engine_core.trim_owned(
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
        @parser_common_engine_core.trim_owned((try! raw_target[1:]).to_string())
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
/// Parses sequence diagram body lines into a `MermaidGraph`.
pub fn parse_sequence_diagram(lines : Array[String]) -> MermaidGraph {
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
    diagram_kind: Sequence,
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
test "parse_sequence_block_header" {
  // exact keyword, no label
  assert_eq(parse_sequence_block_header("loop"), Some((Loop, "")))
  assert_eq(parse_sequence_block_header("alt"), Some((Alt, "")))
  assert_eq(parse_sequence_block_header("opt"), Some((Opt, "")))
  assert_eq(parse_sequence_block_header("par"), Some((Par, "")))
  assert_eq(parse_sequence_block_header("critical"), Some((Critical, "")))
  assert_eq(parse_sequence_block_header("break"), Some((Break, "")))
  assert_eq(parse_sequence_block_header("rect"), Some((Rect, "")))
  // keyword with label
  assert_eq(
    parse_sequence_block_header("loop Every minute"),
    Some((Loop, "Every minute")),
  )
  assert_eq(
    parse_sequence_block_header("alt Successful case"),
    Some((Alt, "Successful case")),
  )
  assert_eq(
    parse_sequence_block_header("opt Optional path"),
    Some((Opt, "Optional path")),
  )
  // case-insensitive
  assert_eq(
    parse_sequence_block_header("LOOP big loop"),
    Some((Loop, "big loop")),
  )
  assert_eq(parse_sequence_block_header("Loop"), Some((Loop, "")))
  assert_eq(parse_sequence_block_header("ALT"), Some((Alt, "")))
  assert_eq(
    parse_sequence_block_header("Critical critical section"),
    Some((Critical, "critical section")),
  )
  assert_eq(
    parse_sequence_block_header("BREAK when error"),
    Some((Break, "when error")),
  )
  assert_eq(
    parse_sequence_block_header("Rect rgb(200,150,255)"),
    Some((Rect, "rgb(200,150,255)")),
  )
  // label with extra spaces trimmed
  assert_eq(
    parse_sequence_block_header("par   parallel task  "),
    Some((Par, "parallel task")),
  )
  // not a keyword
  assert_eq(parse_sequence_block_header("looping"), None)
  assert_eq(parse_sequence_block_header("alternative"), None)
  assert_eq(parse_sequence_block_header("something else"), None)
  assert_eq(parse_sequence_block_header(""), None)
}

///|
test "parse_sequence_divider_label" {
  // exact keyword, no label
  assert_eq(parse_sequence_divider_label("else"), Some(""))
  assert_eq(parse_sequence_divider_label("and"), Some(""))
  // keyword with label
  assert_eq(parse_sequence_divider_label("else Error case"), Some("Error case"))
  assert_eq(
    parse_sequence_divider_label("and Another parallel"),
    Some("Another parallel"),
  )
  // case-insensitive
  assert_eq(parse_sequence_divider_label("ELSE"), Some(""))
  assert_eq(parse_sequence_divider_label("Else fallback"), Some("fallback"))
  assert_eq(parse_sequence_divider_label("AND"), Some(""))
  assert_eq(parse_sequence_divider_label("And second"), Some("second"))
  // extra spaces in label trimmed
  assert_eq(parse_sequence_divider_label("else   spaced  "), Some("spaced"))
  // not a keyword
  assert_eq(parse_sequence_divider_label("otherwise"), None)
  assert_eq(parse_sequence_divider_label(""), None)
  assert_eq(parse_sequence_divider_label("elseif"), None)
  assert_eq(parse_sequence_divider_label("android"), None)
}
