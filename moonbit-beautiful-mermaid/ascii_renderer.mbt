///|
fn graph_is_shape(graph : MermaidGraph, expected : NodeShape) -> Bool {
  if graph.nodes.length() == 0 {
    return false
  }
  for _, node in graph.nodes {
    if node.shape != expected {
      return false
    }
  }
  true
}

///|
fn graph_has_shape(graph : MermaidGraph, expected : NodeShape) -> Bool {
  for _, node in graph.nodes {
    if node.shape == expected {
      return true
    }
  }
  false
}

///|
fn unicode_basic_operator(op : String) -> String {
  op
  .replace_all(old="=", new="═")
  .replace_all(old="-", new="─")
  .replace_all(old=".", new="┄")
  .replace_all(old="<", new="◄")
  .replace_all(old=">", new="►")
}

///|
fn unicode_class_operator(op : String) -> String {
  match op {
    "<|--" => "△──"
    "<|.." => "△┄┄"
    "*--" => "◆──"
    "--*" => "──◆"
    "o--" => "◇──"
    "--o" => "──◇"
    "-->" => "──►"
    "..>" => "┄┄►"
    "..|>" => "┄┄△"
    "--" => "───"
    ".." => "┄┄┄"
    _ => unicode_basic_operator(op)
  }
}

///|
fn unicode_sequence_operator(op : String) -> String {
  match op {
    "->>" => "──►"
    "-->>" => "┄┄►"
    "->" => "──▷"
    "-->" => "┄┄▷"
    "-)" => "──▷"
    "--)" => "┄┄▷"
    "-x" => "──✕"
    "--x" => "┄┄✕"
    _ => unicode_basic_operator(op)
  }
}

///|
fn unicode_er_token(token : String) -> String {
  match token {
    "||" => "║"
    "o|" | "|o" => "o║"
    "o{" | "{o" => "o╟"
    "|{" | "}|" => "╟"
    "|}" | "{|" => "╢"
    _ => token
  }
}

///|
fn unicode_er_operator(op : String) -> String {
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
    (Some(start), Some(end)) => {
      let left = trim_owned((try! op[:start]).to_string())
      let line = trim_owned((try! op[start:end + 1]).to_string())
      let right = trim_owned((try! op[end + 1:]).to_string())
      let line_symbol = if line.contains(".") {
        "┄┄┄"
      } else if line.contains("=") {
        "═══"
      } else {
        "───"
      }
      "\{unicode_er_token(left)}\{line_symbol}\{unicode_er_token(right)}"
    }
    _ => unicode_basic_operator(op)
  }
}

///|
fn connector_for_edge(
  style : EdgeStyle,
  has_start : Bool,
  has_end : Bool,
  use_ascii : Bool,
  relation_operator : String?,
  class_mode : Bool,
  er_mode : Bool,
  sequence_mode : Bool,
) -> String {
  if class_mode || er_mode || sequence_mode {
    match relation_operator {
      Some(operator) =>
        if use_ascii {
          return operator
        } else if class_mode {
          return unicode_class_operator(operator)
        } else if er_mode {
          return unicode_er_operator(operator)
        } else {
          return unicode_sequence_operator(operator)
        }
      None => ()
    }
  }

  if use_ascii {
    let line = match style {
      EdgeStyle::Solid => "-"
      EdgeStyle::Dotted => "."
      EdgeStyle::Thick => "="
    }
    match (has_start, has_end) {
      (true, true) => "<\{line}\{line}\{line}>"
      (true, false) => "<\{line}\{line}\{line}\{line}"
      (false, true) => "\{line}\{line}\{line}>"
      (false, false) => "\{line}\{line}\{line}\{line}"
    }
  } else {
    let line = match style {
      EdgeStyle::Solid => "─"
      EdgeStyle::Dotted => "┄"
      EdgeStyle::Thick => "═"
    }
    match (has_start, has_end) {
      (true, true) => "◄\{line}\{line}\{line}►"
      (true, false) => "◄\{line}\{line}\{line}\{line}"
      (false, true) => "\{line}\{line}\{line}►"
      (false, false) => "\{line}\{line}\{line}\{line}"
    }
  }
}

///|
fn node_label_for_ascii(graph : MermaidGraph, node_id : String) -> String {
  match graph.nodes.get(node_id) {
    Some(node) =>
      match node.shape {
        NodeShape::StateStart | NodeShape::StateEnd => "*"
        _ =>
          if node.label == "" {
            node.id
          } else {
            node.label.replace_all(old="\n", new=" | ")
          }
      }
    None => node_id
  }
}

