///|
fn class_is_method_detail(detail : StringView) -> Bool {
  if detail.has_suffix(" ()") {
    return true
  }
  if detail.contains("(") && detail.contains(")") {
    return true
  }
  false
}

///|
fn class_strip_method_marker(detail : StringView) -> StringView {
  if detail.strip_suffix(" ()") is Some(a) {
    a.trim()
  } else {
    detail
  }
}

///|
fn class_sections(node : MermaidNode) -> Array[Array[String]] {
  let lines = node.label.split("\n").map(part => part.to_string()).to_array()
  if lines.length() == 0 {
    return [[node.id]]
  }

  let header : Array[String] = []
  let attributes : Array[String] = []
  let methods : Array[String] = []

  for i in 1..<lines.length() {
    let detail = lines[i].trim()
    if detail == "" {
      continue
    }
    let rendered = class_strip_method_marker(detail)
    if detail.has_prefix("<<") && detail.has_suffix(">>") {
      header.push(rendered.to_string())
    } else if class_is_method_detail(detail) {
      methods.push(rendered.to_string())
    } else {
      attributes.push(rendered.to_string())
    }
  }
  header.push(lines[0])

  if attributes.length() == 0 && methods.length() == 0 {
    [header]
  } else if methods.length() == 0 {
    [header, attributes]
  } else {
    [header, attributes, methods]
  }
}

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
fn map_push_unique(
  mapping : Map[String, Array[String]],
  key : String,
  value : String,
) -> Unit {
  let values = mapping.get_or_init(key, () => [])
  if !values.any(item => item == value) {
    values.push(value)
  }
}

///|
fn class_relation_meta(operator : String?) -> (String, Bool, Bool, Bool) {
  match operator {
    Some(op) =>
      if op.has_prefix("<|") {
        let rel_type = if op.contains(".") {
          "realization"
        } else {
          "inheritance"
        }
        (rel_type, false, rel_type == "realization", true)
      } else if op.has_suffix("|>") {
        let rel_type = if op.contains(".") {
          "realization"
        } else {
          "inheritance"
        }
        (rel_type, true, rel_type == "realization", true)
      } else if op.has_prefix("*") {
        ("composition", false, false, false)
      } else if op.has_suffix("*") {
        ("composition", true, false, false)
      } else if op.has_prefix("o") {
        ("aggregation", false, false, false)
      } else if op.has_suffix("o") {
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
fn render_ascii_class(
  graph : MermaidGraph,
  options : AsciiRenderOptions,
) -> String {
  let classes = graph.nodes.values().to_array()
  if classes.length() == 0 {
    return ""
  }

  let use_ascii = options.use_ascii
  let h_gap = 4
  let v_gap = 3

  let class_sections_map : Map[String, Array[Array[String]]] = {}
  let class_width : Map[String, Int] = {}
  let class_height : Map[String, Int] = {}
  let class_order : Array[String] = []

  for cls in classes {
    let sections = class_sections(cls)
    let (box_w, box_h) = class_multibox_size(sections)
    class_sections_map[cls.id] = sections
    class_width[cls.id] = box_w
    class_height[cls.id] = box_h
    class_order.push(cls.id)
  }

  let parents : Map[String, Array[String]] = {}
  let children : Map[String, Array[String]] = {}
  for edge in graph.edges {
    let (_, marker_at_to, _, hierarchical) = class_relation_meta(
      edge.relation_operator,
    )
    let (parent_id, child_id) = if hierarchical && marker_at_to {
      (edge.target, edge.source)
    } else {
      (edge.source, edge.target)
    }
    map_push_unique(parents, child_id, parent_id)
    map_push_unique(children, parent_id, child_id)
  }

  let level : Map[String, Int] = {}
  let queue : Array[String] = []
  for class_id in class_order {
    match parents.get(class_id) {
      Some(found) =>
        if found.length() == 0 {
          level[class_id] = 0
          queue.push(class_id)
        }
      None => {
        level[class_id] = 0
        queue.push(class_id)
      }
    }
  }

  let level_cap = classes.length() - 1
  let mut qi = 0
  while qi < queue.length() {
    let id = queue[qi]
    qi = qi + 1
    match children.get(id) {
      Some(child_ids) =>
        for child_id in child_ids {
          let new_level = match level.get(id) {
            Some(found) => found + 1
            None => 1
          }
          if new_level > level_cap {
            continue
          }
          match level.get(child_id) {
            Some(existing) =>
              if existing < new_level {
                level[child_id] = new_level
                queue.push(child_id)
              }
            None => {
              level[child_id] = new_level
              queue.push(child_id)
            }
          }
        }
      None => ()
    }
  }

  for class_id in class_order {
    if !level.contains(class_id) {
      level[class_id] = 0
    }
  }

  let mut max_level = 0
  for class_id in class_order {
    match level.get(class_id) {
      Some(found) => if found > max_level { max_level = found }
      None => ()
    }
  }

  let level_groups : Array[Array[String]] = []
  for _ in 0..<=max_level {
    level_groups.push([])
  }
  for class_id in class_order {
    match level.get(class_id) {
      Some(found) => level_groups[found].push(class_id)
      None => level_groups[0].push(class_id)
    }
  }

  let placed_x : Map[String, Int] = {}
  let placed_y : Map[String, Int] = {}
  let mut current_y = 0
  for lv in 0..<=max_level {
    let group = level_groups[lv]
    if group.length() == 0 {
      continue
    }
    let mut current_x = 0
    let mut max_h = 0
    for class_id in group {
      let w = class_width.get(class_id).unwrap()
      let h = class_height.get(class_id).unwrap()
      placed_x[class_id] = current_x
      placed_y[class_id] = current_y
      current_x = current_x + w + h_gap
      if h > max_h {
        max_h = h
      }
    }
    current_y = current_y + max_h + v_gap
  }

  let mut total_w = 0
  let mut total_h = 0
  for class_id in class_order {
    let x = placed_x.get(class_id).unwrap()
    let y = placed_y.get(class_id).unwrap()
    let w = class_width.get(class_id).unwrap()
    let h = class_height.get(class_id).unwrap()
    if x + w > total_w {
      total_w = x + w
    }
    if y + h > total_h {
      total_h = y + h
    }
  }
  total_w = total_w + 4
  total_h = total_h + 2 + graph.edges.length() * 3

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
