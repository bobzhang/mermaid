///|
fn class_multibox_size(sections : Array[Array[String]]) -> (Int, Int) {
  let mut max_text_width = 0
  for section in sections {
    for line in section {
      if line.length() > max_text_width {
        max_text_width = line.length()
      }
    }
  }
  let mut total_lines = 0
  for section in sections {
    total_lines = total_lines + section.length().max(1)
  }
  let box_width = max_text_width + 4
  let box_height = total_lines + sections.length() - 1 + 2
  (box_width, box_height)
}

///|
fn class_draw_multibox(
  canvas : Array[Array[String]],
  left : Int,
  top : Int,
  sections : Array[Array[String]],
  use_ascii : Bool,
) -> Unit {
  let h_line = if use_ascii { "-" } else { "─" }
  let v_line = if use_ascii { "|" } else { "│" }
  let tl = if use_ascii { "+" } else { "┌" }
  let tr = if use_ascii { "+" } else { "┐" }
  let bl = if use_ascii { "+" } else { "└" }
  let br = if use_ascii { "+" } else { "┘" }
  let div_l = if use_ascii { "+" } else { "├" }
  let div_r = if use_ascii { "+" } else { "┤" }

  let (box_width, box_height) = class_multibox_size(sections)

  put_canvas(canvas, left, top, tl)
  for x in 1..<(box_width - 1) {
    put_canvas(canvas, left + x, top, h_line)
  }
  put_canvas(canvas, left + box_width - 1, top, tr)

  put_canvas(canvas, left, top + box_height - 1, bl)
  for x in 1..<(box_width - 1) {
    put_canvas(canvas, left + x, top + box_height - 1, h_line)
  }
  put_canvas(canvas, left + box_width - 1, top + box_height - 1, br)

  for y in 1..<(box_height - 1) {
    put_canvas(canvas, left, top + y, v_line)
    put_canvas(canvas, left + box_width - 1, top + y, v_line)
  }

  let mut row = top + 1
  for s, section in sections {
    let lines = if section.length() == 0 { [""] } else { section }
    for line in lines {
      write_canvas_text(canvas, left + 2, row, line)
      row = row + 1
    }
    if s < sections.length() - 1 {
      put_canvas(canvas, left, row, div_l)
      for x in 1..<(box_width - 1) {
        put_canvas(canvas, left + x, row, h_line)
      }
      put_canvas(canvas, left + box_width - 1, row, div_r)
      row = row + 1
    }
  }
}

///|
fn class_relation_meta(operator : String?) -> (String, Bool, Bool, Bool) {
  match operator {
    Some(op) =>
      if op is [.. "<|", ..] {
        let rel_type = if op.contains(".") {
          "realization"
        } else {
          "inheritance"
        }
        (rel_type, false, rel_type == "realization", true)
      } else if op is [.., .. "|>"] {
        let rel_type = if op.contains(".") {
          "realization"
        } else {
          "inheritance"
        }
        (rel_type, true, rel_type == "realization", true)
      } else if op is [.. "*", ..] {
        ("composition", false, false, false)
      } else if op is [.., .. "*"] {
        ("composition", true, false, false)
      } else if op is [.. "o", ..] {
        ("aggregation", false, false, false)
      } else if op is [.., .. "o"] {
        ("aggregation", true, false, false)
      } else if op.contains(".") {
        ("dependency", true, true, false)
      } else {
        ("association", true, false, false)
      }
    None => ("association", true, false, false)
  }
}

///|
fn class_marker_shape(
  rel_type : String,
  use_ascii : Bool,
  direction : String,
) -> String {
  match rel_type {
    "inheritance" | "realization" =>
      if direction == "down" {
        if use_ascii {
          "^"
        } else {
          "△"
        }
      } else if direction == "up" {
        if use_ascii {
          "v"
        } else {
          "▽"
        }
      } else if direction == "left" {
        if use_ascii {
          ">"
        } else {
          "◁"
        }
      } else if use_ascii {
        "<"
      } else {
        "▷"
      }
    "composition" => if use_ascii { "*" } else { "◆" }
    "aggregation" => if use_ascii { "o" } else { "◇" }
    "association" | "dependency" =>
      if direction == "down" {
        if use_ascii {
          "v"
        } else {
          "▼"
        }
      } else if direction == "up" {
        if use_ascii {
          "^"
        } else {
          "▲"
        }
      } else if direction == "left" {
        if use_ascii {
          "<"
        } else {
          "◀"
        }
      } else if use_ascii {
        ">"
      } else {
        "▶"
      }
    _ =>
      if direction == "left" {
        if use_ascii {
          "<"
        } else {
          "◀"
        }
      } else if use_ascii {
        ">"
      } else {
        "▶"
      }
  }
}

///|
fn class_draw_marker(
  canvas : Array[Array[String]],
  center_x : Int,
  y : Int,
  marker : String,
) -> Unit {
  let start_x = center_x - marker.length() / 2
  write_canvas_text(canvas, start_x, y, marker)
}