///|
fn flow_node_label(node : PositionedNode) -> String {
  match node.shape {
    NodeShape::StateStart | NodeShape::StateEnd => ""
    _ =>
      if node.label == "" {
        node.id
      } else {
        node.label.replace_all(old="\n", new=" | ")
      }
  }
}

///|
priv struct AsciiFlowNodeBox {
  id : String
  label : String
  left : Int
  top : Int
  width : Int
  height : Int
}

///|
priv struct AsciiFlowGroupBox {
  label : String
  left : Int
  top : Int
  width : Int
  height : Int
  children : Array[AsciiFlowGroupBox]
}

///|
priv struct AsciiArrowPlacement {
  x : Int
  y : Int
  marker : String
}

///|
priv struct AsciiEdgeLabelPlacement {
  x : Int
  y : Int
  label : String
}

///|
fn flow_scale_x() -> Int {
  10
}

///|
fn flow_scale_y() -> Int {
  8
}

///|
fn scale_coord(value : Int, scale : Int, pad : Int) -> Int {
  value / scale + pad
}

///|
fn scale_size(value : Int, scale : Int, min_size : Int) -> Int {
  ((value + scale - 1) / scale).max(min_size)
}

///|
fn flow_line_chars(style : EdgeStyle, use_ascii : Bool) -> (String, String) {
  if use_ascii {
    match style {
      EdgeStyle::Solid => ("-", "|")
      EdgeStyle::Dotted => (".", ":")
      EdgeStyle::Thick => ("=", "|")
    }
  } else {
    match style {
      EdgeStyle::Solid => ("─", "│")
      EdgeStyle::Dotted => ("┄", "┊")
      EdgeStyle::Thick => ("═", "║")
    }
  }
}

///|
fn flow_arrow_marker(dx : Int, dy : Int, use_ascii : Bool) -> String {
  if dx.abs() >= dy.abs() {
    if dx >= 0 {
      if use_ascii {
        ">"
      } else {
        "►"
      }
    } else if use_ascii {
      "<"
    } else {
      "◄"
    }
  } else if dy >= 0 {
    if use_ascii {
      "v"
    } else {
      "▼"
    }
  } else if use_ascii {
    "^"
  } else {
    "▲"
  }
}

///|
fn unit_step(value : Int) -> Int {
  if value > 0 {
    1
  } else if value < 0 {
    -1
  } else {
    0
  }
}

///|
fn axis_is_horizontal(dx : Int, dy : Int) -> Bool {
  dx.abs() >= dy.abs()
}

///|
fn flow_paths_are_reverse(first : Array[Point], second : Array[Point]) -> Bool {
  if first.length() != second.length() {
    return false
  }
  let len = first.length()
  for i in 0..<len {
    let a = first[i]
    let b = second[len - 1 - i]
    if a.x != b.x || a.y != b.y {
      return false
    }
  }
  true
}

///|
fn border_join_marker(
  dx : Int,
  dy : Int,
  for_target : Bool,
  use_ascii : Bool,
) -> String? {
  if use_ascii {
    return None
  }

  if axis_is_horizontal(dx, dy) {
    if for_target {
      if dx > 0 {
        Some("┤")
      } else {
        Some("├")
      }
    } else if dx > 0 {
      Some("├")
    } else {
      Some("┤")
    }
  } else if for_target {
    if dy > 0 {
      Some("┴")
    } else {
      Some("┬")
    }
  } else if dy > 0 {
    Some("┬")
  } else {
    Some("┴")
  }
}

///|
fn flow_edge_anchor(
  box : AsciiFlowNodeBox,
  dx : Int,
  dy : Int,
  for_target : Bool,
) -> (Int, Int) {
  if axis_is_horizontal(dx, dy) {
    let y = box.top + box.height / 2
    if for_target {
      if dx > 0 {
        (box.left, y)
      } else {
        (box.left + box.width - 1, y)
      }
    } else if dx > 0 {
      (box.left + box.width - 1, y)
    } else {
      (box.left, y)
    }
  } else {
    let x = box.left + box.width / 2
    if for_target {
      if dy > 0 {
        (x, box.top)
      } else {
        (x, box.top + box.height - 1)
      }
    } else if dy > 0 {
      (x, box.top + box.height - 1)
    } else {
      (x, box.top)
    }
  }
}

