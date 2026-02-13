///|
fn er_operator_tokens(operator : String?) -> (String, String) {
  match operator {
    Some(op) => {
      let dash_idx = op.find("-")
      let dot_idx = op.find(".")
      let start_sep = match (dash_idx, dot_idx) {
        (Some(a), Some(b)) => Some(a.min(b))
        (Some(a), None) => Some(a)
        (None, Some(b)) => Some(b)
        _ => None
      }
      let dash_last = op.rev_find("-")
      let dot_last = op.rev_find(".")
      let end_sep = match (dash_last, dot_last) {
        (Some(a), Some(b)) => Some(a.max(b))
        (Some(a), None) => Some(a)
        (None, Some(b)) => Some(b)
        _ => None
      }
      match (start_sep, end_sep) {
        (Some(start), Some(end)) =>
          (
            trim_owned((try! op[:start]).to_string()),
            trim_owned((try! op[end + 1:]).to_string()),
          )
        _ => ("", "")
      }
    }
    None => ("", "")
  }
}

///|
fn er_crows_foot_chars(token : String, use_ascii : Bool) -> String {
  if use_ascii {
    if token == "||" {
      "||"
    } else if token is ("o|" | "|o") {
      "o|"
    } else if token is ("|}" | "{|" | "|{" | "}|") {
      "}|"
    } else if token is ("{o" | "o{") {
      "o{"
    } else {
      token
    }
  } else if token == "||" {
    "║"
  } else if token is ("o|" | "|o") {
    "o║"
  } else if token is ("|}" | "{|" | "|{" | "}|") {
    "╟"
  } else if token is ("{o" | "o{") {
    "o╟"
  } else {
    token
  }
}

///|
fn er_ensure_canvas_size(
  canvas : Array[Array[String]],
  min_width : Int,
  min_height : Int,
) -> Unit {
  if min_width <= 0 || min_height <= 0 {
    return
  }

  let current_h = canvas.length()
  let current_w = if current_h == 0 { 0 } else { canvas[0].length() }

  if min_width > current_w {
    for row in canvas {
      for _ in current_w..<min_width {
        row.push(" ")
      }
    }
  }

  if min_height > current_h {
    let row_width = if min_width > current_w { min_width } else { current_w }
    for _ in current_h..<min_height {
      let row : Array[String] = []
      for _ in 0..<row_width {
        row.push(" ")
      }
      canvas.push(row)
    }
  }
}

