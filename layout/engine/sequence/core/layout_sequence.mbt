///|
fn option_int_or(value : Int?, fallback : Int) -> Int {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
fn resolve_padding(options : RenderOptions) -> Int {
  option_int_or(options.padding, 40)
}

///|
fn merge_style(
  target : Map[String, String],
  style : Map[String, String]?,
) -> Unit {
  match style {
    Some(found) =>
      for entry in found.to_array() {
        let (key, value) = entry
        target[key] = value
      }
    None => ()
  }
}

///|
fn resolve_inline_style(
  graph : MermaidGraph,
  node_id : String,
) -> Map[String, String]? {
  let resolved : Map[String, String] = {}
  let class_style = match graph.class_assignments.get(node_id) {
    Some(class_name) => graph.class_defs.get(class_name)
    None => None
  }

  merge_style(resolved, class_style)
  merge_style(resolved, graph.node_styles.get(node_id))

  if resolved.length() == 0 {
    None
  } else {
    Some(resolved)
  }
}

///|
fn sequence_edge_points(
  source : PositionedNode,
  target : PositionedNode,
  y : Int,
) -> Array[Point] {
  if source.id == target.id {
    let start_x = source.x + source.width / 2
    let loop_x = start_x + 36
    let loop_bottom = y + 24
    [
      { x: start_x, y },
      { x: loop_x, y },
      { x: loop_x, y: loop_bottom },
      { x: start_x, y: loop_bottom },
    ]
  } else {
    let moving_right = target.x >= source.x
    let start_x = source.x +
      (if moving_right { source.width / 2 } else { -source.width / 2 })
    let end_x = target.x +
      (if moving_right { -target.width / 2 } else { target.width / 2 })
    [{ x: start_x, y }, { x: end_x, y }]
  }
}

///|
fn sequence_text_width(text : String) -> Int {
  text.length() * 8
}

///|
fn sequence_note_width(text : String, base : Int, padding : Int) -> Int {
  let lines = text.split("\n").map(part => part.to_string()).to_array()
  let mut longest = 0
  for line in lines {
    longest = longest.max(sequence_text_width(line))
  }
  base.max(longest + padding * 2)
}

///|
fn sequence_operator_has_suffix(edge : MermaidEdge, suffix : String) -> Bool {
  match edge.relation_operator {
    Some(op) => op.has_suffix(suffix)
    None => false
  }
}

///|
fn sequence_message_label_bounds(
  edge : MermaidEdge,
  actor_index : Map[String, Int],
  actor_center_x : Array[Int],
) -> (Int, Int)? {
  match edge.label {
    Some(label) =>
      match (actor_index.get(edge.source), actor_index.get(edge.target)) {
        (Some(source_idx), Some(target_idx)) => {
          let width = sequence_text_width(label)
          if source_idx == target_idx {
            let left = actor_center_x[source_idx] + 36
            Some((left, left + width))
          } else {
            let mid = (actor_center_x[source_idx] + actor_center_x[target_idx]) /
              2
            let left = mid - width / 2
            Some((left, left + width))
          }
        }
        _ => None
      }
    None => None
  }
}

///|
fn sequence_divider_default_offset() -> Int {
  28
}

///|
fn sequence_divider_overlap_offset() -> Int {
  36
}

///|
fn sequence_divider_offset_for(
  block_left : Int,
  divider_label : String,
  divider_index : Int,
  edges : Array[MermaidEdge],
  actor_index : Map[String, Int],
  actor_center_x : Array[Int],
) -> Int {
  if divider_label == "" || divider_index < 0 || divider_index >= edges.length() {
    return sequence_divider_default_offset()
  }
  let divider_text = "[\{divider_label}]"
  let divider_left = block_left + 8
  let divider_right = divider_left + sequence_text_width(divider_text)
  match
    sequence_message_label_bounds(
      edges[divider_index],
      actor_index,
      actor_center_x,
    ) {
    Some((message_left, message_right)) =>
      if divider_right > message_left && divider_left < message_right {
        sequence_divider_overlap_offset()
      } else {
        sequence_divider_default_offset()
      }
    None => sequence_divider_default_offset()
  }
}

///|
fn sequence_stack_pop(
  activation_starts : Map[String, Array[Int]],
  actor_id : String,
) -> Int? {
  match activation_starts.get(actor_id) {
    Some(stack) =>
      if stack.length() == 0 {
        None
      } else {
        let last_index = stack.length() - 1
        let value = stack[last_index]
        let next_stack : Array[Int] = []
        for i in 0..<last_index {
          next_stack.push(stack[i])
        }
        activation_starts[actor_id] = next_stack
        Some(value)
      }
    None => None
  }
}

///|
fn sequence_apply_activation_command(
  command : SequenceActivationCommand,
  y : Int,
  actor_index : Map[String, Int],
  actor_center_x : Array[Int],
  activation_width : Int,
  activation_starts : Map[String, Array[Int]],
  sequence_activations : Array[PositionedSequenceActivation],
) -> Unit {
  if command.activate {
    let stack = activation_starts.get_or_init(command.actor_id, () => [])
    stack.push(y)
    return
  }

  match sequence_stack_pop(activation_starts, command.actor_id) {
    Some(start_y) =>
      match actor_index.get(command.actor_id) {
        Some(idx) =>
          sequence_activations.push({
            actor_id: command.actor_id,
            x: actor_center_x[idx] - activation_width / 2,
            top_y: start_y,
            bottom_y: y,
            width: activation_width,
          })
        None => ()
      }
    None => ()
  }
}

///|
fn sequence_collect_ordered_nodes(graph : MermaidGraph) -> Array[MermaidNode] {
  let ordered : Array[MermaidNode] = []
  let seen : Map[String, Bool] = {}
  for actor_id in graph.sequence_actor_order {
    match graph.nodes.get(actor_id) {
      Some(node) => {
        ordered.push(node)
        seen[actor_id] = true
      }
      None => ()
    }
  }
  for entry in graph.nodes.to_array() {
    let (node_id, node) = entry
    if !seen.contains(node_id) {
      ordered.push(node)
    }
  }
  ordered
}

///|
fn sequence_participant_kind(
  graph : MermaidGraph,
  node_id : String,
) -> SequenceParticipantKind {
  match graph.sequence_actor_kinds.get(node_id) {
    Some(kind) => kind
    None => Participant
  }
}

///|
fn sequence_block_header_extra() -> Int {
  28
}

///|
fn sequence_divider_extra() -> Int {
  24
}

/// Lays out a sequence diagram graph.
pub fn layout_sequence_graph(
  graph : MermaidGraph,
  options : RenderOptions,
) -> PositionedGraph {
  let padding = resolve_padding(options)
  let actor_gap = 140
  let actor_height = 40
  let actor_pad_x = 16
  let header_gap = 20
  let message_row_height = 40
  let self_message_extra = 30
  let activation_width = 10
  let block_pad_x = 10
  let block_pad_top = 40
  let block_pad_bottom = 8
  let note_width = 120
  let note_padding = 8
  let note_gap = 10

  let nodes_in_order = sequence_collect_ordered_nodes(graph)
  if nodes_in_order.length() == 0 {
    return {
      width: 0,
      height: 0,
      nodes: [],
      edges: [],
      groups: [],
      sequence_lifelines: [],
      sequence_activations: [],
      sequence_blocks: [],
      sequence_notes: [],
    }
  }

  let actor_widths : Array[Int] = []
  for node in nodes_in_order {
    let label = if node.label == "" { node.id } else { node.label }
    actor_widths.push((sequence_text_width(label) + actor_pad_x * 2).max(80))
  }

  let actor_center_x : Array[Int] = []
  let mut cursor_x = padding + actor_widths[0] / 2
  for i in 0..<nodes_in_order.length() {
    if i > 0 {
      let min_gap = actor_gap.max(
        (actor_widths[i - 1] + actor_widths[i]) / 2 + 40,
      )
      cursor_x = cursor_x + min_gap
    }
    actor_center_x.push(cursor_x)
  }

  let actor_index : Map[String, Int] = {}
  for i, node in nodes_in_order {
    actor_index[node.id] = i
  }

  let positioned_nodes : Array[PositionedNode] = []
  let positioned_by_id : Map[String, PositionedNode] = {}
  let actor_center_y = padding + actor_height / 2
  let mut max_right = padding
  for i, node in nodes_in_order {
    let width = actor_widths[i]
    let height = actor_height
    let x = actor_center_x[i]
    let inline_style = match resolve_inline_style(graph, node.id) {
      Some(style) => style.copy()
      None => {}
    }
    inline_style["__sequence_kind"] = match
      sequence_participant_kind(graph, node.id) {
      Actor => "actor"
      Participant => "participant"
    }
    let positioned = PositionedNode::{
      id: node.id,
      label: node.label,
      shape: node.shape,
      x,
      y: actor_center_y,
      width,
      height,
      inline_style: Some(inline_style),
    }
    positioned_nodes.push(positioned)
    positioned_by_id[node.id] = positioned
    max_right = max_right.max(x + width / 2)
  }

  let extra_before : Map[Int, Int] = {}
  for block in graph.sequence_blocks {
    let header_prev = option_int_or(extra_before.get(block.start_index), 0)
    let header_extra = sequence_block_header_extra()
    if header_extra > header_prev {
      extra_before[block.start_index] = header_extra
    }
    for divider in block.dividers {
      let divider_prev = option_int_or(extra_before.get(divider.index), 0)
      let divider_extra = sequence_divider_extra()
      if divider_extra > divider_prev {
        extra_before[divider.index] = divider_extra
      }
    }
  }

  let positioned_edges : Array[PositionedEdge] = []
  let message_rows : Array[Int] = []
  let activation_starts : Map[String, Array[Int]] = {}
  let sequence_activations : Array[PositionedSequenceActivation] = []
  let activation_commands_by_after : Map[Int, Array[SequenceActivationCommand]] = {}
  for command in graph.sequence_activation_commands {
    let bucket = activation_commands_by_after.get_or_init(command.after_index, () => {
      []
    })
    bucket.push(command)
  }
  let mut message_y = padding + actor_height + header_gap

  match activation_commands_by_after.get(-1) {
    Some(commands) =>
      for command in commands {
        sequence_apply_activation_command(
          command, message_y, actor_index, actor_center_x, activation_width, activation_starts,
          sequence_activations,
        )
      }
    None => ()
  }

  for i, edge in graph.edges {
    let extra = option_int_or(extra_before.get(i), 0)
    if extra > 0 {
      message_y = message_y + extra
    }
    match
      (positioned_by_id.get(edge.source), positioned_by_id.get(edge.target)) {
      (Some(source), Some(target)) => {
        let points = sequence_edge_points(source, target, message_y)
        let label_position = match edge.label {
          Some(_) =>
            if points.length() >= 2 {
              if edge.source == edge.target {
                Some(Point::{ x: points[1].x + 6, y: points[1].y + 10 })
              } else {
                Some({ x: (points[0].x + points[1].x) / 2, y: points[0].y - 6 })
              }
            } else {
              None
            }
          None => None
        }
        positioned_edges.push({
          source: edge.source,
          target: edge.target,
          label: edge.label,
          style: edge.style,
          has_arrow_start: edge.has_arrow_start,
          has_arrow_end: edge.has_arrow_end,
          relation_operator: edge.relation_operator,
          points,
          label_position,
        })
        message_rows.push(message_y)

        if sequence_operator_has_suffix(edge, "+") {
          let stack = activation_starts.get_or_init(edge.target, () => [])
          stack.push(message_y)
        }
        if sequence_operator_has_suffix(edge, "-") {
          sequence_apply_activation_command(
            { actor_id: edge.source, activate: false, after_index: i },
            message_y,
            actor_index,
            actor_center_x,
            activation_width,
            activation_starts,
            sequence_activations,
          )
        }

        match activation_commands_by_after.get(i) {
          Some(commands) => {
            let command_y = if edge.source == edge.target {
              message_y + message_row_height / 2 + self_message_extra / 2
            } else {
              message_y + message_row_height / 2
            }
            for command in commands {
              sequence_apply_activation_command(
                command, command_y, actor_index, actor_center_x, activation_width,
                activation_starts, sequence_activations,
              )
            }
          }
          None => ()
        }

        if edge.source == edge.target {
          message_y = message_y + message_row_height + self_message_extra
        } else {
          message_y = message_y + message_row_height
        }
      }
      _ => ()
    }
  }

  for entry in activation_starts.to_array() {
    let (actor_id, stack) = entry
    for start_y in stack {
      match actor_index.get(actor_id) {
        Some(idx) =>
          sequence_activations.push({
            actor_id,
            x: actor_center_x[idx] - activation_width / 2,
            top_y: start_y,
            bottom_y: (message_y - message_row_height / 2).max(
              start_y + message_row_height / 2,
            ),
            width: activation_width,
          })
        None => ()
      }
    }
  }

  let sequence_blocks : Array[PositionedSequenceBlock] = []
  for block in graph.sequence_blocks {
    let start_row = if block.start_index >= 0 &&
      block.start_index < message_rows.length() {
      message_rows[block.start_index]
    } else {
      message_y
    }
    let end_row = if block.end_index >= 0 &&
      block.end_index < message_rows.length() {
      message_rows[block.end_index]
    } else {
      message_y
    }
    let mut min_idx = nodes_in_order.length() - 1
    let mut max_idx = 0
    let mut has_involved = false
    for message_idx in block.start_index..<=block.end_index {
      if message_idx < 0 || message_idx >= graph.edges.length() {
        continue
      }
      let edge = graph.edges[message_idx]
      match actor_index.get(edge.source) {
        Some(source_idx) => {
          has_involved = true
          min_idx = min_idx.min(source_idx)
          max_idx = max_idx.max(source_idx)
        }
        None => ()
      }
      match actor_index.get(edge.target) {
        Some(target_idx) => {
          has_involved = true
          min_idx = min_idx.min(target_idx)
          max_idx = max_idx.max(target_idx)
        }
        None => ()
      }
    }
    if !has_involved {
      min_idx = 0
      max_idx = nodes_in_order.length() - 1
    }

    let left = actor_center_x[min_idx] - actor_widths[min_idx] / 2 - block_pad_x
    let right = actor_center_x[max_idx] +
      actor_widths[max_idx] / 2 +
      block_pad_x
    let dividers : Array[PositionedSequenceBlockDivider] = []
    for divider in block.dividers {
      let divider_row = if divider.index >= 0 &&
        divider.index < message_rows.length() {
        message_rows[divider.index]
      } else {
        message_y
      }
      let divider_offset = sequence_divider_offset_for(
        left,
        divider.label,
        divider.index,
        graph.edges,
        actor_index,
        actor_center_x,
      )
      dividers.push({ y: divider_row - divider_offset, label: divider.label })
    }
    sequence_blocks.push({
      block_type: block.block_type,
      label: block.label,
      x: left,
      y: start_row - block_pad_top,
      width: right - left,
      height: end_row + block_pad_bottom + 12 - (start_row - block_pad_top),
      dividers,
    })
  }

  let sequence_notes : Array[PositionedSequenceNote] = []
  for note in graph.sequence_notes {
    if note.actor_ids.length() == 0 {
      continue
    }
    let first_index = option_int_or(actor_index.get(note.actor_ids[0]), 0)
    let note_w = sequence_note_width(note.text, note_width, note_padding)
    let note_h = 13 + note_padding * 2
    let note_y = if note.after_index >= 0 &&
      note.after_index < message_rows.length() {
      message_rows[note.after_index] + 4
    } else {
      padding + actor_height + 4
    }
    let note_x = match note.position {
      Left =>
        actor_center_x[first_index] -
        actor_widths[first_index] / 2 -
        note_w -
        note_gap
      Right =>
        actor_center_x[first_index] + actor_widths[first_index] / 2 + note_gap
      Over =>
        if note.actor_ids.length() > 1 {
          let last_actor = note.actor_ids[note.actor_ids.length() - 1]
          let last_index = option_int_or(
            actor_index.get(last_actor),
            first_index,
          )
          (actor_center_x[first_index] + actor_center_x[last_index]) / 2 -
          note_w / 2
        } else {
          actor_center_x[first_index] - note_w / 2
        }
    }
    sequence_notes.push({
      text: note.text,
      x: note_x,
      y: note_y,
      width: note_w,
      height: note_h,
    })
  }

  let diagram_bottom = message_y + padding
  let mut global_min_x = padding
  let mut global_max_x = max_right
  for node in positioned_nodes {
    global_min_x = global_min_x.min(node.x - node.width / 2)
    global_max_x = global_max_x.max(node.x + node.width / 2)
  }
  for block in sequence_blocks {
    global_min_x = global_min_x.min(block.x)
    global_max_x = global_max_x.max(block.x + block.width)
  }
  for note in sequence_notes {
    global_min_x = global_min_x.min(note.x)
    global_max_x = global_max_x.max(note.x + note.width)
  }

  let shift_x = if global_min_x < padding { padding - global_min_x } else { 0 }
  if shift_x > 0 {
    for i, node in positioned_nodes {
      positioned_nodes[i] = {
        id: node.id,
        label: node.label,
        shape: node.shape,
        x: node.x + shift_x,
        y: node.y,
        width: node.width,
        height: node.height,
        inline_style: node.inline_style,
      }
    }
    for i, edge in positioned_edges {
      let shifted_points : Array[Point] = []
      for point in edge.points {
        shifted_points.push({ x: point.x + shift_x, y: point.y })
      }
      let shifted_label = match edge.label_position {
        Some(position) =>
          Some(Point::{ x: position.x + shift_x, y: position.y })
        None => None
      }
      positioned_edges[i] = {
        source: edge.source,
        target: edge.target,
        label: edge.label,
        style: edge.style,
        has_arrow_start: edge.has_arrow_start,
        has_arrow_end: edge.has_arrow_end,
        relation_operator: edge.relation_operator,
        points: shifted_points,
        label_position: shifted_label,
      }
    }
    for i, activation in sequence_activations {
      sequence_activations[i] = {
        actor_id: activation.actor_id,
        x: activation.x + shift_x,
        top_y: activation.top_y,
        bottom_y: activation.bottom_y,
        width: activation.width,
      }
    }
    for i, block in sequence_blocks {
      sequence_blocks[i] = {
        block_type: block.block_type,
        label: block.label,
        x: block.x + shift_x,
        y: block.y,
        width: block.width,
        height: block.height,
        dividers: block.dividers,
      }
    }
    for i, note in sequence_notes {
      sequence_notes[i] = {
        text: note.text,
        x: note.x + shift_x,
        y: note.y,
        width: note.width,
        height: note.height,
      }
    }
  }

  let sequence_lifelines : Array[PositionedSequenceLifeline] = []
  for node in positioned_nodes {
    sequence_lifelines.push({
      actor_id: node.id,
      x: node.x,
      top_y: padding + actor_height,
      bottom_y: diagram_bottom - padding,
    })
  }

  {
    width: (global_max_x + shift_x + padding).max(200),
    height: diagram_bottom.max(100),
    nodes: positioned_nodes,
    edges: positioned_edges,
    groups: [],
    sequence_lifelines,
    sequence_activations,
    sequence_blocks,
    sequence_notes,
  }
}