///|
fn label_overlaps_node_box(
  x : Int,
  y : Int,
  label : String,
  box : AsciiFlowNodeBox,
) -> Bool {
  let box_left = box.left
  let box_right = box.left + box.width - 1
  let box_top = box.top
  let box_bottom = box.top + box.height - 1
  if y < box_top || y > box_bottom {
    return false
  }
  let label_left = x
  let label_right = x + label.length() - 1
  !(label_right < box_left || label_left > box_right)
}

///|
fn label_overlaps_any_node_box(
  x : Int,
  y : Int,
  label : String,
  boxes : Array[AsciiFlowNodeBox],
) -> Bool {
  for box in boxes {
    if label_overlaps_node_box(x, y, label, box) {
      return true
    }
  }
  false
}

///|
fn label_overlaps_edge_label(
  x : Int,
  y : Int,
  label : String,
  existing : AsciiEdgeLabelPlacement,
) -> Bool {
  if y != existing.y {
    return false
  }
  let label_left = x
  let label_right = x + label.length() - 1
  let existing_left = existing.x
  let existing_right = existing.x + existing.label.length() - 1
  !(label_right < existing_left || label_left > existing_right)
}

///|
fn label_overlaps_any_edge_label(
  x : Int,
  y : Int,
  label : String,
  existing_labels : Array[AsciiEdgeLabelPlacement],
) -> Bool {
  for existing in existing_labels {
    if label_overlaps_edge_label(x, y, label, existing) {
      return true
    }
  }
  false
}

///|
fn adjust_label_y_for_state_boxes(
  x : Int,
  y : Int,
  label : String,
  boxes : Array[AsciiFlowNodeBox],
) -> Int {
  if !label_overlaps_any_node_box(x, y, label, boxes) {
    return y
  }
  for offset in 1..<=6 {
    let down = y + offset
    if !label_overlaps_any_node_box(x, down, label, boxes) {
      return down
    }
    let up = y - offset
    if !label_overlaps_any_node_box(x, up, label, boxes) {
      return up
    }
  }
  y
}

///|
fn adjust_label_y_for_state_layout(
  x : Int,
  y : Int,
  label : String,
  boxes : Array[AsciiFlowNodeBox],
  existing_labels : Array[AsciiEdgeLabelPlacement],
) -> Int {
  if !label_overlaps_any_node_box(x, y, label, boxes) &&
    !label_overlaps_any_edge_label(x, y, label, existing_labels) {
    return y
  }
  for offset in 1..<=8 {
    let down = y + offset
    if !label_overlaps_any_node_box(x, down, label, boxes) &&
      !label_overlaps_any_edge_label(x, down, label, existing_labels) {
      return down
    }
    let up = y - offset
    if !label_overlaps_any_node_box(x, up, label, boxes) &&
      !label_overlaps_any_edge_label(x, up, label, existing_labels) {
      return up
    }
  }
  y
}

///|
fn flow_draw_box(
  canvas : Array[Array[String]],
  left : Int,
  top : Int,
  width : Int,
  height : Int,
  label : String,
  use_ascii : Bool,
) -> Unit {
  let h = if use_ascii { "-" } else { "─" }
  let v = if use_ascii { "|" } else { "│" }
  let tl = if use_ascii { "+" } else { "┌" }
  let tr = if use_ascii { "+" } else { "┐" }
  let bl = if use_ascii { "+" } else { "└" }
  let br = if use_ascii { "+" } else { "┘" }

  put_canvas(canvas, left, top, tl)
  for x in (left + 1)..<(left + width - 1) {
    put_canvas(canvas, x, top, h)
  }
  put_canvas(canvas, left + width - 1, top, tr)

  put_canvas(canvas, left, top + height - 1, bl)
  for x in (left + 1)..<(left + width - 1) {
    put_canvas(canvas, x, top + height - 1, h)
  }
  put_canvas(canvas, left + width - 1, top + height - 1, br)

  for y in (top + 1)..<(top + height - 1) {
    put_canvas(canvas, left, y, v)
    put_canvas(canvas, left + width - 1, y, v)
    for x in (left + 1)..<(left + width - 1) {
      put_canvas(canvas, x, y, " ")
    }
  }

  let text_x = left + ((width - label.length()) / 2).max(1)
  let text_y = top + height / 2
  write_canvas_text(canvas, text_x, text_y, label)
}

