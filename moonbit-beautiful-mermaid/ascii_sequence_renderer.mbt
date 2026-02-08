///|
fn sequence_label(node : MermaidNode) -> String {
  if node.label == "" {
    node.id
  } else {
    node.label
  }
}

///|
fn sequence_is_filled_arrow(operator : String?) -> Bool {
  match operator {
    Some(op) => op.contains(">>") || op.contains("x")
    None => false
  }
}

///|
fn ascii_sequence_operator_has_suffix(
  operator : String?,
  suffix : String,
) -> Bool {
  match operator {
    Some(op) => op.has_suffix(suffix)
    None => false
  }
}

///|
fn make_canvas(width : Int, height : Int) -> Array[Array[String]] {
  let canvas : Array[Array[String]] = []
  for _ in 0..<height {
    let row : Array[String] = []
    for _ in 0..<width {
      row.push(" ")
    }
    canvas.push(row)
  }
  canvas
}

///|
fn put_canvas(
  canvas : Array[Array[String]],
  x : Int,
  y : Int,
  value : String,
) -> Unit {
  if x < 0 || y < 0 || y >= canvas.length() || x >= canvas[y].length() {
    return
  }
  canvas[y][x] = value
}

///|
fn write_canvas_text(
  canvas : Array[Array[String]],
  x : Int,
  y : Int,
  text : String,
) -> Unit {
  if y < 0 || y >= canvas.length() {
    return
  }
  for i in 0..<text.length() {
    let target_x = x + i
    if target_x >= 0 && target_x < canvas[y].length() {
      put_canvas(canvas, target_x, y, (try! text[i:i + 1]).to_string())
    }
  }
}

///|
fn draw_actor_box(
  canvas : Array[Array[String]],
  center_x : Int,
  top_y : Int,
  label : String,
  box_pad : Int,
  h : String,
  v : String,
  tl : String,
  tr : String,
  bl : String,
  br : String,
) -> Unit {
  let width = label.length() + 2 * box_pad + 2
  let left = center_x - width / 2

  put_canvas(canvas, left, top_y, tl)
  for x in 1..<(width - 1) {
    put_canvas(canvas, left + x, top_y, h)
  }
  put_canvas(canvas, left + width - 1, top_y, tr)

  put_canvas(canvas, left, top_y + 1, v)
  put_canvas(canvas, left + width - 1, top_y + 1, v)
  write_canvas_text(canvas, left + 1 + box_pad, top_y + 1, label)

  put_canvas(canvas, left, top_y + 2, bl)
  for x in 1..<(width - 1) {
    put_canvas(canvas, left + x, top_y + 2, h)
  }
  put_canvas(canvas, left + width - 1, top_y + 2, br)
}

///|
fn canvas_to_output(canvas : Array[Array[String]]) -> String {
  let lines : Array[String] = []
  for row in canvas {
    lines.push(row.iter().join("").trim_end().to_string())
  }
  lines.iter().join("\n")
}

///|
fn ascii_sequence_block_type_text(block_type : SequenceBlockType) -> String {
  match block_type {
    SequenceBlockType::Loop => "loop"
    SequenceBlockType::Alt => "alt"
    SequenceBlockType::Opt => "opt"
    SequenceBlockType::Par => "par"
    SequenceBlockType::Critical => "critical"
    SequenceBlockType::Break => "break"
    SequenceBlockType::Rect => "rect"
  }
}