///|
/// Renders an ER diagram as ASCII/Unicode text art.
pub fn render_ascii_er(
  graph : MermaidGraph,
  er_layout : @renderer_ascii_layout_plan.AsciiErLayout,
  options : AsciiRenderOptions,
) -> String {
  let entity_order = er_layout.entity_order
  if entity_order.length() == 0 {
    return ""
  }

  let use_ascii = options.use_ascii
  let entity_sections = er_layout.entity_sections
  let entity_width = er_layout.entity_width
  let entity_height = er_layout.entity_height
  let placed_x = er_layout.placed_x
  let placed_y = er_layout.placed_y
  let total_w = er_layout.total_w
  let total_h = er_layout.total_h

  let canvas = make_canvas(total_w, total_h)
  for entity_id in entity_order {
    let x = placed_x.get(entity_id).unwrap()
    let y = placed_y.get(entity_id).unwrap()
    let sections = entity_sections.get(entity_id).unwrap()
    class_draw_multibox(canvas, x, y, sections, use_ascii)
  }

  let h = if use_ascii { "-" } else { "─" }
  let v = if use_ascii { "|" } else { "│" }
  let dash_h = if use_ascii { "." } else { "╌" }
  let dash_v = if use_ascii { ":" } else { "┊" }

  for edge in graph.edges {
    match (placed_x.get(edge.source), placed_x.get(edge.target)) {
      (Some(sx), Some(tx)) => {
        let sy = placed_y.get(edge.source).unwrap()
        let ty = placed_y.get(edge.target).unwrap()
        let sw = entity_width.get(edge.source).unwrap()
        let sh = entity_height.get(edge.source).unwrap()
        let tw = entity_width.get(edge.target).unwrap()
        let th = entity_height.get(edge.target).unwrap()

        let line_h = if edge.style == Dotted { dash_h } else { h }
        let line_v = if edge.style == Dotted { dash_v } else { v }

        let scx = sx + sw / 2
        let scy = sy + sh / 2
        let tcx = tx + tw / 2
        let tcy = ty + th / 2
        let same_row = (scy - tcy).abs() < sh.max(th)

        let (left_token, right_token) = er_operator_tokens(
          edge.relation_operator,
        )

        if same_row {
          let left_is_source = scx < tcx
          let left_x = if left_is_source { sx } else { tx }
          let left_y = if left_is_source { sy } else { ty }
          let left_w = if left_is_source { sw } else { tw }
          let left_h = if left_is_source { sh } else { th }
          let right_x = if left_is_source { tx } else { sx }
          let left_token_value = if left_is_source {
            left_token
          } else {
            right_token
          }
          let right_token_value = if left_is_source {
            right_token
          } else {
            left_token
          }

          let start_x = left_x + left_w
          let end_x = right_x - 1
          let line_y = left_y + left_h / 2

          for x in start_x..<=end_x {
            put_canvas(canvas, x, line_y, line_h)
          }

          let left_chars = er_crows_foot_chars(left_token_value, use_ascii)
          write_canvas_text(canvas, start_x, line_y, left_chars)

          let right_chars = er_crows_foot_chars(right_token_value, use_ascii)
          write_canvas_text(
            canvas,
            end_x - right_chars.length() + 1,
            line_y,
            right_chars,
          )

          match edge.label {
            Some(label) =>
              if label != "" {
                let gap_mid = (start_x + end_x) / 2
                let label_start = start_x.max(gap_mid - label.length() / 2)
                let label_y = line_y - 1
                if label_y >= 0 {
                  for i in 0..<label.length() {
                    let lx = label_start + i
                    if lx >= start_x && lx <= end_x {
                      put_canvas(
                        canvas,
                        lx,
                        label_y,
                        (try! label[i:i + 1]).to_string(),
                      )
                    }
                  }
                }
              }
            None => ()
          }
        } else {
          let upper_is_source = scy < tcy
          let upper_x = if upper_is_source { sx } else { tx }
          let upper_y = if upper_is_source { sy } else { ty }
          let upper_w = if upper_is_source { sw } else { tw }
          let upper_h = if upper_is_source { sh } else { th }
          let lower_x = if upper_is_source { tx } else { sx }
          let lower_y = if upper_is_source { ty } else { sy }
          let lower_w = if upper_is_source { tw } else { sw }
          let upper_token = if upper_is_source {
            left_token
          } else {
            right_token
          }
          let lower_token = if upper_is_source {
            right_token
          } else {
            left_token
          }

          let start_y = upper_y + upper_h
          let end_y = lower_y - 1
          let line_x = upper_x + upper_w / 2
          let lower_cx = lower_x + lower_w / 2

          for y in start_y..<=end_y {
            put_canvas(canvas, line_x, y, line_v)
          }

          if line_x != lower_cx {
            let mid_y = (start_y + end_y) / 2
            let lx = if line_x < lower_cx { line_x } else { lower_cx }
            let rx = if line_x > lower_cx { line_x } else { lower_cx }
            for x in lx..<=rx {
              put_canvas(canvas, x, mid_y, line_h)
            }
            for y in (mid_y + 1)..<=end_y {
              put_canvas(canvas, lower_cx, y, line_v)
            }
          }

          let upper_chars = er_crows_foot_chars(upper_token, use_ascii)
          class_draw_marker(canvas, line_x, start_y, upper_chars)

          let target_x = if line_x != lower_cx { lower_cx } else { line_x }
          let lower_chars = er_crows_foot_chars(lower_token, use_ascii)
          class_draw_marker(canvas, target_x, end_y, lower_chars)

          match edge.label {
            Some(label) =>
              if label != "" {
                let mid_y = (start_y + end_y) / 2
                let label_x = line_x + 2
                er_ensure_canvas_size(
                  canvas,
                  label_x + label.length() + 1,
                  mid_y + 1,
                )
                write_canvas_text(canvas, label_x, mid_y, label)
              }
            None => ()
          }
        }
      }
      _ => ()
    }
  }

  canvas_to_output(canvas)
}