///|
fn flow_draw_frame(
  canvas : Array[Array[String]],
  left : Int,
  top : Int,
  width : Int,
  height : Int,
  use_ascii : Bool,
) -> Unit {
  let h = if use_ascii { "-" } else { "─" }
  let v = if use_ascii { "|" } else { "│" }
  let tl = if use_ascii { "+" } else { "┌" }
  let tr = if use_ascii { "+" } else { "┐" }
  let bl = if use_ascii { "+" } else { "└" }
  let br = if use_ascii { "+" } else { "┘" }

  put_canvas(canvas, left, top, tl)
  for x in (left + 1)..<(left + width - 1) {
    put_canvas(canvas, x, top, h)
  }
  put_canvas(canvas, left + width - 1, top, tr)

  put_canvas(canvas, left, top + height - 1, bl)
  for x in (left + 1)..<(left + width - 1) {
    put_canvas(canvas, x, top + height - 1, h)
  }
  put_canvas(canvas, left + width - 1, top + height - 1, br)

  for y in (top + 1)..<(top + height - 1) {
    put_canvas(canvas, left, y, v)
    put_canvas(canvas, left + width - 1, y, v)
  }
}

///|
fn flow_draw_hline(
  canvas : Array[Array[String]],
  x1 : Int,
  x2 : Int,
  y : Int,
  ch : String,
) -> Unit {
  let start = x1.min(x2)
  let ending = x1.max(x2)
  let use_ascii = ch == "-" || ch == "." || ch == "="
  for x in start..<=ending {
    flow_put_line_canvas(canvas, x, y, ch, use_ascii, true)
  }
}

///|
fn flow_draw_vline(
  canvas : Array[Array[String]],
  x : Int,
  y1 : Int,
  y2 : Int,
  ch : String,
) -> Unit {
  let start = y1.min(y2)
  let ending = y1.max(y2)
  let use_ascii = ch == "|" || ch == ":"
  for y in start..<=ending {
    flow_put_line_canvas(canvas, x, y, ch, use_ascii, false)
  }
}

///|
fn flow_is_horizontal_line_char(ch : String) -> Bool {
  ch == "-" ||
  ch == "." ||
  ch == "=" ||
  ch == "─" ||
  ch == "┄" ||
  ch == "═"
}

///|
fn flow_is_vertical_line_char(ch : String) -> Bool {
  ch == "|" || ch == ":" || ch == "│" || ch == "┊" || ch == "║"
}

///|
fn flow_is_corner_or_junction_char(ch : String) -> Bool {
  ch == "+" ||
  ch == "┼" ||
  ch == "┌" ||
  ch == "┐" ||
  ch == "└" ||
  ch == "┘" ||
  ch == "├" ||
  ch == "┤" ||
  ch == "┬" ||
  ch == "┴"
}

///|
fn flow_put_line_canvas(
  canvas : Array[Array[String]],
  x : Int,
  y : Int,
  ch : String,
  use_ascii : Bool,
  horizontal : Bool,
) -> Unit {
  if y < 0 || y >= canvas.length() {
    return
  }
  if canvas.length() == 0 || x < 0 || x >= canvas[0].length() {
    return
  }
  let existing = canvas[y][x]
  if existing == " " || existing == "" {
    canvas[y][x] = ch
    return
  }
  if existing == ch {
    return
  }
  if flow_is_corner_or_junction_char(existing) {
    return
  }

  let cross = if horizontal {
    flow_is_vertical_line_char(existing)
  } else {
    flow_is_horizontal_line_char(existing)
  }
  if cross {
    canvas[y][x] = if use_ascii { "+" } else { "┼" }
    return
  }

  canvas[y][x] = ch
}

///|
fn flow_draw_segment(
  canvas : Array[Array[String]],
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  h_char : String,
  v_char : String,
) -> Unit {
  if x1 == x2 {
    flow_draw_vline(canvas, x1, y1, y2, v_char)
  } else if y1 == y2 {
    flow_draw_hline(canvas, x1, x2, y1, h_char)
  } else {
    flow_draw_hline(canvas, x1, x2, y1, h_char)
    flow_draw_vline(canvas, x2, y1, y2, v_char)
  }
}

///|
fn flow_mark_blocked_cells_for_nodes(
  blocked : Map[String, Bool],
  nodes : Array[AsciiFlowNodeBox],
) -> Unit {
  for node in nodes {
    if node.width <= 2 || node.height <= 2 {
      continue
    }
    for y in (node.top + 1)..<(node.top + node.height - 1) {
      for x in (node.left + 1)..<(node.left + node.width - 1) {
        blocked[ascii_grid_key(AsciiGridCoord::{ x, y })] = true
      }
    }
  }
}

