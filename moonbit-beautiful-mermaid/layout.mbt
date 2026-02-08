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
fn resolve_node_spacing(options : RenderOptions) -> Int {
  option_int_or(options.node_spacing, 130)
}

///|
fn resolve_layer_spacing(options : RenderOptions) -> Int {
  option_int_or(options.layer_spacing, 90)
}

///|
fn node_dimensions(node : MermaidNode) -> (Int, Int) {
  let label_lines = node.label
    .split("\n")
    .map(part => part.to_string())
    .to_array()
  let mut longest_line = 0
  for line in label_lines {
    longest_line = longest_line.max(line.length())
  }

  match node.shape {
    NodeShape::StateStart => (22, 22)
    NodeShape::StateEnd => (22, 22)
    NodeShape::Circle => (60, 60)
    NodeShape::DoubleCircle => (64, 64)
    NodeShape::ClassEntity => {
      let min_width = 120
      let width = min_width.max(longest_line * 8 + 30)
      let detail_rows = (label_lines.length() - 1).max(1)
      let height = 36 + detail_rows * 16 + 10
      (width, height)
    }
    NodeShape::ErEntity => {
      let min_width = 120
      let width = min_width.max(longest_line * 8 + 30)
      let detail_rows = (label_lines.length() - 1).max(1)
      let height = 34 + detail_rows * 16 + 10
      (width, height)
    }
    _ => {
      let min_width = 70
      let width = min_width.max(longest_line * 8 + 24)
      let height = (24 + label_lines.length() * 14).max(44)
      (width, height)
    }
  }
}

///|
fn layout_direction_is_horizontal(direction : Direction) -> Bool {
  direction is (Direction::LR | Direction::RL)
}

///|
fn layout_direction_is_reverse(direction : Direction) -> Bool {
  direction is (Direction::RL | Direction::BT)
}