///|
fn sequence_ordered_actors(graph : MermaidGraph) -> Array[MermaidNode] {
  let ordered : Array[MermaidNode] = []
  let seen : Map[String, Bool] = {}
  for actor_id in graph.sequence_actor_order {
    match graph.nodes.get(actor_id) {
      Some(actor) => {
        ordered.push(actor)
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
fn sequence_note_lines(text : String) -> Array[String] {
  let escaped = text.split("\\n").map(line => line.to_string()).to_array()
  if escaped.length() > 1 {
    escaped
  } else {
    text.split("\n").map(line => line.to_string()).to_array()
  }
}

///|
priv struct SequenceAsciiNoteLayout {
  x : Int
  y : Int
  width : Int
  height : Int
  lines : Array[String]
}

///|
priv struct SequenceAsciiActivation {
  actor_idx : Int
  top_y : Int
  bottom_y : Int
}

///|
fn ascii_sequence_apply_activation_command(
  command : SequenceActivationCommand,
  y : Int,
  actor_index : Map[String, Int],
  activation_starts : Map[String, Array[Int]],
  activations : Array[SequenceAsciiActivation],
) -> Unit {
  match actor_index.get(command.actor_id) {
    Some(actor_idx) =>
      if command.activate {
        let stack = activation_starts.get_or_init(command.actor_id, () => [])
        stack.push(y)
      } else {
        match activation_starts.get(command.actor_id) {
          Some(stack) =>
            if stack.length() > 0 {
              let last_index = stack.length() - 1
              let top_y = stack[last_index]
              let next_stack : Array[Int] = []
              for i in 0..<last_index {
                next_stack.push(stack[i])
              }
              activation_starts[command.actor_id] = next_stack
              activations.push(SequenceAsciiActivation::{
                actor_idx,
                top_y,
                bottom_y: y,
              })
            }
          None => ()
        }
      }
    None => ()
  }
}

///|
fn render_ascii_sequence(
  graph : MermaidGraph,
  options : AsciiRenderOptions,
) -> String {
  let actors = sequence_ordered_actors(graph)
  if actors.length() == 0 {
    return ""
  }

  let use_ascii = options.use_ascii
  let h = if use_ascii { "-" } else { "─" }
  let dashed_h = if use_ascii { "." } else { "╌" }
  let v = if use_ascii { "|" } else { "│" }
  let tl = if use_ascii { "+" } else { "┌" }
  let tr = if use_ascii { "+" } else { "┐" }
  let bl = if use_ascii { "+" } else { "└" }
  let br = if use_ascii { "+" } else { "┘" }
  let jt = if use_ascii { "+" } else { "┬" }
  let jb = if use_ascii { "+" } else { "┴" }
  let jl = if use_ascii { "+" } else { "├" }
  let jr = if use_ascii { "+" } else { "┤" }
  let top_right = if use_ascii { "+" } else { "┐" }
  let bottom_right = if use_ascii { "+" } else { "┘" }

  let actor_index : Map[String, Int] = {}
  for i, actor in actors {
    actor_index[actor.id] = i
  }

  let box_pad = 1
  let actor_box_h = 3
  let actor_widths : Array[Int] = []
  let half_box : Array[Int] = []
  for actor in actors {
    let width = sequence_label(actor).length() + 2 * box_pad + 2
    actor_widths.push(width)
    half_box.push((width + 1) / 2)
  }

  let gap_count = if actors.length() > 0 { actors.length() - 1 } else { 0 }
  let adjacent_width : Array[Int] = []
  for _ in 0..<gap_count {
    adjacent_width.push(0)
  }

  for edge in graph.edges {
    match (actor_index.get(edge.source), actor_index.get(edge.target)) {
      (Some(fi), Some(ti)) =>
        if fi != ti {
          let lo = if fi < ti { fi } else { ti }
          let hi = if fi > ti { fi } else { ti }
          let label_len = match edge.label {
            Some(label) => label.length()
            None => 0
          }
          let needed = label_len + 4
          let num_gaps = hi - lo
          let per_gap = (needed + num_gaps - 1) / num_gaps
          for g in lo..<hi {
            if per_gap > adjacent_width[g] {
              adjacent_width[g] = per_gap
            }
          }
        }
      _ => ()
    }
  }

  let lifeline_x : Array[Int] = [half_box[0]]
  for i in 1..<actors.length() {
    let gap1 = half_box[i - 1] + half_box[i] + 2
    let gap2 = adjacent_width[i - 1] + 2
    let mut gap = 10
    if gap1 > gap {
      gap = gap1
    }
    if gap2 > gap {
      gap = gap2
    }
    lifeline_x.push(lifeline_x[i - 1] + gap)
  }

  let message_arrow_y : Array[Int] = []
  let message_label_y : Array[Int] = []
  let block_start_y : Array[Int] = []
  let block_end_y : Array[Int] = []
  for _ in 0..<graph.sequence_blocks.length() {
    block_start_y.push(-1)
    block_end_y.push(-1)
  }
  let divider_y_map : Map[String, Int] = {}
  let note_positions : Array[SequenceAsciiNoteLayout] = []
  let activations : Array[SequenceAsciiActivation] = []

  let mut cur_y = actor_box_h
  for message_index, edge in graph.edges {
    for block_index, block in graph.sequence_blocks {
      if block.start_index == message_index {
        cur_y = cur_y + 2
        block_start_y[block_index] = cur_y - 1
      }
    }

    for block_index, block in graph.sequence_blocks {
      for divider_index, divider in block.dividers {
        if divider.index == message_index {
          cur_y = cur_y + 1
          divider_y_map["\{block_index}:\{divider_index}"] = cur_y
          cur_y = cur_y + 1
        }
      }
    }

    cur_y = cur_y + 1
    if edge.source == edge.target {
      message_label_y.push(cur_y + 1)
      message_arrow_y.push(cur_y)
      cur_y = cur_y + 3
    } else {
      message_label_y.push(cur_y)
      message_arrow_y.push(cur_y + 1)
      cur_y = cur_y + 2
    }

    for note in graph.sequence_notes {
      if note.after_index == message_index && note.actor_ids.length() > 0 {
        cur_y = cur_y + 1

        let lines = sequence_note_lines(note.text)
        let mut max_len = 0
        for line in lines {
          max_len = max_len.max(line.length())
        }
        let width = max_len + 4
        let height = lines.length() + 2

        let actor_idx = option_int_or(actor_index.get(note.actor_ids[0]), 0)
        let mut note_x = match note.position {
          SequenceNotePosition::Left => lifeline_x[actor_idx] - width - 1
          SequenceNotePosition::Right => lifeline_x[actor_idx] + 2
          SequenceNotePosition::Over =>
            if note.actor_ids.length() >= 2 {
              let second_actor = note.actor_ids[note.actor_ids.length() - 1]
              let second_idx = option_int_or(
                actor_index.get(second_actor),
                actor_idx,
              )
              (lifeline_x[actor_idx] + lifeline_x[second_idx]) / 2 - width / 2
            } else {
              lifeline_x[actor_idx] - width / 2
            }
        }
        if note_x < 0 {
          note_x = 0
        }

        note_positions.push(SequenceAsciiNoteLayout::{
          x: note_x,
          y: cur_y,
          width,
          height,
          lines,
        })
        cur_y = cur_y + height
      }
    }

    for block_index, block in graph.sequence_blocks {
      if block.end_index == message_index {
        cur_y = cur_y + 1
        block_end_y[block_index] = cur_y
        cur_y = cur_y + 1
      }
    }
  }

  cur_y = cur_y + 1
  let footer_y = cur_y
  let total_h = footer_y + actor_box_h

  let mut total_w = lifeline_x[lifeline_x.length() - 1] +
    half_box[half_box.length() - 1] +
    2

  for edge in graph.edges {
    if edge.source != edge.target {
      continue
    }
    match actor_index.get(edge.source) {
      Some(fi) => {
        let label_len = match edge.label {
          Some(label) => label.length()
          None => 0
        }
        let self_right = lifeline_x[fi] + 8 + label_len
        if self_right + 1 > total_w {
          total_w = self_right + 1
        }
      }
      None => ()
    }
  }

  for note_position in note_positions {
    let right = note_position.x + note_position.width + 1
    if right > total_w {
      total_w = right
    }
  }

  let activation_starts : Map[String, Array[Int]] = {}
  let activation_commands_by_after : Map[Int, Array[SequenceActivationCommand]] = {}
  for command in graph.sequence_activation_commands {
    let bucket = activation_commands_by_after.get_or_init(command.after_index, () => {
      []
    })
    bucket.push(command)
  }
  let initial_row_y = if message_arrow_y.length() > 0 {
    message_arrow_y[0]
  } else {
    actor_box_h + 1
  }
  match activation_commands_by_after.get(-1) {
    Some(commands) =>
      for command in commands {
        ascii_sequence_apply_activation_command(
          command, initial_row_y, actor_index, activation_starts, activations,
        )
      }
    None => ()
  }
  for edge_index, edge in graph.edges {
    let row_y = message_arrow_y[edge_index]
    if ascii_sequence_operator_has_suffix(edge.relation_operator, "+") {
      ascii_sequence_apply_activation_command(
        SequenceActivationCommand::{
          actor_id: edge.target,
          activate: true,
          after_index: edge_index,
        },
        row_y,
        actor_index,
        activation_starts,
        activations,
      )
    }
    if ascii_sequence_operator_has_suffix(edge.relation_operator, "-") {
      ascii_sequence_apply_activation_command(
        SequenceActivationCommand::{
          actor_id: edge.source,
          activate: false,
          after_index: edge_index,
        },
        row_y,
        actor_index,
        activation_starts,
        activations,
      )
    }
    match activation_commands_by_after.get(edge_index) {
      Some(commands) => {
        let command_row_y = row_y +
          (if edge.source == edge.target { 2 } else { 1 })
        for command in commands {
          ascii_sequence_apply_activation_command(
            command, command_row_y, actor_index, activation_starts, activations,
          )
        }
      }
      None => ()
    }
  }
  for entry in activation_starts.to_array() {
    let (actor_id, stack) = entry
    match actor_index.get(actor_id) {
      Some(actor_idx) =>
        for top_y in stack {
          activations.push(SequenceAsciiActivation::{
            actor_idx,
            top_y,
            bottom_y: (footer_y - 1).max(top_y + 1),
          })
        }
      None => ()
    }
  }

  let canvas = make_canvas(total_w, total_h)

  for i in 0..<actors.length() {
    let x = lifeline_x[i]
    for y in actor_box_h..<=footer_y {
      put_canvas(canvas, x, y, v)
    }
  }

  for i, actor in actors {
    let label = sequence_label(actor)
    draw_actor_box(
      canvas,
      lifeline_x[i],
      0,
      label,
      box_pad,
      h,
      v,
      tl,
      tr,
      bl,
      br,
    )
    draw_actor_box(
      canvas,
      lifeline_x[i],
      footer_y,
      label,
      box_pad,
      h,
      v,
      tl,
      tr,
      bl,
      br,
    )
    if !use_ascii {
      put_canvas(canvas, lifeline_x[i], actor_box_h - 1, jt)
      put_canvas(canvas, lifeline_x[i], footer_y, jb)
    }
  }

  let activation_tl = if use_ascii { "+" } else { "┌" }
  let activation_tr = if use_ascii { "+" } else { "┐" }
  let activation_bl = if use_ascii { "+" } else { "└" }
  let activation_br = if use_ascii { "+" } else { "┘" }
  let activation_h = h
  let activation_v = v
  for activation in activations {
    let center_x = lifeline_x[activation.actor_idx]
    let left = center_x - 1
    let right = center_x + 1
    let top = activation.top_y
    let bottom = activation.bottom_y
    if top >= bottom {
      continue
    }
    put_canvas(canvas, left, top, activation_tl)
    put_canvas(canvas, center_x, top, activation_h)
    put_canvas(canvas, right, top, activation_tr)
    for y in (top + 1)..<bottom {
      put_canvas(canvas, left, y, activation_v)
      put_canvas(canvas, right, y, activation_v)
    }
    put_canvas(canvas, left, bottom, activation_bl)
    put_canvas(canvas, center_x, bottom, activation_h)
    put_canvas(canvas, right, bottom, activation_br)
  }

  for i, edge in graph.edges {
    match (actor_index.get(edge.source), actor_index.get(edge.target)) {
      (Some(fi), Some(ti)) => {
        let from_x = lifeline_x[fi]
        let to_x = lifeline_x[ti]
        let is_self = fi == ti
        let is_dashed = edge.style == EdgeStyle::Dotted
        let is_filled = sequence_is_filled_arrow(edge.relation_operator)
        let line_char = if is_dashed { dashed_h } else { h }
        let label = match edge.label {
          Some(found) => found
          None => ""
        }

        if is_self {
          let y0 = message_arrow_y[i]
          let loop_w = 4

          put_canvas(canvas, from_x, y0, jl)
          for x in (from_x + 1)..<(from_x + loop_w) {
            put_canvas(canvas, x, y0, line_char)
          }
          put_canvas(canvas, from_x + loop_w, y0, top_right)

          put_canvas(canvas, from_x + loop_w, y0 + 1, v)
          write_canvas_text(canvas, from_x + loop_w + 2, y0 + 1, label)

          let arrow = if is_filled {
            if use_ascii {
              "<"
            } else {
              "◀"
            }
          } else if use_ascii {
            "<"
          } else {
            "◁"
          }
          put_canvas(canvas, from_x, y0 + 2, arrow)
          for x in (from_x + 1)..<(from_x + loop_w) {
            put_canvas(canvas, x, y0 + 2, line_char)
          }
          put_canvas(canvas, from_x + loop_w, y0 + 2, bottom_right)
        } else {
          let label_y = message_label_y[i]
          let arrow_y = message_arrow_y[i]

          let mid_x = (from_x + to_x) / 2
          let label_start = mid_x - label.length() / 2
          write_canvas_text(canvas, label_start, label_y, label)

          if from_x < to_x {
            for x in (from_x + 1)..<to_x {
              put_canvas(canvas, x, arrow_y, line_char)
            }
            let arrow = if is_filled {
              if use_ascii {
                ">"
              } else {
                "▶"
              }
            } else if use_ascii {
              ">"
            } else {
              "▷"
            }
            put_canvas(canvas, to_x, arrow_y, arrow)
          } else {
            for x in (to_x + 1)..<from_x {
              put_canvas(canvas, x, arrow_y, line_char)
            }
            let arrow = if is_filled {
              if use_ascii {
                "<"
              } else {
                "◀"
              }
            } else if use_ascii {
              "<"
            } else {
              "◁"
            }
            put_canvas(canvas, to_x, arrow_y, arrow)
          }
        }
      }
      _ => ()
    }
  }

  for block_index, block in graph.sequence_blocks {
    let top_y = block_start_y[block_index]
    let bottom_y = block_end_y[block_index]
    if top_y < 0 || bottom_y < 0 {
      continue
    }

    let mut min_lx = total_w
    let mut max_lx = 0
    let mut has_message = false
    if block.start_index <= block.end_index {
      for message_index in block.start_index..<=block.end_index {
        if message_index >= graph.edges.length() {
          continue
        }
        let message = graph.edges[message_index]
        match
          (actor_index.get(message.source), actor_index.get(message.target)) {
          (Some(from_idx), Some(to_idx)) => {
            has_message = true
            let left_idx = if from_idx < to_idx { from_idx } else { to_idx }
            let right_idx = if from_idx > to_idx { from_idx } else { to_idx }
            min_lx = min_lx.min(lifeline_x[left_idx])
            max_lx = max_lx.max(lifeline_x[right_idx])
          }
          _ => ()
        }
      }
    }

    if !has_message {
      min_lx = lifeline_x[0]
      max_lx = lifeline_x[lifeline_x.length() - 1]
    }

    let block_left = (min_lx - 4).max(0)
    let block_right = (max_lx + 4).min(total_w - 1)

    put_canvas(canvas, block_left, top_y, tl)
    for x in (block_left + 1)..<block_right {
      put_canvas(canvas, x, top_y, h)
    }
    put_canvas(canvas, block_right, top_y, tr)

    let header = if block.label == "" {
      ascii_sequence_block_type_text(block.block_type)
    } else {
      "\{ascii_sequence_block_type_text(block.block_type)} [\{block.label}]"
    }
    for i in 0..<header.length() {
      let x = block_left + 1 + i
      if x < block_right {
        put_canvas(canvas, x, top_y, (try! header[i:i + 1]).to_string())
      }
    }

    put_canvas(canvas, block_left, bottom_y, bl)
    for x in (block_left + 1)..<block_right {
      put_canvas(canvas, x, bottom_y, h)
    }
    put_canvas(canvas, block_right, bottom_y, br)

    for y in (top_y + 1)..<bottom_y {
      put_canvas(canvas, block_left, y, v)
      put_canvas(canvas, block_right, y, v)
    }

    let divider_char = if use_ascii { "-" } else { "╌" }
    for divider_index, divider in block.dividers {
      let key = "\{block_index}:\{divider_index}"
      match divider_y_map.get(key) {
        Some(divider_y) => {
          put_canvas(canvas, block_left, divider_y, jl)
          for x in (block_left + 1)..<block_right {
            put_canvas(canvas, x, divider_y, divider_char)
          }
          put_canvas(canvas, block_right, divider_y, jr)

          if divider.label != "" {
            let divider_text = "[\{divider.label}]"
            for i in 0..<divider_text.length() {
              let x = block_left + 1 + i
              if x < block_right {
                put_canvas(
                  canvas,
                  x,
                  divider_y,
                  (try! divider_text[i:i + 1]).to_string(),
                )
              }
            }
          }
        }
        None => ()
      }
    }
  }

  for note_position in note_positions {
    let left = note_position.x
    let top = note_position.y
    let width = note_position.width
    let height = note_position.height

    put_canvas(canvas, left, top, tl)
    for x in 1..<(width - 1) {
      put_canvas(canvas, left + x, top, h)
    }
    put_canvas(canvas, left + width - 1, top, tr)

    for line_index, line in note_position.lines {
      let y = top + 1 + line_index
      put_canvas(canvas, left, y, v)
      put_canvas(canvas, left + width - 1, y, v)
      write_canvas_text(canvas, left + 2, y, line)
    }

    let bottom = top + height - 1
    put_canvas(canvas, left, bottom, bl)
    for x in 1..<(width - 1) {
      put_canvas(canvas, left + x, bottom, h)
    }
    put_canvas(canvas, left + width - 1, bottom, br)
  }

  canvas_to_output(canvas)
}