///|
fn flow_draw_routed_segment(
  canvas : Array[Array[String]],
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  h_char : String,
  v_char : String,
  blocked : Map[String, Bool],
) -> Bool {
  if canvas.length() == 0 || canvas[0].length() == 0 {
    return false
  }
  let start = AsciiGridCoord::{ x: x1, y: y1 }
  let ending = AsciiGridCoord::{ x: x2, y: y2 }
  match
    ascii_grid_pathfind(
      start,
      ending,
      blocked,
      0,
      canvas[0].length() - 1,
      0,
      canvas.length() - 1,
    ) {
    Some(path) => {
      if path.length() < 2 {
        return false
      }
      for i in 1..<path.length() {
        let from = path[i - 1]
        let to = path[i]
        flow_draw_segment(canvas, from.x, from.y, to.x, to.y, h_char, v_char)
      }
      true
    }
    None => false
  }
}

///|
fn map_flow_group(
  group : PositionedGroup,
  scale_x : Int,
  scale_y : Int,
  pad_x : Int,
  pad_y : Int,
  state_composite_layout_mode : Bool,
) -> AsciiFlowGroupBox {
  let children : Array[AsciiFlowGroupBox] = []
  for child in group.children {
    children.push(
      map_flow_group(
        child, scale_x, scale_y, pad_x, pad_y, state_composite_layout_mode,
      ),
    )
  }
  let min_width = if state_composite_layout_mode {
    (group.label.length() + 6).max(9)
  } else {
    (group.label.length() + 4).max(7)
  }
  AsciiFlowGroupBox::{
    label: group.label,
    left: scale_coord(group.x, scale_x, pad_x),
    top: scale_coord(group.y, scale_y, pad_y),
    width: scale_size(group.width, scale_x, min_width),
    height: scale_size(group.height, scale_y, 5),
    children,
  }
}

///|
fn flow_group_max_x(group : AsciiFlowGroupBox) -> Int {
  let mut max_x = group.left + group.width
  for child in group.children {
    max_x = max_x.max(flow_group_max_x(child))
  }
  max_x
}

///|
fn flow_group_max_y(group : AsciiFlowGroupBox) -> Int {
  let mut max_y = group.top + group.height
  for child in group.children {
    max_y = max_y.max(flow_group_max_y(child))
  }
  max_y
}

///|
fn flow_draw_group(
  canvas : Array[Array[String]],
  group : AsciiFlowGroupBox,
  use_ascii : Bool,
) -> Unit {
  flow_draw_frame(
    canvas,
    group.left,
    group.top,
    group.width,
    group.height,
    use_ascii,
  )
  for child in group.children {
    flow_draw_group(canvas, child, use_ascii)
  }
}

///|
fn flow_draw_group_labels(
  canvas : Array[Array[String]],
  group : AsciiFlowGroupBox,
) -> Unit {
  let label_x = group.left + ((group.width - group.label.length()) / 2).max(1)
  let label_y = group.top + 1
  write_canvas_text(canvas, label_x, label_y, group.label)
  for child in group.children {
    flow_draw_group_labels(canvas, child)
  }
}

///|
fn leading_spaces(line : String) -> Int {
  let mut idx = 0
  while idx < line.length() {
    let ch = (try! line[idx:idx + 1]).to_string()
    if ch != " " {
      break
    }
    idx = idx + 1
  }
  idx
}

///|
fn trim_flow_canvas_output(output : String) -> String {
  let raw_lines = output.split("\n").map(line => line.to_string()).to_array()
  let mut start = 0
  while start < raw_lines.length() && raw_lines[start].trim() == "" {
    start = start + 1
  }

  let mut end = raw_lines.length()
  while end > start && raw_lines[end - 1].trim() == "" {
    end = end - 1
  }

  if start >= end {
    return ""
  }

  let lines = raw_lines[start:end]
  let mut min_leading = -1
  for line in lines {
    if line.trim() == "" {
      continue
    }
    let count = leading_spaces(line)
    if min_leading == -1 || count < min_leading {
      min_leading = count
    }
  }

  if min_leading <= 0 {
    let max_width = lines.fold(init=0, fn(acc, line) {
      acc.max(line.trim_end().length())
    })
    if max_width <= 0 {
      return lines.iter().join("\n")
    }
    let normalized : Array[String] = []
    for line in lines {
      if line.length() <= max_width {
        normalized.push(line)
      } else {
        normalized.push((try! line[:max_width]).to_string())
      }
    }
    return normalized.iter().join("\n")
  }

  let trimmed : Array[String] = []
  for line in lines {
    if line.length() <= min_leading {
      trimmed.push("")
    } else {
      trimmed.push((try! line[min_leading:]).to_string())
    }
  }
  let max_width = trimmed.fold(init=0, fn(acc, line) {
    acc.max(line.trim_end().length())
  })
  if max_width <= 0 {
    return trimmed.iter().join("\n")
  }

  let normalized : Array[String] = []
  for line in trimmed {
    if line.length() <= max_width {
      normalized.push(line)
    } else {
      normalized.push((try! line[:max_width]).to_string())
    }
  }
  normalized.iter().join("\n")
}

