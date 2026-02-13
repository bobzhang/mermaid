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
    lines.push(row.iter().join(""))
  }
  lines.iter().join("\n")
}

///|
fn ascii_sequence_block_type_text(block_type : SequenceBlockType) -> String {
  match block_type {
    Loop => "loop"
    Alt => "alt"
    Opt => "opt"
    Par => "par"
    Critical => "critical"
    Break => "break"
    Rect => "rect"
  }
}

///|
/// Renders a sequence diagram as ASCII/Unicode text art.
pub fn render_ascii_sequence(
  graph : MermaidGraph,
  sequence_layout : @renderer_ascii_layout_plan.AsciiSequenceLayout,
  options : AsciiRenderOptions,
) -> String {
  let actors = sequence_layout.actors
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

  let box_pad = 1
  let actor_box_h = 3

  let actor_index = sequence_layout.actor_index
  let lifeline_x = sequence_layout.lifeline_x
  let message_arrow_y = sequence_layout.message_arrow_y
  let message_label_y = sequence_layout.message_label_y
  let block_start_y = sequence_layout.block_start_y
  let block_end_y = sequence_layout.block_end_y
  let divider_y_map = sequence_layout.divider_y_map
  let note_positions = sequence_layout.note_positions
  let activations = sequence_layout.activations
  let footer_y = sequence_layout.footer_y
  let total_w = sequence_layout.total_w
  let total_h = sequence_layout.total_h

  let canvas = make_canvas(total_w + 1, total_h)
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

  for activation in activations {
    let _actor_idx = activation.actor_idx
    let _top_y = activation.top_y
    let _bottom_y = activation.bottom_y
    ()
  }

  for i, edge in graph.edges {
    match (actor_index.get(edge.source), actor_index.get(edge.target)) {
      (Some(fi), Some(ti)) => {
        let from_x = lifeline_x[fi]
        let to_x = lifeline_x[ti]
        let is_self = fi == ti
        let is_dashed = edge.style == Dotted
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