///|
/// Renders a class diagram as ASCII/Unicode text art.
pub fn render_ascii_class(
  graph : MermaidGraph,
  class_layout : @renderer_ascii_layout_plan.AsciiClassLayout,
  options : AsciiRenderOptions,
) -> String {
  let class_order = class_layout.class_order
  if class_order.length() == 0 {
    return ""
  }

  let use_ascii = options.use_ascii
  let class_sections_map = class_layout.class_sections_map
  let class_width = class_layout.class_width
  let class_height = class_layout.class_height
  let placed_x = class_layout.placed_x
  let placed_y = class_layout.placed_y
  let total_w = class_layout.total_w
  let total_h = class_layout.total_h

  let canvas = make_canvas(total_w, total_h)
  for class_id in class_order {
    let x = placed_x.get(class_id).unwrap()
    let y = placed_y.get(class_id).unwrap()
    let sections = class_sections_map.get(class_id).unwrap()
    class_draw_multibox(canvas, x, y, sections, use_ascii)
  }

  let line_h = if use_ascii { "-" } else { "─" }
  let line_v = if use_ascii { "|" } else { "│" }
  let dash_h = if use_ascii { "." } else { "╌" }
  let dash_v = if use_ascii { ":" } else { "┊" }

  for edge in graph.edges {
    match (placed_x.get(edge.source), placed_x.get(edge.target)) {
      (Some(from_x), Some(to_x)) => {
        let from_y = placed_y.get(edge.source).unwrap()
        let to_y = placed_y.get(edge.target).unwrap()
        let from_w = class_width.get(edge.source).unwrap()
        let from_h = class_height.get(edge.source).unwrap()
        let to_w = class_width.get(edge.target).unwrap()
        let to_h = class_height.get(edge.target).unwrap()

        let (rel_type, marker_at_to, dashed, hierarchical) = class_relation_meta(
          edge.relation_operator,
        )
        let line_h_char = if dashed { dash_h } else { line_h }
        let line_v_char = if dashed { dash_v } else { line_v }

        let from_cx = from_x + from_w / 2
        let from_by = from_y + from_h - 1
        let to_cx = to_x + to_w / 2
        let to_ty = to_y
        let to_by = to_y + to_h - 1

        let mut label_mid_y = 0

        if from_by < to_ty {
          let mid_y = from_by + (to_ty - from_by) / 2
          label_mid_y = (from_by + 1 + to_ty - 1) / 2

          for y in (from_by + 1)..<=mid_y {
            put_canvas(canvas, from_cx, y, line_v_char)
          }

          if from_cx != to_cx {
            let lx = if from_cx < to_cx { from_cx } else { to_cx }
            let rx = if from_cx > to_cx { from_cx } else { to_cx }
            for x in lx..<=rx {
              put_canvas(canvas, x, mid_y, line_h_char)
            }
            if !use_ascii {
              if from_cx < to_cx {
                put_canvas(canvas, from_cx, mid_y, "└")
                put_canvas(canvas, to_cx, mid_y, "┐")
              } else {
                put_canvas(canvas, from_cx, mid_y, "┘")
                put_canvas(canvas, to_cx, mid_y, "┌")
              }
            }
          }

          for y in (mid_y + 1)..<to_ty {
            put_canvas(canvas, to_cx, y, line_v_char)
          }

          if marker_at_to {
            let marker = class_marker_shape(rel_type, use_ascii, "down")
            class_draw_marker(canvas, to_cx, to_ty - 1, marker)
          } else {
            let marker = class_marker_shape(rel_type, use_ascii, "down")
            class_draw_marker(canvas, from_cx, from_by + 1, marker)
          }
        } else if to_by < from_y {
          let mid_y = to_by + (from_y - to_by) / 2
          label_mid_y = (to_by + 1 + from_y - 1) / 2

          for y in mid_y..<from_y {
            put_canvas(canvas, from_cx, y, line_v_char)
          }

          if from_cx != to_cx {
            let lx = if from_cx < to_cx { from_cx } else { to_cx }
            let rx = if from_cx > to_cx { from_cx } else { to_cx }
            for x in lx..<=rx {
              put_canvas(canvas, x, mid_y, line_h_char)
            }
            if !use_ascii {
              if from_cx < to_cx {
                put_canvas(canvas, from_cx, mid_y, "┌")
                put_canvas(canvas, to_cx, mid_y, "┘")
              } else {
                put_canvas(canvas, from_cx, mid_y, "┐")
                put_canvas(canvas, to_cx, mid_y, "└")
              }
            }
          }

          for y in (to_by + 1)..<mid_y {
            put_canvas(canvas, to_cx, y, line_v_char)
          }

          if !marker_at_to {
            let marker = class_marker_shape(rel_type, use_ascii, "up")
            class_draw_marker(canvas, from_cx, from_y - 1, marker)
          } else {
            let direction = if hierarchical { "down" } else { "up" }
            let marker = class_marker_shape(rel_type, use_ascii, direction)
            class_draw_marker(canvas, to_cx, to_by + 1, marker)
          }
        } else {
          let detour_y = from_by.max(to_by) + 2
          label_mid_y = detour_y

          for y in (from_by + 1)..<=detour_y {
            put_canvas(canvas, from_cx, y, line_v_char)
          }

          let lx = if from_cx < to_cx { from_cx } else { to_cx }
          let rx = if from_cx > to_cx { from_cx } else { to_cx }
          for x in lx..<=rx {
            put_canvas(canvas, x, detour_y, line_h_char)
          }

          for y in (to_by + 1)..<detour_y {
            put_canvas(canvas, to_cx, y, line_v_char)
          }

          if marker_at_to {
            let marker = class_marker_shape(rel_type, use_ascii, "up")
            class_draw_marker(canvas, to_cx, to_by + 1, marker)
          } else {
            let marker = class_marker_shape(rel_type, use_ascii, "down")
            class_draw_marker(canvas, from_cx, from_by + 1, marker)
          }
        }

        match edge.label {
          Some(label) =>
            if label != "" {
              let padded = " \{label} "
              let mid_x = (from_cx + to_cx) / 2
              let start_x = mid_x - padded.length() / 2
              write_canvas_text(canvas, start_x, label_mid_y, padded)
            }
          None => ()
        }
      }
      _ => ()
    }
  }

  canvas_to_output(canvas)
}