///|
fn flow_canvas_to_output(canvas : Array[Array[String]]) -> String {
  let lines : Array[String] = []
  for row in canvas {
    lines.push(row.iter().join(""))
  }
  lines.iter().join("\n")
}

///|
fn render_ascii_flow_subgraphs(
  graph : MermaidGraph,
  options : AsciiRenderOptions,
) -> String {
  let positioned = layout_graph_for_ascii(graph, RenderOptions::default())
  let state_layout_mode = graph_has_shape(graph, NodeShape::StateStart) ||
    graph_has_shape(graph, NodeShape::StateEnd)
  let state_flat_layout_mode = state_layout_mode &&
    graph.subgraphs.length() == 0
  let state_composite_layout_mode = state_layout_mode && !state_flat_layout_mode
  let scale_x = if state_layout_mode { 9 } else { flow_scale_x() }
  let scale_y = if state_layout_mode { 10 } else { flow_scale_y() }
  let mut state_uniform_min_width : Int? = None
  let mut state_flat_max_x : Int? = None
  let mut state_flat_has_multiple_columns = false
  if state_flat_layout_mode {
    let mut max_state_text_len = 0
    let x_columns : Map[Int, Bool] = {}
    let mut max_node_x = 0
    for node in positioned.nodes {
      max_state_text_len = max_state_text_len.max(
        flow_node_label(node).length(),
      )
      x_columns[node.x] = true
      max_node_x = max_node_x.max(node.x)
    }
    for edge in positioned.edges {
      match edge.label {
        Some(label) =>
          max_state_text_len = max_state_text_len.max(label.length())
        None => ()
      }
    }
    state_flat_has_multiple_columns = x_columns.length() > 1
    if state_flat_has_multiple_columns {
      state_flat_max_x = Some(max_node_x)
    }
    if max_state_text_len >= 12 {
      state_uniform_min_width = Some(max_state_text_len + 4)
    }
  }

  let mapped_groups : Array[AsciiFlowGroupBox] = []
  for group in positioned.groups {
    mapped_groups.push(
      map_flow_group(
        group,
        scale_x,
        scale_y,
        options.padding_x,
        options.padding_y,
        state_composite_layout_mode,
      ),
    )
  }

  let mapped_nodes : Array[AsciiFlowNodeBox] = []
  for node in positioned.nodes {
    let label = flow_node_label(node)
    let (min_width, min_height) = if state_layout_mode {
      match state_uniform_min_width {
        Some(uniform_width) => {
          let narrowed_width = if state_flat_layout_mode &&
            state_flat_has_multiple_columns {
            match state_flat_max_x {
              Some(max_x) =>
                if node.x == max_x {
                  (uniform_width - 1).max(12)
                } else {
                  uniform_width
                }
              None => uniform_width
            }
          } else {
            uniform_width
          }
          (narrowed_width, 5)
        }
        None =>
          match node.shape {
            NodeShape::StateStart | NodeShape::StateEnd =>
              if state_composite_layout_mode {
                (14, 5)
              } else {
                (12, 5)
              }
            _ => ((label.length() + 6).max(12), 5)
          }
      }
    } else {
      match node.shape {
        NodeShape::StateStart | NodeShape::StateEnd => (10, 5)
        _ => ((label.length() + 4).max(5), 3)
      }
    }
    let width = scale_size(node.width, scale_x, min_width)
    let height = scale_size(node.height, scale_y, min_height).max(min_height)
    let cx = scale_coord(node.x, scale_x, options.padding_x)
    let cy = scale_coord(node.y, scale_y, options.padding_y)
    let box = AsciiFlowNodeBox::{
      id: node.id,
      label,
      left: cx - width / 2,
      top: cy - height / 2,
      width,
      height,
    }
    mapped_nodes.push(box)
  }

  let mut max_x = 0
  let mut max_y = 0
  for group in mapped_groups {
    max_x = max_x.max(flow_group_max_x(group))
    max_y = max_y.max(flow_group_max_y(group))
  }
  for node in mapped_nodes {
    max_x = max_x.max(node.left + node.width)
    max_y = max_y.max(node.top + node.height)
  }
  for edge in positioned.edges {
    for point in edge.points {
      let x = scale_coord(point.x, scale_x, options.padding_x)
      let y = scale_coord(point.y, scale_y, options.padding_y)
      max_x = max_x.max(x + 1)
      max_y = max_y.max(y + 1)
    }
  }
  let canvas = make_canvas(
    max_x + options.padding_x + 2,
    max_y + options.padding_y + 2,
  )
  let node_box_by_id : Map[String, AsciiFlowNodeBox] = {}
  for box in mapped_nodes {
    node_box_by_id[box.id] = box
  }

  for group in mapped_groups {
    flow_draw_group(canvas, group, options.use_ascii)
  }

  let arrow_overlays : Array[AsciiArrowPlacement] = []
  let border_overlays : Array[AsciiArrowPlacement] = []
  let edge_label_overlays : Array[AsciiEdgeLabelPlacement] = []
  let blocked_cells : Map[String, Bool] = {}
  if state_flat_layout_mode {
    flow_mark_blocked_cells_for_nodes(blocked_cells, mapped_nodes)
  }
  for edge in positioned.edges {
    let (h_char, v_char) = flow_line_chars(edge.style, options.use_ascii)
    let points = edge.points
    if points.length() < 2 {
      continue
    }
    for i in 1..<points.length() {
      let p1 = points[i - 1]
      let p2 = points[i]
      let x1 = scale_coord(p1.x, scale_x, options.padding_x)
      let y1 = scale_coord(p1.y, scale_y, options.padding_y)
      let x2 = scale_coord(p2.x, scale_x, options.padding_x)
      let y2 = scale_coord(p2.y, scale_y, options.padding_y)
      let routed = state_flat_layout_mode &&
        (x1 != x2 || y1 != y2) &&
        flow_draw_routed_segment(
          canvas, x1, y1, x2, y2, h_char, v_char, blocked_cells,
        )
      if !routed {
        flow_draw_segment(canvas, x1, y1, x2, y2, h_char, v_char)
      }
    }

    let first = points[0]
    let next = points[1]
    let first_x = scale_coord(first.x, scale_x, options.padding_x)
    let first_y = scale_coord(first.y, scale_y, options.padding_y)
    let next_x = scale_coord(next.x, scale_x, options.padding_x)
    let next_y = scale_coord(next.y, scale_y, options.padding_y)
    let start_dx = next_x - first_x
    let start_dy = next_y - first_y
    let (source_anchor_x, source_anchor_y) = match
      node_box_by_id.get(edge.source) {
      Some(source_box) =>
        flow_edge_anchor(source_box, start_dx, start_dy, false)
      None => (first_x, first_y)
    }
    match border_join_marker(start_dx, start_dy, false, options.use_ascii) {
      Some(marker) =>
        border_overlays.push(AsciiArrowPlacement::{
          x: source_anchor_x,
          y: source_anchor_y,
          marker,
        })
      None => ()
    }

    let last = points[points.length() - 1]
    let prev = points[points.length() - 2]
    let end_x = scale_coord(last.x, scale_x, options.padding_x)
    let end_y = scale_coord(last.y, scale_y, options.padding_y)
    let prev_x = scale_coord(prev.x, scale_x, options.padding_x)
    let prev_y = scale_coord(prev.y, scale_y, options.padding_y)
    let end_dx = end_x - prev_x
    let end_dy = end_y - prev_y
    let (target_anchor_x, target_anchor_y) = match
      node_box_by_id.get(edge.target) {
      Some(target_box) => flow_edge_anchor(target_box, end_dx, end_dy, true)
      None => (end_x, end_y)
    }
    match edge.label {
      Some(label) => {
        let mut has_labeled_reverse_shared_path = false
        if state_layout_mode {
          for candidate in positioned.edges {
            if candidate.source == edge.target &&
              candidate.target == edge.source {
              if candidate.label is Some(_) &&
                flow_paths_are_reverse(edge.points, candidate.points) {
                has_labeled_reverse_shared_path = true
                break
              }
            }
          }
        }
        let (anchor_x, anchor_y) = if has_labeled_reverse_shared_path {
          (
            (source_anchor_x + target_anchor_x) / 2,
            (source_anchor_y + target_anchor_y) / 2,
          )
        } else {
          match edge.label_position {
            Some(position) =>
              (
                scale_coord(position.x, scale_x, options.padding_x),
                scale_coord(position.y, scale_y, options.padding_y),
              )
            None => ((first_x + end_x) / 2, (first_y + end_y) / 2)
          }
        }
        let label_x = anchor_x - label.length() / 2
        let label_y = if state_layout_mode {
          let base_y = adjust_label_y_for_state_boxes(
            label_x, anchor_y, label, mapped_nodes,
          )
          if has_labeled_reverse_shared_path {
            base_y
          } else {
            adjust_label_y_for_state_layout(
              label_x, base_y, label, mapped_nodes, edge_label_overlays,
            )
          }
        } else {
          anchor_y
        }
        edge_label_overlays.push(AsciiEdgeLabelPlacement::{
          x: label_x,
          y: label_y,
          label,
        })
      }
      None => ()
    }

    if edge.has_arrow_end {
      let dx = end_dx
      let dy = end_dy
      arrow_overlays.push(AsciiArrowPlacement::{
        x: target_anchor_x - unit_step(dx),
        y: target_anchor_y - unit_step(dy),
        marker: flow_arrow_marker(dx, dy, options.use_ascii),
      })
    }
    if edge.has_arrow_start {
      let dx = -start_dx
      let dy = -start_dy
      arrow_overlays.push(AsciiArrowPlacement::{
        x: source_anchor_x + unit_step(dx),
        y: source_anchor_y + unit_step(dy),
        marker: flow_arrow_marker(dx, dy, options.use_ascii),
      })
    }
  }

  for node in mapped_nodes {
    flow_draw_box(
      canvas,
      node.left,
      node.top,
      node.width,
      node.height,
      node.label,
      options.use_ascii,
    )
  }

  for join in border_overlays {
    put_canvas(canvas, join.x, join.y, join.marker)
  }

  for arrow in arrow_overlays {
    put_canvas(canvas, arrow.x, arrow.y, arrow.marker)
  }
  for placement in edge_label_overlays {
    write_canvas_text(canvas, placement.x, placement.y, placement.label)
  }
  for group in mapped_groups {
    flow_draw_group_labels(canvas, group)
  }

  trim_flow_canvas_output(flow_canvas_to_output(canvas))
}