///|
fn resolve_subgraph_layout_direction(
  subgraph_direction : Direction?,
  inherited_horizontal : Bool,
  inherited_reverse : Bool,
) -> (Bool, Bool) {
  match subgraph_direction {
    Some(direction) =>
      (
        layout_direction_is_horizontal(direction),
        layout_direction_is_reverse(direction),
      )
    None => (inherited_horizontal, inherited_reverse)
  }
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
fn edge_points_for(
  source : PositionedNode,
  target : PositionedNode,
  horizontal : Bool,
) -> Array[Point] {
  if horizontal {
    let moving_right = target.x >= source.x
    let source_delta = if moving_right {
      source.width / 2
    } else {
      -source.width / 2
    }
    let target_delta = if moving_right {
      -target.width / 2
    } else {
      target.width / 2
    }
    let start_x = source.x + source_delta
    let end_x = target.x + target_delta
    [Point::{ x: start_x, y: source.y }, Point::{ x: end_x, y: target.y }]
  } else {
    let moving_down = target.y >= source.y
    let source_delta = if moving_down {
      source.height / 2
    } else {
      -source.height / 2
    }
    let target_delta = if moving_down {
      -target.height / 2
    } else {
      target.height / 2
    }
    let start_y = source.y + source_delta
    let end_y = target.y + target_delta
    [Point::{ x: source.x, y: start_y }, Point::{ x: target.x, y: end_y }]
  }
}

///|
fn midpoint(a : Point, b : Point) -> Point {
  Point::{ x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }
}

///|
fn label_overlap_offset(slot : Int) -> Int {
  if slot <= 0 {
    return 0
  }
  let magnitude = (slot + 1) / 2 * 30
  if slot % 2 == 1 {
    -magnitude
  } else {
    magnitude
  }
}

///|
fn label_overlap_offset_x(slot : Int) -> Int {
  if slot <= 0 {
    return 0
  }
  let magnitude = (slot + 1) / 2 * 40
  if slot % 2 == 1 {
    -magnitude
  } else {
    magnitude
  }
}

///|
fn label_anchor_key(point : Point) -> String {
  "\{point.x}:\{point.y}"
}

///|
fn is_sequence_graph(graph : MermaidGraph) -> Bool {
  let nodes = graph.nodes.values().to_array()
  if nodes.length() == 0 {
    return false
  }
  for node in nodes {
    if node.shape != NodeShape::SequenceParticipant {
      return false
    }
  }
  true
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
      Point::{ x: start_x, y },
      Point::{ x: loop_x, y },
      Point::{ x: loop_x, y: loop_bottom },
      Point::{ x: start_x, y: loop_bottom },
    ]
  } else {
    let moving_right = target.x >= source.x
    let start_x = source.x +
      (if moving_right { source.width / 2 } else { -source.width / 2 })
    let end_x = target.x +
      (if moving_right { -target.width / 2 } else { target.width / 2 })
    [Point::{ x: start_x, y }, Point::{ x: end_x, y }]
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
          sequence_activations.push(PositionedSequenceActivation::{
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
    None => SequenceParticipantKind::Participant
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

///|
fn layout_sequence_graph(
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
    return PositionedGraph::{
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
      SequenceParticipantKind::Actor => "actor"
      SequenceParticipantKind::Participant => "participant"
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
                Some(Point::{
                  x: (points[0].x + points[1].x) / 2,
                  y: points[0].y - 6,
                })
              }
            } else {
              None
            }
          None => None
        }
        positioned_edges.push(PositionedEdge::{
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
            SequenceActivationCommand::{
              actor_id: edge.source,
              activate: false,
              after_index: i,
            },
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
          sequence_activations.push(PositionedSequenceActivation::{
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
      dividers.push(PositionedSequenceBlockDivider::{
        y: divider_row - divider_offset,
        label: divider.label,
      })
    }
    sequence_blocks.push(PositionedSequenceBlock::{
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
      SequenceNotePosition::Left =>
        actor_center_x[first_index] -
        actor_widths[first_index] / 2 -
        note_w -
        note_gap
      SequenceNotePosition::Right =>
        actor_center_x[first_index] + actor_widths[first_index] / 2 + note_gap
      SequenceNotePosition::Over =>
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
    sequence_notes.push(PositionedSequenceNote::{
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
      positioned_nodes[i] = PositionedNode::{
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
        shifted_points.push(Point::{ x: point.x + shift_x, y: point.y })
      }
      let shifted_label = match edge.label_position {
        Some(position) =>
          Some(Point::{ x: position.x + shift_x, y: position.y })
        None => None
      }
      positioned_edges[i] = PositionedEdge::{
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
      sequence_activations[i] = PositionedSequenceActivation::{
        actor_id: activation.actor_id,
        x: activation.x + shift_x,
        top_y: activation.top_y,
        bottom_y: activation.bottom_y,
        width: activation.width,
      }
    }
    for i, block in sequence_blocks {
      sequence_blocks[i] = PositionedSequenceBlock::{
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
      sequence_notes[i] = PositionedSequenceNote::{
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
    sequence_lifelines.push(PositionedSequenceLifeline::{
      actor_id: node.id,
      x: node.x,
      top_y: padding + actor_height,
      bottom_y: diagram_bottom - padding,
    })
  }

  PositionedGraph::{
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

///|
fn subgraph_group_padding() -> Int {
  12
}

///|
fn subgraph_group_header_height() -> Int {
  24
}

///|
fn subgraph_group_min_width(label : String) -> Int {
  (label.length() * 7 + 24).max(80)
}

///|
fn subgraph_group_min_height() -> Int {
  subgraph_group_header_height() + subgraph_group_padding() * 2 + 20
}

///|
fn include_bounds(
  has_bounds : Bool,
  min_left : Int,
  min_top : Int,
  max_right : Int,
  max_bottom : Int,
  left : Int,
  top : Int,
  right : Int,
  bottom : Int,
) -> (Bool, Int, Int, Int, Int) {
  if has_bounds {
    (
      true,
      min_left.min(left),
      min_top.min(top),
      max_right.max(right),
      max_bottom.max(bottom),
    )
  } else {
    (true, left, top, right, bottom)
  }
}

///|
fn build_empty_group_tree_at(
  subgraph : MermaidSubgraph,
  x : Int,
  y : Int,
  inherited_horizontal : Bool,
  inherited_reverse : Bool,
) -> PositionedGroup {
  let (horizontal, reverse) = resolve_subgraph_layout_direction(
    subgraph.direction,
    inherited_horizontal,
    inherited_reverse,
  )
  let group_padding = subgraph_group_padding()
  let header_height = subgraph_group_header_height()
  let children : Array[PositionedGroup] = []
  let child_groups : Array[PositionedGroup] = []
  let mut max_child_right = x
  let mut max_child_bottom = y

  for child_subgraph in subgraph.children {
    let child_group = build_empty_group_tree_at(
      child_subgraph, 0, 0, horizontal, reverse,
    )
    child_groups.push(child_group)
  }

  if child_groups.length() > 0 {
    if horizontal {
      let mut total_width = 0
      let mut max_height = 0
      for child_group in child_groups {
        total_width += child_group.width
        max_height = max_height.max(child_group.height)
      }
      total_width += group_padding * (child_groups.length() - 1)
      let content_left = x + group_padding
      let content_top = y + header_height + group_padding
      let mut left = content_left
      let mut right = content_left + total_width
      for child_group in child_groups {
        let child_x = if reverse { right - child_group.width } else { left }
        let child_y = content_top + (max_height - child_group.height) / 2
        let shifted_group = shift_positioned_group(
          child_group,
          child_x - child_group.x,
          child_y - child_group.y,
        )
        children.push(shifted_group)
        max_child_right = max_child_right.max(
          shifted_group.x + shifted_group.width,
        )
        max_child_bottom = max_child_bottom.max(
          shifted_group.y + shifted_group.height,
        )
        if reverse {
          right = right - child_group.width - group_padding
        } else {
          left = left + child_group.width + group_padding
        }
      }
    } else {
      let mut total_height = 0
      let mut max_width = 0
      for child_group in child_groups {
        total_height += child_group.height
        max_width = max_width.max(child_group.width)
      }
      total_height += group_padding * (child_groups.length() - 1)
      let content_left = x + group_padding
      let content_top = y + header_height + group_padding
      let mut top = content_top
      let mut bottom = content_top + total_height
      for child_group in child_groups {
        let child_x = content_left + (max_width - child_group.width) / 2
        let child_y = if reverse { bottom - child_group.height } else { top }
        let shifted_group = shift_positioned_group(
          child_group,
          child_x - child_group.x,
          child_y - child_group.y,
        )
        children.push(shifted_group)
        max_child_right = max_child_right.max(
          shifted_group.x + shifted_group.width,
        )
        max_child_bottom = max_child_bottom.max(
          shifted_group.y + shifted_group.height,
        )
        if reverse {
          bottom = bottom - child_group.height - group_padding
        } else {
          top = top + child_group.height + group_padding
        }
      }
    }
  }

  let mut width = subgraph_group_min_width(subgraph.label)
  let mut height = subgraph_group_min_height()
  if child_groups.length() > 0 {
    width = width.max(max_child_right - x + group_padding)
    height = height.max(max_child_bottom - y + group_padding)
  }

  PositionedGroup::{
    id: subgraph.id,
    label: subgraph.label,
    x,
    y,
    width,
    height,
    children,
  }
}

///|
fn build_positioned_group(
  subgraph : MermaidSubgraph,
  positioned_by_id : Map[String, PositionedNode],
  inherited_horizontal : Bool,
  inherited_reverse : Bool,
) -> PositionedGroup? {
  let (subgraph_horizontal, subgraph_reverse) = resolve_subgraph_layout_direction(
    subgraph.direction,
    inherited_horizontal,
    inherited_reverse,
  )
  let mut has_bounds = false
  let mut min_left = 0
  let mut min_top = 0
  let mut max_right = 0
  let mut max_bottom = 0
  let children : Array[PositionedGroup] = []
  let missing_children : Array[MermaidSubgraph] = []

  for child_subgraph in subgraph.children {
    match
      build_positioned_group(
        child_subgraph, positioned_by_id, subgraph_horizontal, subgraph_reverse,
      ) {
      Some(child_group) => {
        children.push(child_group)
        let (next_has, next_left, next_top, next_right, next_bottom) = include_bounds(
          has_bounds,
          min_left,
          min_top,
          max_right,
          max_bottom,
          child_group.x,
          child_group.y,
          child_group.x + child_group.width,
          child_group.y + child_group.height,
        )
        has_bounds = next_has
        min_left = next_left
        min_top = next_top
        max_right = next_right
        max_bottom = next_bottom
      }
      None => missing_children.push(child_subgraph)
    }
  }

  for node_id in subgraph.node_ids {
    match positioned_by_id.get(node_id) {
      Some(node) => {
        let node_left = node.x - node.width / 2
        let node_top = node.y - node.height / 2
        let node_right = node.x + node.width / 2
        let node_bottom = node.y + node.height / 2
        let (next_has, next_left, next_top, next_right, next_bottom) = include_bounds(
          has_bounds, min_left, min_top, max_right, max_bottom, node_left, node_top,
          node_right, node_bottom,
        )
        has_bounds = next_has
        min_left = next_left
        min_top = next_top
        max_right = next_right
        max_bottom = next_bottom
      }
      None => ()
    }
  }

  if !has_bounds {
    return None
  }

  let group_padding = subgraph_group_padding()
  let header_height = subgraph_group_header_height()
  let content_width = max_right - min_left
  let content_height = max_bottom - min_top
  let min_group_width = subgraph_group_min_width(subgraph.label)
  let min_group_height = subgraph_group_min_height()
  let mut width = (content_width + group_padding * 2).max(min_group_width)
  let mut height = (content_height + header_height + group_padding * 2).max(
    min_group_height,
  )
  let x = min_left - group_padding
  let y = min_top - header_height - group_padding
  let mut empty_child_top = y + height + group_padding
  for missing_child in missing_children {
    let child_group = build_empty_group_tree_at(
      missing_child,
      x + group_padding,
      empty_child_top,
      subgraph_horizontal,
      subgraph_reverse,
    )
    children.push(child_group)
    width = width.max(child_group.x + child_group.width - x + group_padding)
    height = height.max(child_group.y + child_group.height - y + group_padding)
    empty_child_top = child_group.y + child_group.height + group_padding
  }

  Some(PositionedGroup::{
    id: subgraph.id,
    label: subgraph.label,
    x,
    y,
    width,
    height,
    children,
  })
}

///|
fn positioned_group_min_x(group : PositionedGroup) -> Int {
  let mut min_x = group.x
  for child in group.children {
    min_x = min_x.min(positioned_group_min_x(child))
  }
  min_x
}

///|
fn positioned_group_min_y(group : PositionedGroup) -> Int {
  let mut min_y = group.y
  for child in group.children {
    min_y = min_y.min(positioned_group_min_y(child))
  }
  min_y
}

///|
fn positioned_group_max_x(group : PositionedGroup) -> Int {
  let mut max_x = group.x + group.width
  for child in group.children {
    max_x = max_x.max(positioned_group_max_x(child))
  }
  max_x
}

///|
fn positioned_group_max_y(group : PositionedGroup) -> Int {
  let mut max_y = group.y + group.height
  for child in group.children {
    max_y = max_y.max(positioned_group_max_y(child))
  }
  max_y
}

///|
fn shift_positioned_group(
  group : PositionedGroup,
  shift_x : Int,
  shift_y : Int,
) -> PositionedGroup {
  let shifted_children : Array[PositionedGroup] = []
  for child in group.children {
    shifted_children.push(shift_positioned_group(child, shift_x, shift_y))
  }
  PositionedGroup::{
    id: group.id,
    label: group.label,
    x: group.x + shift_x,
    y: group.y + shift_y,
    width: group.width,
    height: group.height,
    children: shifted_children,
  }
}

///|
fn collect_subgraph_edge_redirects(
  subgraph : MermaidSubgraph,
  entry_by_subgraph : Map[String, String],
  exit_by_subgraph : Map[String, String],
) -> Unit {
  for child in subgraph.children {
    collect_subgraph_edge_redirects(child, entry_by_subgraph, exit_by_subgraph)
  }

  let mut entry_id : String? = None
  let mut exit_id : String? = None
  if subgraph.node_ids.length() > 0 {
    entry_id = Some(subgraph.node_ids[0])
    exit_id = Some(subgraph.node_ids[subgraph.node_ids.length() - 1])
  } else if subgraph.children.length() > 0 {
    let first_child = subgraph.children[0]
    let last_child = subgraph.children[subgraph.children.length() - 1]
    entry_id = entry_by_subgraph.get(first_child.id)
    exit_id = exit_by_subgraph.get(last_child.id)
  } else {
    entry_id = Some(subgraph.id)
    exit_id = Some(subgraph.id)
  }

  match entry_id {
    Some(id) => entry_by_subgraph[subgraph.id] = id
    None => ()
  }
  match exit_id {
    Some(id) => exit_by_subgraph[subgraph.id] = id
    None => ()
  }
}

///|
fn collect_hidden_subgraph_node_ids(
  subgraphs : Array[MermaidSubgraph],
  entry_by_subgraph : Map[String, String],
  exit_by_subgraph : Map[String, String],
  hidden_node_ids : Map[String, Bool],
) -> Unit {
  for subgraph in subgraphs {
    if entry_by_subgraph.contains(subgraph.id) ||
      exit_by_subgraph.contains(subgraph.id) {
      hidden_node_ids[subgraph.id] = true
    }
    collect_hidden_subgraph_node_ids(
      subgraph.children,
      entry_by_subgraph,
      exit_by_subgraph,
      hidden_node_ids,
    )
  }
}

///|
fn apply_subgraph_direction_override_to_members(
  node_ids : Array[String],
  horizontal : Bool,
  reverse : Bool,
  node_spacing : Int,
  layer_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  positioned_index_by_id : Map[String, Int],
) -> Unit {
  let member_indexes : Array[Int] = []
  for node_id in node_ids {
    match positioned_index_by_id.get(node_id) {
      Some(index) => member_indexes.push(index)
      None => ()
    }
  }

  if member_indexes.length() < 2 {
    return
  }

  let mut has_bounds = false
  let mut min_left = 0
  let mut min_top = 0
  let mut max_right = 0
  let mut max_bottom = 0
  for index in member_indexes {
    let node = positioned_nodes[index]
    let left = node.x - node.width / 2
    let top = node.y - node.height / 2
    let right = node.x + node.width / 2
    let bottom = node.y + node.height / 2
    let (next_has, next_left, next_top, next_right, next_bottom) = include_bounds(
      has_bounds, min_left, min_top, max_right, max_bottom, left, top, right, bottom,
    )
    has_bounds = next_has
    min_left = next_left
    min_top = next_top
    max_right = next_right
    max_bottom = next_bottom
  }

  if !has_bounds {
    return
  }

  if horizontal {
    let mut left = min_left
    let mut right = max_right
    let center_y = (min_top + max_bottom) / 2
    for index in member_indexes {
      let node = positioned_nodes[index]
      let x = if reverse {
        right - node.width / 2
      } else {
        left + node.width / 2
      }
      positioned_nodes[index] = PositionedNode::{
        id: node.id,
        label: node.label,
        shape: node.shape,
        x,
        y: center_y,
        width: node.width,
        height: node.height,
        inline_style: node.inline_style,
      }
      if reverse {
        right = right - node.width - node_spacing
      } else {
        left = left + node.width + node_spacing
      }
    }
  } else {
    let mut top = min_top
    let mut bottom = max_bottom
    let center_x = (min_left + max_right) / 2
    for index in member_indexes {
      let node = positioned_nodes[index]
      let y = if reverse {
        bottom - node.height / 2
      } else {
        top + node.height / 2
      }
      positioned_nodes[index] = PositionedNode::{
        id: node.id,
        label: node.label,
        shape: node.shape,
        x: center_x,
        y,
        width: node.width,
        height: node.height,
        inline_style: node.inline_style,
      }
      if reverse {
        bottom = bottom - node.height - layer_spacing
      } else {
        top = top + node.height + layer_spacing
      }
    }
  }
}

///|
priv struct SubgraphMemberBlock {
  node_indexes : Array[Int]
  left : Int
  top : Int
  width : Int
  height : Int
}

///|
fn collect_subgraph_node_indexes(
  subgraph : MermaidSubgraph,
  positioned_index_by_id : Map[String, Int],
  seen_node_ids : Map[String, Bool],
  indexes : Array[Int],
) -> Unit {
  for node_id in subgraph.node_ids {
    if seen_node_ids.contains(node_id) {
      continue
    }
    seen_node_ids[node_id] = true
    match positioned_index_by_id.get(node_id) {
      Some(index) => indexes.push(index)
      None => ()
    }
  }
  for child in subgraph.children {
    collect_subgraph_node_indexes(
      child, positioned_index_by_id, seen_node_ids, indexes,
    )
  }
}

///|
fn member_indexes_bounds(
  indexes : Array[Int],
  positioned_nodes : Array[PositionedNode],
) -> (Bool, Int, Int, Int, Int) {
  let mut has_bounds = false
  let mut min_left = 0
  let mut min_top = 0
  let mut max_right = 0
  let mut max_bottom = 0
  for index in indexes {
    let node = positioned_nodes[index]
    let left = node.x - node.width / 2
    let top = node.y - node.height / 2
    let right = node.x + node.width / 2
    let bottom = node.y + node.height / 2
    let (next_has, next_left, next_top, next_right, next_bottom) = include_bounds(
      has_bounds, min_left, min_top, max_right, max_bottom, left, top, right, bottom,
    )
    has_bounds = next_has
    min_left = next_left
    min_top = next_top
    max_right = next_right
    max_bottom = next_bottom
  }
  (has_bounds, min_left, min_top, max_right, max_bottom)
}

///|
fn shift_member_indexes(
  indexes : Array[Int],
  dx : Int,
  dy : Int,
  positioned_nodes : Array[PositionedNode],
) -> Unit {
  if dx == 0 && dy == 0 {
    return
  }
  for index in indexes {
    let node = positioned_nodes[index]
    positioned_nodes[index] = PositionedNode::{
      id: node.id,
      label: node.label,
      shape: node.shape,
      x: node.x + dx,
      y: node.y + dy,
      width: node.width,
      height: node.height,
      inline_style: node.inline_style,
    }
  }
}

///|
fn apply_subgraph_direction_override_to_children(
  children : Array[MermaidSubgraph],
  horizontal : Bool,
  reverse : Bool,
  node_spacing : Int,
  layer_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  positioned_index_by_id : Map[String, Int],
) -> Unit {
  let member_blocks : Array[SubgraphMemberBlock] = []
  let mut has_bounds = false
  let mut min_left = 0
  let mut min_top = 0
  let mut max_right = 0
  let mut max_bottom = 0

  for child in children {
    let seen_node_ids : Map[String, Bool] = {}
    let indexes : Array[Int] = []
    collect_subgraph_node_indexes(
      child, positioned_index_by_id, seen_node_ids, indexes,
    )
    let (child_has_bounds, child_left, child_top, child_right, child_bottom) = member_indexes_bounds(
      indexes, positioned_nodes,
    )
    if !child_has_bounds {
      continue
    }
    member_blocks.push(SubgraphMemberBlock::{
      node_indexes: indexes,
      left: child_left,
      top: child_top,
      width: child_right - child_left,
      height: child_bottom - child_top,
    })
    let (next_has, next_left, next_top, next_right, next_bottom) = include_bounds(
      has_bounds, min_left, min_top, max_right, max_bottom, child_left, child_top,
      child_right, child_bottom,
    )
    has_bounds = next_has
    min_left = next_left
    min_top = next_top
    max_right = next_right
    max_bottom = next_bottom
  }

  if !has_bounds || member_blocks.length() < 2 {
    return
  }

  if horizontal {
    let mut left = min_left
    let mut right = max_right
    let center_y = (min_top + max_bottom) / 2
    for block in member_blocks {
      let target_left = if reverse { right - block.width } else { left }
      let target_top = center_y - block.height / 2
      let dx = target_left - block.left
      let dy = target_top - block.top
      shift_member_indexes(block.node_indexes, dx, dy, positioned_nodes)
      if reverse {
        right = right - block.width - node_spacing
      } else {
        left = left + block.width + node_spacing
      }
    }
  } else {
    let mut top = min_top
    let mut bottom = max_bottom
    let center_x = (min_left + max_right) / 2
    for block in member_blocks {
      let target_left = center_x - block.width / 2
      let target_top = if reverse { bottom - block.height } else { top }
      let dx = target_left - block.left
      let dy = target_top - block.top
      shift_member_indexes(block.node_indexes, dx, dy, positioned_nodes)
      if reverse {
        bottom = bottom - block.height - layer_spacing
      } else {
        top = top + block.height + layer_spacing
      }
    }
  }
}

///|
fn apply_subgraph_direction_overrides(
  subgraphs : Array[MermaidSubgraph],
  inherited_horizontal : Bool,
  inherited_reverse : Bool,
  inherited_override_active : Bool,
  global_horizontal : Bool,
  global_reverse : Bool,
  node_spacing : Int,
  layer_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  positioned_index_by_id : Map[String, Int],
  node_horizontal_by_id : Map[String, Bool],
) -> Unit {
  for subgraph in subgraphs {
    let (subgraph_horizontal, subgraph_reverse, override_active) = match
      subgraph.direction {
      Some(direction) => {
        let horizontal = layout_direction_is_horizontal(direction)
        let reverse = layout_direction_is_reverse(direction)
        (
          horizontal,
          reverse,
          horizontal != global_horizontal || reverse != global_reverse,
        )
      }
      None =>
        (inherited_horizontal, inherited_reverse, inherited_override_active)
    }

    if override_active {
      for node_id in subgraph.node_ids {
        if positioned_index_by_id.contains(node_id) {
          node_horizontal_by_id[node_id] = subgraph_horizontal
        }
      }
      apply_subgraph_direction_override_to_members(
        subgraph.node_ids,
        subgraph_horizontal,
        subgraph_reverse,
        node_spacing,
        layer_spacing,
        positioned_nodes,
        positioned_index_by_id,
      )
    }

    apply_subgraph_direction_overrides(
      subgraph.children,
      subgraph_horizontal,
      subgraph_reverse,
      override_active,
      global_horizontal,
      global_reverse,
      node_spacing,
      layer_spacing,
      positioned_nodes,
      positioned_index_by_id,
      node_horizontal_by_id,
    )

    if override_active {
      apply_subgraph_direction_override_to_children(
        subgraph.children,
        subgraph_horizontal,
        subgraph_reverse,
        node_spacing,
        layer_spacing,
        positioned_nodes,
        positioned_index_by_id,
      )
    }
  }
}

///|
fn is_state_graph(graph : MermaidGraph) -> Bool {
  for _, node in graph.nodes {
    match node.shape {
      NodeShape::StateStart | NodeShape::StateEnd => return true
      _ => ()
    }
  }
  false
}

///|
fn find_positioned_group_index(
  groups : Array[PositionedGroup],
  group_id : String,
) -> Int? {
  for i, group in groups {
    if group.id == group_id {
      return Some(i)
    }
  }
  None
}

///|
fn shift_top_level_state_subgraphs_right(
  graph : MermaidGraph,
  node_spacing : Int,
  layer_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  positioned_groups : Array[PositionedGroup],
  positioned_index_by_id : Map[String, Int],
  positioned_by_id : Map[String, PositionedNode],
) -> Unit {
  if graph.subgraphs.length() == 0 {
    return
  }

  let member_indexes_by_root : Array[Array[Int]] = []
  let subgraph_node_ids : Map[String, Bool] = {}
  for subgraph in graph.subgraphs {
    let seen_node_ids : Map[String, Bool] = {}
    let indexes : Array[Int] = []
    collect_subgraph_node_indexes(
      subgraph,
      positioned_index_by_id,
      seen_node_ids,
      indexes,
    )
    for index in indexes {
      subgraph_node_ids[positioned_nodes[index].id] = true
    }
    member_indexes_by_root.push(indexes)
  }

  let outside_indexes : Array[Int] = []
  for i, node in positioned_nodes {
    if !subgraph_node_ids.contains(node.id) {
      outside_indexes.push(i)
    }
  }
  if outside_indexes.length() == 0 {
    return
  }

  let (has_outside, _, _, outside_right, _) = member_indexes_bounds(
    outside_indexes,
    positioned_nodes,
  )
  if !has_outside {
    return
  }
  let (_, _, outside_top, _, _) = member_indexes_bounds(
    outside_indexes,
    positioned_nodes,
  )

  let min_gap = (node_spacing / 3).max(24)
  let mut cursor_left = outside_right + min_gap
  let target_top = outside_top - (layer_spacing / 2).max(30)
  for i, subgraph in graph.subgraphs {
    let member_indexes = member_indexes_by_root[i]
    if member_indexes.length() == 0 {
      continue
    }

    let group_index = match find_positioned_group_index(positioned_groups, subgraph.id) {
      Some(index) => index
      None => continue
    }
    let group = positioned_groups[group_index]
    let dx = cursor_left - group.x
    let dy = target_top - group.y
    if dx > 0 || dy != 0 {
      shift_member_indexes(member_indexes, dx.max(0), dy, positioned_nodes)
      positioned_groups[group_index] = shift_positioned_group(group, dx.max(0), dy)
      for index in member_indexes {
        let node = positioned_nodes[index]
        positioned_by_id[node.id] = node
      }
    }
    let shifted_group = positioned_groups[group_index]
    cursor_left = shifted_group.x + shifted_group.width + min_gap
  }
}

///|
fn register_group_anchors(
  group : PositionedGroup,
  positioned_by_id : Map[String, PositionedNode],
  preserve_existing : Bool,
) -> Unit {
  if !preserve_existing || !positioned_by_id.contains(group.id) {
    positioned_by_id[group.id] = PositionedNode::{
      id: group.id,
      label: group.label,
      shape: NodeShape::Rectangle,
      x: group.x + group.width / 2,
      y: group.y + group.height / 2,
      width: group.width,
      height: group.height,
      inline_style: None,
    }
  }
  for child in group.children {
    register_group_anchors(child, positioned_by_id, preserve_existing)
  }
}

///|
fn layout_graph(
  graph : MermaidGraph,
  options : RenderOptions,
) -> PositionedGraph {
  layout_graph_with_subgraph_redirects(graph, options, true)
}

///|
fn layout_graph_for_ascii(
  graph : MermaidGraph,
  options : RenderOptions,
) -> PositionedGraph {
  let state_graph = is_state_graph(graph)
  let horizontal = layout_direction_is_horizontal(graph.direction)
  let reverse = layout_direction_is_reverse(graph.direction)
  let state_flat_ascii_grid_mode =
    state_graph &&
    graph.subgraphs.length() == 0 &&
    !horizontal &&
    !reverse
  if state_flat_ascii_grid_mode {
    return layout_flat_state_graph_for_ascii_grid(graph, options)
  }

  let state_composite_ascii_mode =
    state_graph && graph.subgraphs.length() > 0
  layout_graph_with_subgraph_redirects(
    graph,
    options,
    !state_composite_ascii_mode,
  )
}

///|
fn layout_graph_with_subgraph_redirects(
  graph : MermaidGraph,
  options : RenderOptions,
  use_subgraph_redirects : Bool,
) -> PositionedGraph {
  if is_sequence_graph(graph) {
    return layout_sequence_graph(graph, options)
  }

  let padding = resolve_padding(options)
  let node_spacing = resolve_node_spacing(options)
  let layer_spacing = resolve_layer_spacing(options)
  let horizontal = layout_direction_is_horizontal(graph.direction)
  let reverse = layout_direction_is_reverse(graph.direction)
  let state_graph = is_state_graph(graph)
  let flat_state_graph = state_graph && !horizontal && graph.subgraphs.length() == 0

  let subgraph_entry_by_id : Map[String, String] = {}
  let subgraph_exit_by_id : Map[String, String] = {}
  if use_subgraph_redirects {
    for subgraph in graph.subgraphs {
      collect_subgraph_edge_redirects(
        subgraph, subgraph_entry_by_id, subgraph_exit_by_id,
      )
    }
  }
  let hidden_subgraph_node_ids : Map[String, Bool] = {}
  if use_subgraph_redirects {
    collect_hidden_subgraph_node_ids(
      graph.subgraphs,
      subgraph_entry_by_id,
      subgraph_exit_by_id,
      hidden_subgraph_node_ids,
    )
  }

  let nodes_in_order : Array[MermaidNode] = []
  for entry in graph.nodes.to_array() {
    let (node_id, node) = entry
    if !hidden_subgraph_node_ids.contains(node_id) {
      nodes_in_order.push(node)
    }
  }
  let positioned_nodes : Array[PositionedNode] = []
  let positioned_by_id : Map[String, PositionedNode] = {}
  let state_lane_by_node_id : Map[String, Int] = {}
  let state_label_y_offset_by_node_id : Map[String, Int] = {}
  if flat_state_graph {
    let node_order_by_id : Map[String, Int] = {}
    let node_shape_by_id : Map[String, NodeShape] = {}
    let lane_assigned : Map[String, Bool] = {}
    for i, node in nodes_in_order {
      node_order_by_id[node.id] = i
      node_shape_by_id[node.id] = node.shape
      state_lane_by_node_id[node.id] = 0
    }

    for node in nodes_in_order {
      match node.shape {
        NodeShape::StateStart | NodeShape::StateEnd => ()
        _ => {
          lane_assigned[node.id] = true
          break
        }
      }
    }

    let forward_extra_rows_by_order : Map[Int, Int] = {}
    for edge in graph.edges {
      let source_order = option_int_or(node_order_by_id.get(edge.source), -1)
      let target_order = option_int_or(node_order_by_id.get(edge.target), -1)
      if source_order < 0 || target_order < 0 || target_order <= source_order {
        continue
      }
      let mut extra_rows = 0
      if edge.label is Some(_) {
        extra_rows += 1
      }
      let target_is_state_end = match node_shape_by_id.get(edge.target) {
        Some(shape) =>
          match shape {
            NodeShape::StateEnd => true
            _ => false
          }
        None => false
      }
      if target_is_state_end {
        extra_rows += 2
      }
      if extra_rows <= 0 {
        continue
      }
      let current = option_int_or(forward_extra_rows_by_order.get(target_order), 0)
      forward_extra_rows_by_order[target_order] = current + extra_rows
    }
    let label_row_units = 10
    let mut cumulative_label_offset = 0
    for i, node in nodes_in_order {
      let step_count = option_int_or(forward_extra_rows_by_order.get(i), 0)
      cumulative_label_offset += step_count * label_row_units
      state_label_y_offset_by_node_id[node.id] = cumulative_label_offset
    }

    let forward_targets_by_source : Map[String, Array[String]] = {}
    for edge in graph.edges {
      let source_order = option_int_or(node_order_by_id.get(edge.source), -1)
      let target_order = option_int_or(node_order_by_id.get(edge.target), -1)
      if source_order < 0 || target_order < 0 || target_order <= source_order {
        continue
      }

      let target_is_pseudostate = match node_shape_by_id.get(edge.target) {
        Some(shape) =>
          match shape {
            NodeShape::StateStart | NodeShape::StateEnd => true
            _ => false
          }
        None => false
      }
      if target_is_pseudostate {
        continue
      }

      if !forward_targets_by_source.contains(edge.source) {
        forward_targets_by_source[edge.source] = []
      }
      let targets = forward_targets_by_source[edge.source]
      if !targets.contains(edge.target) {
        targets.push(edge.target)
      }
    }

    for node in nodes_in_order {
      let source_lane = option_int_or(state_lane_by_node_id.get(node.id), 0)
      match forward_targets_by_source.get(node.id) {
        Some(targets) => {
          for i, target_id in targets {
            if lane_assigned.contains(target_id) {
              continue
            }
            state_lane_by_node_id[target_id] = source_lane + i * 2
            lane_assigned[target_id] = true
          }
        }
        None => ()
      }
    }
  }

  let mut max_right = padding
  let mut max_bottom = padding

  let total_nodes = nodes_in_order.length()
  let state_lane_step = (node_spacing / 3).max(26)
  for i, node in nodes_in_order {
    let order_index = if reverse { total_nodes - 1 - i } else { i }
    let (width, height) = node_dimensions(node)
    let x = if horizontal {
      padding + order_index * node_spacing + width / 2
    } else if flat_state_graph {
      padding +
      90 +
      option_int_or(state_lane_by_node_id.get(node.id), 0) * state_lane_step
    } else {
      padding + 90
    }
    let y = if horizontal {
      padding + 70
    } else {
      padding +
      order_index * layer_spacing +
      height / 2 +
      option_int_or(state_label_y_offset_by_node_id.get(node.id), 0)
    }
    let positioned = PositionedNode::{
      id: node.id,
      label: node.label,
      shape: node.shape,
      x,
      y,
      width,
      height,
      inline_style: resolve_inline_style(graph, node.id),
    }
    positioned_nodes.push(positioned)
    positioned_by_id[node.id] = positioned
    max_right = max_right.max(x + width / 2)
    max_bottom = max_bottom.max(y + height / 2)
  }

  let positioned_index_by_id : Map[String, Int] = {}
  for i, node in positioned_nodes {
    positioned_index_by_id[node.id] = i
  }
  let node_horizontal_by_id : Map[String, Bool] = {}
  apply_subgraph_direction_overrides(
    graph.subgraphs,
    horizontal,
    reverse,
    false,
    horizontal,
    reverse,
    node_spacing,
    layer_spacing,
    positioned_nodes,
    positioned_index_by_id,
    node_horizontal_by_id,
  )

  max_right = padding
  max_bottom = padding
  for node in positioned_nodes {
    positioned_by_id[node.id] = node
    max_right = max_right.max(node.x + node.width / 2)
    max_bottom = max_bottom.max(node.y + node.height / 2)
  }

  let positioned_groups : Array[PositionedGroup] = []
  let mut empty_group_top = padding
  for subgraph in graph.subgraphs {
    match
      build_positioned_group(subgraph, positioned_by_id, horizontal, reverse) {
      Some(group) => positioned_groups.push(group)
      None => {
        let empty_group = build_empty_group_tree_at(
          subgraph, padding, empty_group_top, horizontal, reverse,
        )
        positioned_groups.push(empty_group)
        empty_group_top = empty_group_top +
          empty_group.height +
          subgraph_group_padding()
      }
    }
  }

  if state_graph {
    shift_top_level_state_subgraphs_right(
      graph,
      node_spacing,
      layer_spacing,
      positioned_nodes,
      positioned_groups,
      positioned_index_by_id,
      positioned_by_id,
    )
  }

  for group in positioned_groups {
    register_group_anchors(group, positioned_by_id, state_graph)
  }

  let positioned_edges : Array[PositionedEdge] = []
  let label_slots_by_anchor : Map[String, Int] = {}
  for edge in graph.edges {
    let resolved_source_id = if use_subgraph_redirects {
      match subgraph_exit_by_id.get(edge.source) {
        Some(found) => found
        None => edge.source
      }
    } else {
      edge.source
    }
    let resolved_target_id = if use_subgraph_redirects {
      match subgraph_entry_by_id.get(edge.target) {
        Some(found) => found
        None => edge.target
      }
    } else {
      edge.target
    }
    match
      (
        positioned_by_id.get(resolved_source_id),
        positioned_by_id.get(resolved_target_id),
      ) {
      (Some(source), Some(target)) => {
        let edge_horizontal = match
          (
            node_horizontal_by_id.get(resolved_source_id),
            node_horizontal_by_id.get(resolved_target_id),
          ) {
          (Some(source_horizontal), Some(target_horizontal)) =>
            if source_horizontal == target_horizontal {
              source_horizontal
            } else {
              horizontal
            }
          _ => horizontal
        }
        let points = edge_points_for(source, target, edge_horizontal)
        let label_position = match edge.label {
          Some(_) => {
            let base = midpoint(points[0], points[1])
            let key = label_anchor_key(base)
            let slot = option_int_or(label_slots_by_anchor.get(key), 0)
            label_slots_by_anchor[key] = slot + 1
            let label_x = if state_graph {
              base.x + label_overlap_offset_x(slot)
            } else {
              base.x
            }
            Some(Point::{ x: label_x, y: base.y + label_overlap_offset(slot) })
          }
          None => None
        }
        positioned_edges.push(PositionedEdge::{
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
      }
      _ => ()
    }
  }

  let mut global_min_x = padding
  let mut global_min_y = padding
  let mut global_max_x = max_right
  let mut global_max_y = max_bottom

  for node in positioned_nodes {
    global_min_x = global_min_x.min(node.x - node.width / 2)
    global_min_y = global_min_y.min(node.y - node.height / 2)
    global_max_x = global_max_x.max(node.x + node.width / 2)
    global_max_y = global_max_y.max(node.y + node.height / 2)
  }
  for edge in positioned_edges {
    for point in edge.points {
      global_min_x = global_min_x.min(point.x)
      global_min_y = global_min_y.min(point.y)
      global_max_x = global_max_x.max(point.x)
      global_max_y = global_max_y.max(point.y)
    }
    match edge.label_position {
      Some(position) => {
        global_min_x = global_min_x.min(position.x)
        global_min_y = global_min_y.min(position.y)
        global_max_x = global_max_x.max(position.x)
        global_max_y = global_max_y.max(position.y)
      }
      None => ()
    }
  }
  for group in positioned_groups {
    global_min_x = global_min_x.min(positioned_group_min_x(group))
    global_min_y = global_min_y.min(positioned_group_min_y(group))
    global_max_x = global_max_x.max(positioned_group_max_x(group))
    global_max_y = global_max_y.max(positioned_group_max_y(group))
  }

  let shift_x = if global_min_x < padding { padding - global_min_x } else { 0 }
  let shift_y = if global_min_y < padding { padding - global_min_y } else { 0 }
  if shift_x > 0 || shift_y > 0 {
    for i, node in positioned_nodes {
      positioned_nodes[i] = PositionedNode::{
        id: node.id,
        label: node.label,
        shape: node.shape,
        x: node.x + shift_x,
        y: node.y + shift_y,
        width: node.width,
        height: node.height,
        inline_style: node.inline_style,
      }
    }
    for i, edge in positioned_edges {
      let shifted_points : Array[Point] = []
      for point in edge.points {
        shifted_points.push(Point::{
          x: point.x + shift_x,
          y: point.y + shift_y,
        })
      }
      let shifted_label = match edge.label_position {
        Some(position) =>
          Some(Point::{ x: position.x + shift_x, y: position.y + shift_y })
        None => None
      }
      positioned_edges[i] = PositionedEdge::{
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
    for i, group in positioned_groups {
      positioned_groups[i] = shift_positioned_group(group, shift_x, shift_y)
    }
  }

  PositionedGraph::{
    width: global_max_x + shift_x + padding,
    height: global_max_y + shift_y + padding,
    nodes: positioned_nodes,
    edges: positioned_edges,
    groups: positioned_groups,
    sequence_lifelines: [],
    sequence_activations: [],
    sequence_blocks: [],
    sequence_notes: [],
  }
}