///|
fn render_ascii(graph : MermaidGraph, options : AsciiRenderOptions) -> String {
  let lines : Array[String] = []
  let sequence_mode = graph_is_shape(graph, NodeShape::SequenceParticipant)
  if sequence_mode {
    return render_ascii_sequence(graph, options)
  }
  let class_mode = graph_is_shape(graph, NodeShape::ClassEntity)
  if class_mode {
    return render_ascii_class(graph, options)
  }
  let er_mode = graph_is_shape(graph, NodeShape::ErEntity)
  if er_mode {
    return render_ascii_er(graph, options)
  }
  let state_mode = graph_has_shape(graph, NodeShape::StateStart) ||
    graph_has_shape(graph, NodeShape::StateEnd)
  if state_mode {
    return render_ascii_flow_subgraphs(graph, options)
  }
  if graph.subgraphs.length() > 0 {
    return render_ascii_flow_subgraphs(graph, options)
  }

  if graph.edges.length() == 0 {
    for _, node in graph.nodes {
      let label = if node.label == "" { node.id } else { node.label }
      lines.push("[\{label}]")
    }
    return lines.iter().join("\n")
  }

  for edge in graph.edges {
    let source = node_label_for_ascii(graph, edge.source)
    let target = node_label_for_ascii(graph, edge.target)
    let connector = connector_for_edge(
      edge.style,
      edge.has_arrow_start,
      edge.has_arrow_end,
      options.use_ascii,
      edge.relation_operator,
      class_mode,
      er_mode,
      false,
    )

    let line = match edge.label {
      Some(label) => "[\{source}]\{connector}(\{label})[\{target}]"
      None => "[\{source}]\{connector}[\{target}]"
    }
    lines.push(line)
  }

  lines.iter().join("\n")
}
