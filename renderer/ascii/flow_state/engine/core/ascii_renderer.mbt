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
fn flow_node_label(node : PositionedNode) -> String {
  match node.shape {
    StateStart | StateEnd => ""
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
  id : String
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
priv struct StateAsciiEdgeLayout {
  edge : MermaidEdge
  path : Array[AsciiGridCoord]
  label_line : Array[AsciiGridCoord]
}

///|
fn flow_scale_x() -> Int {
  7
}

///|
fn flow_scale_y() -> Int {
  9
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
      Solid => ("-", "|")
      Dotted => (".", ":")
      Thick => ("=", "|")
    }
  } else {
    match style {
      Solid => ("─", "│")
      Dotted => ("┄", "┊")
      Thick => ("═", "║")
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
fn flow_node_pair_key(a : String, b : String) -> String {
  if a <= b {
    "\{a}|\{b}"
  } else {
    "\{b}|\{a}"
  }
}

///|
fn flow_non_state_label_anchor(
  source_x : Int,
  source_y : Int,
  target_x : Int,
  target_y : Int,
  label_len : Int,
) -> (Int, Int) {
  if source_y == target_y {
    return ((source_x + target_x) / 2, source_y)
  }
  if source_x == target_x {
    return (source_x, (source_y + target_y) / 2)
  }

  let horizontal_span = (target_x - source_x).abs() + 1
  let vertical_span = (target_y - source_y).abs() + 1
  if horizontal_span >= label_len || horizontal_span >= vertical_span {
    ((source_x + target_x) / 2, source_y)
  } else {
    (target_x, (source_y + target_y) / 2)
  }
}

///|
fn flow_non_state_route_points(
  source_x : Int,
  source_y : Int,
  target_x : Int,
  target_y : Int,
  horizontal_first : Bool,
) -> Array[Point] {
  let points : Array[Point] = [{ x: source_x, y: source_y }]
  if source_x != target_x && source_y != target_y {
    if horizontal_first {
      points.push({ x: target_x, y: source_y })
    } else {
      points.push({ x: source_x, y: target_y })
    }
  }
  points.push({ x: target_x, y: target_y })
  points
}

///|
fn flow_non_state_route_hits_blocked_cells(
  points : Array[Point],
  blocked : Map[String, Bool],
) -> Bool {
  if points.length() < 2 {
    return false
  }

  for i in 1..<points.length() {
    let start = points[i - 1]
    let ending = points[i]
    if start.x == ending.x {
      let low = start.y.min(ending.y)
      let high = start.y.max(ending.y)
      for y in low..<=high {
        if y == start.y || y == ending.y {
          continue
        }
        if blocked.contains(ascii_grid_key({ x: start.x, y })) {
          return true
        }
      }
    } else if start.y == ending.y {
      let low = start.x.min(ending.x)
      let high = start.x.max(ending.x)
      for x in low..<=high {
        if x == start.x || x == ending.x {
          continue
        }
        if blocked.contains(ascii_grid_key({ x, y: start.y })) {
          return true
        }
      }
    }
  }
  false
}

///|
fn flow_compact_route_points(points : Array[Point]) -> Array[Point] {
  if points.length() <= 1 {
    return points
  }
  let compacted : Array[Point] = [points[0]]
  for i in 1..<points.length() {
    let current = points[i]
    let previous = compacted[compacted.length() - 1]
    if current.x != previous.x || current.y != previous.y {
      compacted.push(current)
    }
  }
  compacted
}

///|
fn flow_non_state_route_points_with_pathfinder(
  source_x : Int,
  source_y : Int,
  target_x : Int,
  target_y : Int,
  horizontal_first : Bool,
  blocked : Map[String, Bool],
  canvas_width : Int,
  canvas_height : Int,
) -> Array[Point] {
  let fallback = flow_non_state_route_points(
    source_x, source_y, target_x, target_y, horizontal_first,
  )
  if canvas_width <= 0 || canvas_height <= 0 {
    return fallback
  }

  let start = AsciiGridCoord::{ x: source_x, y: source_y }
  let ending = AsciiGridCoord::{ x: target_x, y: target_y }
  match
    @layout_engine_pathfinder_core.ascii_grid_pathfind(
      start,
      ending,
      blocked,
      0,
      canvas_width - 1,
      0,
      canvas_height - 1,
    ) {
    Some(path) => {
      if path.length() < 2 {
        return fallback
      }
      let merged_path = @layout_engine_pathfinder_core.ascii_grid_merge_path(
        path,
      )
      if merged_path.length() < 2 {
        return fallback
      }
      let route : Array[Point] = []
      for coord in merged_path {
        route.push({ x: coord.x, y: coord.y })
      }
      route
    }
    None => fallback
  }
}

///|
fn flow_non_state_shared_back_edge_route_points(
  source_id : String,
  target_id : String,
  source_anchor_x : Int,
  source_anchor_y : Int,
  source_box_height : Int,
  target_anchor_x : Int,
  target_anchor_y : Int,
  source_out_degree : Int,
  edges : Array[MermaidEdge],
  node_box_by_id : Map[String, AsciiFlowNodeBox],
) -> Array[Point]? {
  if source_out_degree < 2 {
    return None
  }

  let mut shared_anchor_x = -1
  for sibling in edges {
    if sibling.source != source_id || sibling.target == target_id {
      continue
    }
    match node_box_by_id.get(sibling.target) {
      Some(sibling_box) => {
        let sibling_anchor_x = sibling_box.left + sibling_box.width + 2
        let sibling_anchor_y = sibling_box.top + sibling_box.height / 2
        if sibling_anchor_y == source_anchor_y &&
          sibling_anchor_x < source_anchor_x &&
          sibling_anchor_x > shared_anchor_x {
          shared_anchor_x = sibling_anchor_x
        }
      }
      None => ()
    }
  }
  if shared_anchor_x <= target_anchor_x + 1 {
    return None
  }

  let target_entry_x = target_anchor_x + 3
  let detour_y = source_anchor_y + source_box_height.max(5)
  let route = flow_compact_route_points([
    { x: source_anchor_x, y: source_anchor_y },
    { x: shared_anchor_x, y: source_anchor_y },
    { x: shared_anchor_x, y: detour_y },
    { x: target_entry_x, y: detour_y },
    { x: target_entry_x, y: target_anchor_y },
    { x: target_anchor_x, y: target_anchor_y },
  ])
  if route.length() >= 2 {
    Some(route)
  } else {
    None
  }
}

///|
fn flow_non_state_edge_span(start : Point, ending : Point) -> Int {
  (ending.x - start.x).abs() + (ending.y - start.y).abs()
}

///|
fn flow_non_state_back_edge_detour_row(
  source_id : String,
  target_id : String,
  source_x : Int,
  target_x : Int,
  min_y : Int,
  nodes : Array[AsciiFlowNodeBox],
) -> Int {
  let mut detour_y = min_y
  let left = source_x.min(target_x)
  let right = source_x.max(target_x)
  for node in nodes {
    if node.id == source_id || node.id == target_id {
      continue
    }
    let node_left = node.left
    let node_right = node.left + node.width - 1
    let overlaps_x = !(right < node_left || left > node_right)
    if overlaps_x && node.top <= min_y {
      detour_y = detour_y.max(node.top + node.height + 1)
    }
  }
  detour_y
}

///|
fn flow_non_state_label_anchor_from_points(
  points : Array[Point],
  source_x : Int,
  source_y : Int,
  target_x : Int,
  target_y : Int,
  label_len : Int,
) -> (Int, Int) {
  if points.length() < 2 {
    return flow_non_state_label_anchor(
      source_x, source_y, target_x, target_y, label_len,
    )
  }

  let mut best_start = points[0]
  let mut best_end = points[1]
  let mut best_span = flow_non_state_edge_span(best_start, best_end)
  let mut found_label_fit = false
  if best_span >= label_len {
    found_label_fit = true
  }

  for i in 1..<points.length() {
    let start = points[i - 1]
    let ending = points[i]
    let span = flow_non_state_edge_span(start, ending)
    if span >= label_len {
      if !found_label_fit {
        best_start = start
        best_end = ending
        found_label_fit = true
      }
      break
    } else if !found_label_fit && span > best_span {
      best_start = start
      best_end = ending
      best_span = span
    }
  }

  let point = midpoint(best_start, best_end)
  (point.x, point.y)
}

///|
fn flow_non_state_edge_label_placement(
  points : Array[Point],
  source_x : Int,
  source_y : Int,
  target_x : Int,
  target_y : Int,
  label : String,
  boxes : Array[AsciiFlowNodeBox],
  existing_labels : Array[AsciiEdgeLabelPlacement],
) -> AsciiEdgeLabelPlacement {
  fn overlaps_existing_labels(
    label_x : Int,
    label_y : Int,
    label : String,
    existing_labels : Array[AsciiEdgeLabelPlacement],
  ) -> Bool {
    let left = label_x
    let right = label_x + label.length() - 1
    for placement in existing_labels {
      if placement.y != label_y {
        continue
      }
      let other_left = placement.x
      let other_right = placement.x + placement.label.length() - 1
      if !(right + 1 < other_left || left > other_right + 1) {
        return true
      }
    }
    false
  }

  let level_back_edge_detour = points.length() == 4 &&
    points[0].x == points[1].x &&
    points[1].y == points[2].y &&
    points[2].x == points[3].x &&
    points[0].x > points[3].x &&
    points[0].y == points[3].y
  let left_descending_labeled_detour = points.length() == 5 &&
    points[0].y == points[1].y &&
    points[1].x == points[2].x &&
    points[2].y == points[3].y &&
    points[3].x == points[4].x &&
    points[0].x > points[1].x &&
    points[2].y < points[4].y
  let (anchor_x, anchor_y) = if level_back_edge_detour {
    (points[0].x, points[0].y + 1)
  } else if left_descending_labeled_detour {
    (points[0].x, points[0].y)
  } else {
    flow_non_state_label_anchor_from_points(
      points,
      source_x,
      source_y,
      target_x,
      target_y,
      label.length(),
    )
  }
  let mut label_x = if left_descending_labeled_detour {
    points[0].x - label.length()
  } else {
    anchor_x - label.length() / 2
  }
  if source_y == target_y {
    if source_x < target_x {
      let max_right = target_x - 2
      let label_right = label_x + label.length() - 1
      if label_right > max_right {
        label_x = max_right - label.length() + 1
      }
    } else if source_x > target_x {
      let min_left = target_x + 2
      if label_x < min_left {
        label_x = min_left
      }
    }
  }
  let base_y = if label_overlaps_any_node_box(label_x, anchor_y, label, boxes) {
    adjust_label_y_for_state_boxes(label_x, anchor_y, label, boxes)
  } else {
    anchor_y
  }
  if !label_overlaps_any_node_box(label_x, base_y, label, boxes) &&
    !overlaps_existing_labels(label_x, base_y, label, existing_labels) {
    return { x: label_x, y: base_y, label }
  }

  for offset in 1..<8 {
    let up = base_y - offset
    if up >= 0 &&
      !label_overlaps_any_node_box(label_x, up, label, boxes) &&
      !overlaps_existing_labels(label_x, up, label, existing_labels) {
      return { x: label_x, y: up, label }
    }
    let down = base_y + offset
    if !label_overlaps_any_node_box(label_x, down, label, boxes) &&
      !overlaps_existing_labels(label_x, down, label, existing_labels) {
      return { x: label_x, y: down, label }
    }
  }

  { x: label_x, y: base_y, label }
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

  let center_bias = if label.length() % 2 == 0 { 1 } else { 0 }
  let text_x = left + ((width - label.length() + center_bias) / 2).max(1)
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
fn flow_connects_up(ch : String) -> Bool {
  flow_is_vertical_line_char(ch) ||
  ch == "┼" ||
  ch == "├" ||
  ch == "┤" ||
  ch == "┴" ||
  ch == "└" ||
  ch == "┘"
}

///|
fn flow_connects_down(ch : String) -> Bool {
  flow_is_vertical_line_char(ch) ||
  ch == "┼" ||
  ch == "├" ||
  ch == "┤" ||
  ch == "┬" ||
  ch == "┌" ||
  ch == "┐"
}

///|
fn flow_connects_left(ch : String) -> Bool {
  flow_is_horizontal_line_char(ch) ||
  ch == "┼" ||
  ch == "┤" ||
  ch == "┬" ||
  ch == "┴" ||
  ch == "┐" ||
  ch == "┘"
}

///|
fn flow_connects_right(ch : String) -> Bool {
  flow_is_horizontal_line_char(ch) ||
  ch == "┼" ||
  ch == "├" ||
  ch == "┬" ||
  ch == "┴" ||
  ch == "┌" ||
  ch == "└"
}

///|
fn flow_unicode_horizontal_line_for(existing : String) -> String {
  if existing == "┄" {
    "┄"
  } else if existing == "═" {
    "═"
  } else {
    "─"
  }
}

///|
fn flow_unicode_vertical_line_for(existing : String) -> String {
  if existing == "┊" {
    "┊"
  } else if existing == "║" {
    "║"
  } else {
    "│"
  }
}

///|
fn flow_unicode_char_for_connections(
  existing : String,
  has_left : Bool,
  has_right : Bool,
  has_up : Bool,
  has_down : Bool,
) -> String {
  let connection_count = (if has_left { 1 } else { 0 }) +
    (if has_right { 1 } else { 0 }) +
    (if has_up { 1 } else { 0 }) +
    (if has_down { 1 } else { 0 })

  if connection_count == 4 {
    return "┼"
  }

  if connection_count == 3 {
    if !has_up {
      return "┬"
    }
    if !has_down {
      return "┴"
    }
    if !has_left {
      return "├"
    }
    return "┤"
  }

  if connection_count == 2 {
    if has_left && has_right {
      return flow_unicode_horizontal_line_for(existing)
    }
    if has_up && has_down {
      return flow_unicode_vertical_line_for(existing)
    }
    if has_right && has_down {
      return "┌"
    }
    if has_left && has_down {
      return "┐"
    }
    if has_right && has_up {
      return "└"
    }
    if has_left && has_up {
      return "┘"
    }
  }

  existing
}

///|
fn flow_normalize_unicode_junctions(canvas : Array[Array[String]]) -> Unit {
  if canvas.length() == 0 || canvas[0].length() == 0 {
    return
  }

  let snapshot : Array[Array[String]] = []
  for row in canvas {
    let copied_row : Array[String] = []
    for ch in row {
      copied_row.push(ch)
    }
    snapshot.push(copied_row)
  }

  for y in 0..<snapshot.length() {
    for x in 0..<snapshot[0].length() {
      let existing = snapshot[y][x]
      let has_line_char = flow_is_horizontal_line_char(existing) ||
        flow_is_vertical_line_char(existing) ||
        flow_is_corner_or_junction_char(existing)
      if !has_line_char || existing == "+" {
        continue
      }

      let has_left = x > 0 && flow_connects_right(snapshot[y][x - 1])
      let has_right = x + 1 < snapshot[0].length() &&
        flow_connects_left(snapshot[y][x + 1])
      let has_up = y > 0 && flow_connects_down(snapshot[y - 1][x])
      let has_down = y + 1 < snapshot.length() &&
        flow_connects_up(snapshot[y + 1][x])

      canvas[y][x] = flow_unicode_char_for_connections(
        existing, has_left, has_right, has_up, has_down,
      )
    }
  }
}

///|
fn flow_refine_unicode_side_tees(canvas : Array[Array[String]]) -> Unit {
  if canvas.length() == 0 || canvas[0].length() == 0 {
    return
  }

  let snapshot : Array[Array[String]] = []
  for row in canvas {
    let copied_row : Array[String] = []
    for ch in row {
      copied_row.push(ch)
    }
    snapshot.push(copied_row)
  }

  for y in 0..<snapshot.length() {
    for x in 0..<snapshot[0].length() {
      let existing = snapshot[y][x]
      if existing != "┤" && existing != "├" {
        continue
      }
      let has_left = x > 0 && flow_connects_right(snapshot[y][x - 1])
      let has_right = x + 1 < snapshot[0].length() &&
        flow_connects_left(snapshot[y][x + 1])
      let has_up = y > 0 && flow_connects_down(snapshot[y - 1][x])
      let has_down = y + 1 < snapshot.length() &&
        flow_connects_up(snapshot[y + 1][x])
      canvas[y][x] = flow_unicode_char_for_connections(
        existing, has_left, has_right, has_up, has_down,
      )
    }
  }
}

///|
fn flow_put_unicode_border_join(
  canvas : Array[Array[String]],
  x : Int,
  y : Int,
) -> Unit {
  if y < 0 || y >= canvas.length() {
    return
  }
  if canvas.length() == 0 || x < 0 || x >= canvas[0].length() {
    return
  }

  let existing = canvas[y][x]
  let has_left = x > 0 && flow_connects_right(canvas[y][x - 1])
  let has_right = x + 1 < canvas[0].length() &&
    flow_connects_left(canvas[y][x + 1])
  let has_up = y > 0 && flow_connects_down(canvas[y - 1][x])
  let has_down = y + 1 < canvas.length() && flow_connects_up(canvas[y + 1][x])

  put_canvas(
    canvas,
    x,
    y,
    flow_unicode_char_for_connections(
      existing, has_left, has_right, has_up, has_down,
    ),
  )
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
    if use_ascii {
      canvas[y][x] = ch
      return
    }

    if horizontal {
      let has_up = y > 0 && flow_connects_down(canvas[y - 1][x])
      let has_down = y + 1 < canvas.length() &&
        flow_connects_up(canvas[y + 1][x])
      canvas[y][x] = if has_up && has_down {
        "┼"
      } else if has_down {
        "┬"
      } else if has_up {
        "┴"
      } else {
        "┼"
      }
    } else {
      let has_left = x > 0 && flow_connects_right(canvas[y][x - 1])
      let has_right = x + 1 < canvas[0].length() &&
        flow_connects_left(canvas[y][x + 1])
      canvas[y][x] = if has_left && has_right {
        "┼"
      } else if has_right {
        "├"
      } else if has_left {
        "┤"
      } else {
        "┼"
      }
    }
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
fn flow_mark_ascii_route_bends(
  canvas : Array[Array[String]],
  route_points : Array[Point],
) -> Unit {
  if route_points.length() < 3 {
    return
  }
  for i in 1..<(route_points.length() - 1) {
    let previous = route_points[i - 1]
    let current = route_points[i]
    let next = route_points[i + 1]
    let prev_dx = unit_step(current.x - previous.x)
    let prev_dy = unit_step(current.y - previous.y)
    let next_dx = unit_step(next.x - current.x)
    let next_dy = unit_step(next.y - current.y)
    if prev_dx != next_dx || prev_dy != next_dy {
      put_canvas(canvas, current.x, current.y, "+")
    }
  }
}

///|
fn flow_mark_ascii_route_intersections(
  canvas : Array[Array[String]],
  route_points : Array[Point],
) -> Unit {
  if route_points.length() < 2 || canvas.length() == 0 {
    return
  }
  let width = canvas[0].length()
  for i in 1..<route_points.length() {
    let start = route_points[i - 1]
    let ending = route_points[i]
    if start.y != ending.y {
      continue
    }
    let y = start.y
    if y < 0 || y >= canvas.length() {
      continue
    }
    let low = start.x.min(ending.x)
    let high = start.x.max(ending.x)
    for x in low..<=high {
      if x < 0 || x >= width {
        continue
      }
      let has_left = x > 0 && flow_connects_right(canvas[y][x - 1])
      let has_right = x + 1 < width && flow_connects_left(canvas[y][x + 1])
      let has_up = y > 0 && flow_connects_down(canvas[y - 1][x])
      let has_down = y + 1 < canvas.length() &&
        flow_connects_up(canvas[y + 1][x])
      if (has_left || has_right) && (has_up || has_down) {
        put_canvas(canvas, x, y, "+")
      }
    }
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
        blocked[ascii_grid_key({ x, y })] = true
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
    @layout_engine_pathfinder_core.ascii_grid_pathfind(
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
    7
  }
  let width = if state_composite_layout_mode {
    scale_size(group.width, scale_x, min_width)
  } else {
    (group.width / scale_x).max(min_width)
  }
  {
    id: group.id,
    label: group.label,
    left: scale_coord(group.x, scale_x, pad_x),
    top: scale_coord(group.y, scale_y, pad_y),
    width,
    height: scale_size(group.height, scale_y, 5),
    children,
  }
}

///|
fn flow_group_right(group : AsciiFlowGroupBox) -> Int {
  group.left + group.width - 1
}

///|
fn flow_group_bottom(group : AsciiFlowGroupBox) -> Int {
  group.top + group.height - 1
}

///|
fn state_group_box_from_nodes(
  subgraph : MermaidSubgraph,
  node_box_by_id : Map[String, AsciiFlowNodeBox],
) -> AsciiFlowGroupBox? {
  let children : Array[AsciiFlowGroupBox] = []
  let mut has_bounds = false
  let mut min_left = 0
  let mut min_top = 0
  let mut max_right = 0
  let mut max_bottom = 0

  for child in subgraph.children {
    match state_group_box_from_nodes(child, node_box_by_id) {
      Some(group) => {
        children.push(group)
        let right = flow_group_right(group)
        let bottom = flow_group_bottom(group)
        if !has_bounds {
          min_left = group.left
          min_top = group.top
          max_right = right
          max_bottom = bottom
          has_bounds = true
        } else {
          min_left = min_left.min(group.left)
          min_top = min_top.min(group.top)
          max_right = max_right.max(right)
          max_bottom = max_bottom.max(bottom)
        }
      }
      None => ()
    }
  }

  for node_id in subgraph.node_ids {
    match node_box_by_id.get(node_id) {
      Some(box) => {
        let right = box.left + box.width - 1
        let bottom = box.top + box.height - 1
        if !has_bounds {
          min_left = box.left
          min_top = box.top
          max_right = right
          max_bottom = bottom
          has_bounds = true
        } else {
          min_left = min_left.min(box.left)
          min_top = min_top.min(box.top)
          max_right = max_right.max(right)
          max_bottom = max_bottom.max(bottom)
        }
      }
      None => ()
    }
  }

  if !has_bounds {
    return None
  }

  let group_padding = 2
  let label_space = 2
  let left = min_left - group_padding
  let top = min_top - group_padding - label_space
  let right = max_right + group_padding
  let bottom = max_bottom + group_padding
  Some({
    id: subgraph.id,
    label: subgraph.label,
    left,
    top,
    width: right - left + 1,
    height: bottom - top + 1,
    children,
  })
}

///|
fn state_mapped_groups_from_nodes(
  graph : MermaidGraph,
  node_box_by_id : Map[String, AsciiFlowNodeBox],
) -> Array[AsciiFlowGroupBox] {
  let groups : Array[AsciiFlowGroupBox] = []
  for subgraph in graph.subgraphs {
    match state_group_box_from_nodes(subgraph, node_box_by_id) {
      Some(group) => groups.push(group)
      None => ()
    }
  }
  groups
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
fn shift_ascii_flow_group(
  group : AsciiFlowGroupBox,
  shift_x : Int,
  shift_y : Int,
) -> AsciiFlowGroupBox {
  let children : Array[AsciiFlowGroupBox] = []
  for child in group.children {
    children.push(shift_ascii_flow_group(child, shift_x, shift_y))
  }
  {
    id: group.id,
    label: group.label,
    left: group.left + shift_x,
    top: group.top + shift_y,
    width: group.width,
    height: group.height,
    children,
  }
}

///|
fn flow_collect_node_top_level_group_ids(
  subgraph : MermaidSubgraph,
  top_level_group_id : String,
  node_top_level_group_by_id : Map[String, String],
) -> Unit {
  for node_id in subgraph.node_ids {
    if !node_top_level_group_by_id.contains(node_id) {
      node_top_level_group_by_id[node_id] = top_level_group_id
    }
  }
  for child in subgraph.children {
    flow_collect_node_top_level_group_ids(
      child, top_level_group_id, node_top_level_group_by_id,
    )
  }
}

///|
fn flow_lr_top_level_group_shifts(
  groups : Array[AsciiFlowGroupBox],
) -> Map[String, Int] {
  let shifts : Map[String, Int] = {}
  if groups.length() <= 1 {
    return shifts
  }

  let ordered_indexes : Array[Int] = []
  for i in 0..<groups.length() {
    ordered_indexes.push(i)
  }
  for i in 1..<ordered_indexes.length() {
    let mut j = i
    while j > 0 &&
          groups[ordered_indexes[j - 1]].left > groups[ordered_indexes[j]].left {
      let tmp = ordered_indexes[j - 1]
      ordered_indexes[j - 1] = ordered_indexes[j]
      ordered_indexes[j] = tmp
      j = j - 1
    }
  }

  let mut cumulative_shift = 0
  let first_group = groups[ordered_indexes[0]]
  shifts[first_group.id] = 0
  let mut previous_right = first_group.left + first_group.width - 1
  for i in 1..<ordered_indexes.length() {
    let group = groups[ordered_indexes[i]]
    let shifted_left = group.left + cumulative_shift
    let desired_left = previous_right + 3
    if shifted_left > desired_left {
      cumulative_shift = cumulative_shift - (shifted_left - desired_left)
    }
    shifts[group.id] = cumulative_shift
    previous_right = group.left + cumulative_shift + group.width - 1
  }
  shifts
}

///|
fn flow_group_contains_node_center(
  group : AsciiFlowGroupBox,
  node : AsciiFlowNodeBox,
) -> Bool {
  let center_x = node.left + node.width / 2
  let center_y = node.top + node.height / 2
  center_x >= group.left &&
  center_x <= group.left + group.width - 1 &&
  center_y >= group.top &&
  center_y <= group.top + group.height - 1
}

///|
fn flow_subgraph_has_content(subgraph : MermaidSubgraph) -> Bool {
  if subgraph.node_ids.length() > 0 {
    return true
  }
  for child in subgraph.children {
    if flow_subgraph_has_content(child) {
      return true
    }
  }
  false
}

///|
fn flow_collect_subgraph_content_flags(
  subgraphs : Array[MermaidSubgraph],
  has_content : Map[String, Bool],
) -> Unit {
  for subgraph in subgraphs {
    flow_collect_subgraph_content_flags(subgraph.children, has_content)
    has_content[subgraph.id] = flow_subgraph_has_content(subgraph)
  }
}

///|
fn flow_filter_groups_by_subgraph_content(
  groups : Array[AsciiFlowGroupBox],
  has_content : Map[String, Bool],
) -> Array[AsciiFlowGroupBox] {
  let filtered : Array[AsciiFlowGroupBox] = []
  for group in groups {
    let filtered_children = flow_filter_groups_by_subgraph_content(
      group.children,
      has_content,
    )
    let keep_group = match has_content.get(group.id) {
      Some(value) => value
      None => true
    }
    if keep_group || filtered_children.length() > 0 {
      filtered.push({
        id: group.id,
        label: group.label,
        left: group.left,
        top: group.top,
        width: group.width,
        height: group.height,
        children: filtered_children,
      })
    }
  }
  filtered
}

///|
fn flow_collect_subgraph_has_direct_nodes(
  subgraphs : Array[MermaidSubgraph],
  has_direct_nodes : Map[String, Bool],
) -> Unit {
  for subgraph in subgraphs {
    has_direct_nodes[subgraph.id] = subgraph.node_ids.length() > 0
    flow_collect_subgraph_has_direct_nodes(subgraph.children, has_direct_nodes)
  }
}

///|
fn flow_collect_node_has_indirect_ancestor(
  subgraphs : Array[MermaidSubgraph],
  has_indirect_ancestor : Bool,
  node_has_indirect_ancestor : Map[String, Bool],
) -> Unit {
  for subgraph in subgraphs {
    for node_id in subgraph.node_ids {
      if has_indirect_ancestor {
        node_has_indirect_ancestor[node_id] = true
      }
    }
    let child_has_indirect_ancestor = has_indirect_ancestor ||
      subgraph.node_ids.length() == 0
    flow_collect_node_has_indirect_ancestor(
      subgraph.children,
      child_has_indirect_ancestor,
      node_has_indirect_ancestor,
    )
  }
}

///|
fn flow_expand_indirect_nested_group_bottom_padding(
  group : AsciiFlowGroupBox,
  has_direct_nodes : Map[String, Bool],
) -> AsciiFlowGroupBox {
  let adjusted_children : Array[AsciiFlowGroupBox] = []
  for child in group.children {
    adjusted_children.push(
      flow_expand_indirect_nested_group_bottom_padding(child, has_direct_nodes),
    )
  }
  let has_direct_nodes_here = match has_direct_nodes.get(group.id) {
    Some(value) => value
    None => true
  }
  let grow_bottom = adjusted_children.length() > 0 && !has_direct_nodes_here
  {
    id: group.id,
    label: group.label,
    left: group.left,
    top: group.top,
    width: group.width,
    height: group.height + (if grow_bottom { 1 } else { 0 }),
    children: adjusted_children,
  }
}

///|
fn flow_expand_group_side_padding_for_nodes(
  group : AsciiFlowGroupBox,
  nodes : Array[AsciiFlowNodeBox],
  require_node_within_group : Bool,
) -> AsciiFlowGroupBox {
  let adjusted_children : Array[AsciiFlowGroupBox] = []
  for child in group.children {
    adjusted_children.push(
      flow_expand_group_side_padding_for_nodes(
        child, nodes, require_node_within_group,
      ),
    )
  }

  let mut left = group.left
  let mut right = flow_group_right(group)
  let mut has_content = false
  let mut content_left = 0
  let mut content_right = 0
  for child in adjusted_children {
    let child_left = child.left
    let child_right = flow_group_right(child)
    if !has_content {
      content_left = child_left
      content_right = child_right
      has_content = true
    } else {
      content_left = content_left.min(child_left)
      content_right = content_right.max(child_right)
    }
    if child_left <= left + 1 {
      left = child_left - 2
    }
    if child_right >= right - 1 {
      right = child_right + 2
    }
  }

  for node in nodes {
    if require_node_within_group &&
      !flow_group_contains_node_center(group, node) {
      continue
    }
    let node_left = node.left
    let node_right = node.left + node.width - 1
    if !has_content {
      content_left = node_left
      content_right = node_right
      has_content = true
    } else {
      content_left = content_left.min(node_left)
      content_right = content_right.max(node_right)
    }
    if node_left <= left + 1 {
      left = node_left - 2
    }
    if node_right >= right - 1 {
      right = node_right + 2
    }
  }
  if has_content {
    let desired_left = content_left - 2
    let desired_right = content_right + 2
    if desired_left > left {
      left = desired_left
    }
    if desired_right < right {
      right = desired_right
    }
  }
  {
    id: group.id,
    label: group.label,
    left,
    top: group.top,
    width: right - left + 1,
    height: group.height,
    children: adjusted_children,
  }
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
  let label_room = (group.width - 2).max(0)
  let label = if group.label.length() > label_room {
    (try! group.label[:label_room]).to_string()
  } else {
    group.label
  }
  let centered_x = group.left + (group.width - 1) / 2 - label.length() / 2
  let label_x = centered_x.max(group.left + 1)
  let label_y = group.top + 1
  write_canvas_text(canvas, label_x, label_y, label)
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
fn state_ascii_node_label(node : MermaidNode) -> String {
  match node.shape {
    StateStart | StateEnd => ""
    _ =>
      if node.label == "" {
        node.id
      } else {
        node.label.replace_all(old="\n", new=" | ")
      }
  }
}

///|
fn state_ascii_line_width(
  column_width : Map[Int, Int],
  start_x : Int,
  end_x : Int,
) -> Int {
  let start = start_x.min(end_x)
  let ending = start_x.max(end_x)
  let mut total = 0
  for x in start..<=ending {
    total = total + option_int_or(column_width.get(x), 0)
  }
  total
}

///|
fn state_ascii_grid_to_draw(
  column_width : Map[Int, Int],
  row_height : Map[Int, Int],
  coord : AsciiGridCoord,
) -> (Int, Int) {
  let mut x = 0
  for column in 0..<coord.x {
    x = x + option_int_or(column_width.get(column), 0)
  }
  let mut y = 0
  for row in 0..<coord.y {
    y = y + option_int_or(row_height.get(row), 0)
  }
  x = x + option_int_or(column_width.get(coord.x), 0) / 2
  y = y + option_int_or(row_height.get(coord.y), 0) / 2
  (x, y)
}

///|
fn state_ascii_corner_char(
  prev_dx : Int,
  prev_dy : Int,
  next_dx : Int,
  next_dy : Int,
  use_ascii : Bool,
) -> String {
  if use_ascii {
    return "+"
  }
  if (prev_dx == 1 && prev_dy == 0 && next_dx == 0 && next_dy == 1) ||
    (prev_dx == 0 && prev_dy == -1 && next_dx == -1 && next_dy == 0) {
    "┐"
  } else if (prev_dx == 1 && prev_dy == 0 && next_dx == 0 && next_dy == -1) ||
    (prev_dx == 0 && prev_dy == 1 && next_dx == -1 && next_dy == 0) {
    "┘"
  } else if (prev_dx == -1 && prev_dy == 0 && next_dx == 0 && next_dy == 1) ||
    (prev_dx == 0 && prev_dy == -1 && next_dx == 1 && next_dy == 0) {
    "┌"
  } else if (prev_dx == -1 && prev_dy == 0 && next_dx == 0 && next_dy == -1) ||
    (prev_dx == 0 && prev_dy == 1 && next_dx == 1 && next_dy == 0) {
    "└"
  } else {
    "+"
  }
}

///|
fn state_ascii_draw_segment_simple(
  canvas : Array[Array[String]],
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  h_char : String,
  v_char : String,
) -> Unit {
  if x1 == x2 {
    let start = y1.min(y2)
    let ending = y1.max(y2)
    for y in start..<=ending {
      put_canvas(canvas, x1, y, v_char)
    }
    return
  }
  if y1 == y2 {
    let start = x1.min(x2)
    let ending = x1.max(x2)
    for x in start..<=ending {
      put_canvas(canvas, x, y1, h_char)
    }
    return
  }

  let h_start = x1.min(x2)
  let h_end = x1.max(x2)
  for x in h_start..<=h_end {
    put_canvas(canvas, x, y1, h_char)
  }
  let v_start = y1.min(y2)
  let v_end = y1.max(y2)
  for y in v_start..<=v_end {
    put_canvas(canvas, x2, y, v_char)
  }
}

///|
fn render_ascii_state_flat_grid(
  graph : MermaidGraph,
  layout_plan : @renderer_ascii_layout_plan.AsciiStateFlatGridLayout,
  options : AsciiRenderOptions,
) -> String {
  let nodes_in_order = layout_plan.nodes_in_order
  let grid_positions = layout_plan.grid_positions
  let state_layout_mode = graph_has_shape(graph, StateStart) ||
    graph_has_shape(graph, StateEnd)
  if grid_positions.length() == 0 {
    return ""
  }

  let column_width : Map[Int, Int] = {}
  let row_height : Map[Int, Int] = {}
  for node in nodes_in_order {
    match grid_positions.get(node.id) {
      Some(coord) => {
        let label = state_ascii_node_label(node)
        let content_width = options.box_border_padding * 2 + label.length()
        let content_height = 1 + options.box_border_padding * 2

        let col0 = option_int_or(column_width.get(coord.x), 0)
        if 1 > col0 {
          column_width[coord.x] = 1
        }
        let col1 = option_int_or(column_width.get(coord.x + 1), 0)
        if content_width > col1 {
          column_width[coord.x + 1] = content_width
        }
        let col2 = option_int_or(column_width.get(coord.x + 2), 0)
        if 1 > col2 {
          column_width[coord.x + 2] = 1
        }

        let row0 = option_int_or(row_height.get(coord.y), 0)
        if 1 > row0 {
          row_height[coord.y] = 1
        }
        let row1 = option_int_or(row_height.get(coord.y + 1), 0)
        if content_height > row1 {
          row_height[coord.y + 1] = content_height
        }
        let row2 = option_int_or(row_height.get(coord.y + 2), 0)
        if 1 > row2 {
          row_height[coord.y + 2] = 1
        }

        if coord.x > 0 {
          let gap_col = option_int_or(column_width.get(coord.x - 1), 0)
          if options.padding_x > gap_col {
            column_width[coord.x - 1] = options.padding_x
          }
        }
        if coord.y > 0 {
          let gap_row = option_int_or(row_height.get(coord.y - 1), 0)
          if options.padding_y > gap_row {
            row_height[coord.y - 1] = options.padding_y
          }
        }
      }
      None => ()
    }
  }

  let edge_layouts : Array[StateAsciiEdgeLayout] = []
  let edge_paths = layout_plan.edge_paths
  for i, edge in graph.edges {
    let path = if i < edge_paths.length() { edge_paths[i] } else { [] }

    for coord in path {
      if !column_width.contains(coord.x) {
        column_width[coord.x] = (options.padding_x / 2).max(1)
      }
      if !row_height.contains(coord.y) {
        row_height[coord.y] = (options.padding_y / 2).max(1)
      }
    }

    let label_line : Array[AsciiGridCoord] = []
    match edge.label {
      Some(label) =>
        if path.length() >= 2 {
          let mut best_start = path[0]
          let mut best_end = path[1]
          let mut best_width = 0
          for i in 1..<path.length() {
            let start = path[i - 1]
            let ending = path[i]
            let line_width = state_ascii_line_width(
              column_width,
              start.x,
              ending.x,
            )
            if line_width >= label.length() {
              best_start = start
              best_end = ending
              break
            }
            if line_width > best_width {
              best_width = line_width
              best_start = start
              best_end = ending
            }
          }
          let min_x = best_start.x.min(best_end.x)
          let max_x = best_start.x.max(best_end.x)
          let middle_x = min_x + (max_x - min_x) / 2
          let current_width = option_int_or(column_width.get(middle_x), 0)
          if label.length() + 2 > current_width {
            column_width[middle_x] = label.length() + 2
          }
          label_line.push(best_start)
          label_line.push(best_end)
        }
      None => ()
    }
    edge_layouts.push({ edge, path, label_line })
  }

  let mapped_nodes : Array[AsciiFlowNodeBox] = []
  let node_box_by_id : Map[String, AsciiFlowNodeBox] = {}
  for node in nodes_in_order {
    match grid_positions.get(node.id) {
      Some(coord) => {
        let (left, top) = state_ascii_grid_to_draw(column_width, row_height, {
          x: coord.x,
          y: coord.y,
        })
        let width = option_int_or(column_width.get(coord.x), 0) +
          option_int_or(column_width.get(coord.x + 1), 0) +
          1
        let height = option_int_or(row_height.get(coord.y), 0) +
          option_int_or(row_height.get(coord.y + 1), 0) +
          1
        let box = AsciiFlowNodeBox::{
          id: node.id,
          label: state_ascii_node_label(node),
          left,
          top,
          width: width.max(3),
          height: height.max(3),
        }
        mapped_nodes.push(box)
        node_box_by_id[box.id] = box
      }
      None => ()
    }
  }
  let mapped_groups = state_mapped_groups_from_nodes(graph, node_box_by_id)

  let mut min_x = 0
  let mut min_y = 0
  let mut max_x = 0
  let mut max_y = 0
  let mut has_bounds = false
  for node in mapped_nodes {
    let right = node.left + node.width - 1
    let bottom = node.top + node.height - 1
    if !has_bounds {
      min_x = node.left
      min_y = node.top
      max_x = right
      max_y = bottom
      has_bounds = true
    } else {
      min_x = min_x.min(node.left)
      min_y = min_y.min(node.top)
      max_x = max_x.max(right)
      max_y = max_y.max(bottom)
    }
  }
  for group in mapped_groups {
    let right = flow_group_max_x(group) - 1
    let bottom = flow_group_max_y(group) - 1
    if !has_bounds {
      min_x = group.left
      min_y = group.top
      max_x = right
      max_y = bottom
      has_bounds = true
    } else {
      min_x = min_x.min(group.left)
      min_y = min_y.min(group.top)
      max_x = max_x.max(right)
      max_y = max_y.max(bottom)
    }
  }
  for layout in edge_layouts {
    for coord in layout.path {
      let (x, y) = state_ascii_grid_to_draw(column_width, row_height, coord)
      if !has_bounds {
        min_x = x
        min_y = y
        max_x = x
        max_y = y
        has_bounds = true
      } else {
        min_x = min_x.min(x)
        min_y = min_y.min(y)
        max_x = max_x.max(x)
        max_y = max_y.max(y)
      }
    }
    if layout.label_line.length() == 2 {
      match layout.edge.label {
        Some(label) => {
          let (x1, y1) = state_ascii_grid_to_draw(
            column_width,
            row_height,
            layout.label_line[0],
          )
          let (x2, y2) = state_ascii_grid_to_draw(
            column_width,
            row_height,
            layout.label_line[1],
          )
          let anchor_x = x1.min(x2) + (x1.max(x2) - x1.min(x2)) / 2
          let anchor_y = y1.min(y2) + (y1.max(y2) - y1.min(y2)) / 2
          let label_x = anchor_x - label.length() / 2
          let label_right = label_x + label.length() - 1
          if !has_bounds {
            min_x = label_x
            max_x = label_right
            min_y = anchor_y
            max_y = anchor_y
            has_bounds = true
          } else {
            min_x = min_x.min(label_x)
            max_x = max_x.max(label_right)
            min_y = min_y.min(anchor_y)
            max_y = max_y.max(anchor_y)
          }
        }
        None => ()
      }
    }
  }
  if !has_bounds {
    return ""
  }

  let shift_x = if min_x < 0 { -min_x } else { 0 }
  let shift_y = if min_y < 0 { -min_y } else { 0 }
  let canvas = make_canvas(max_x + shift_x + 2, max_y + shift_y + 2)
  let shifted_groups : Array[AsciiFlowGroupBox] = []
  for group in mapped_groups {
    shifted_groups.push(shift_ascii_flow_group(group, shift_x, shift_y))
  }

  for group in shifted_groups {
    flow_draw_group(canvas, group, options.use_ascii)
  }

  for node in mapped_nodes {
    flow_draw_box(
      canvas,
      node.left + shift_x,
      node.top + shift_y,
      node.width,
      node.height,
      node.label,
      options.use_ascii,
    )
  }

  let corner_overlays : Array[AsciiArrowPlacement] = []
  let arrow_overlays : Array[AsciiArrowPlacement] = []
  let box_start_overlays : Array[AsciiArrowPlacement] = []
  let edge_label_overlays : Array[AsciiEdgeLabelPlacement] = []

  for layout in edge_layouts {
    let points : Array[Point] = []
    for coord in layout.path {
      let (x, y) = state_ascii_grid_to_draw(column_width, row_height, coord)
      points.push({ x: x + shift_x, y: y + shift_y })
    }
    if points.length() < 2 {
      continue
    }

    let line_style = if state_layout_mode { layout.edge.style } else { Solid }
    let (h_char, v_char) = flow_line_chars(line_style, options.use_ascii)
    let mut first_drawn : Point? = None
    let mut first_dir_x = 0
    let mut first_dir_y = 0
    let mut last_drawn : Point? = None
    let mut last_dir_x = 0
    let mut last_dir_y = 0

    for i in 1..<points.length() {
      let previous = points[i - 1]
      let next = points[i]
      let dir_x = unit_step(next.x - previous.x)
      let dir_y = unit_step(next.y - previous.y)
      let first_segment = i == 1
      let last_segment = i == points.length() - 1
      let start_x = if first_segment { previous.x + dir_x } else { previous.x }
      let start_y = if first_segment { previous.y + dir_y } else { previous.y }
      let end_x = if last_segment { next.x - dir_x } else { next.x }
      let end_y = if last_segment { next.y - dir_y } else { next.y }
      if start_x == end_x && start_y == end_y {
        continue
      }

      if options.use_ascii {
        state_ascii_draw_segment_simple(
          canvas, start_x, start_y, end_x, end_y, h_char, v_char,
        )
      } else {
        flow_draw_segment(
          canvas, start_x, start_y, end_x, end_y, h_char, v_char,
        )
      }
      if first_drawn is None {
        first_drawn = Some({ x: start_x, y: start_y })
        first_dir_x = dir_x
        first_dir_y = dir_y
      }
      last_drawn = Some({ x: end_x, y: end_y })
      last_dir_x = dir_x
      last_dir_y = dir_y
    }

    if points.length() >= 3 {
      for i in 1..<(points.length() - 1) {
        let previous = points[i - 1]
        let current = points[i]
        let next = points[i + 1]
        let prev_dx = unit_step(current.x - previous.x)
        let prev_dy = unit_step(current.y - previous.y)
        let next_dx = unit_step(next.x - current.x)
        let next_dy = unit_step(next.y - current.y)
        if prev_dx == next_dx && prev_dy == next_dy {
          continue
        }
        corner_overlays.push({
          x: current.x,
          y: current.y,
          marker: state_ascii_corner_char(
            prev_dx,
            prev_dy,
            next_dx,
            next_dy,
            options.use_ascii,
          ),
        })
      }
    }

    if !options.use_ascii {
      match first_drawn {
        Some(first) =>
          if first_dir_x == 0 && first_dir_y < 0 {
            box_start_overlays.push({
              x: first.x,
              y: first.y + 1,
              marker: "┴",
            })
          } else if first_dir_x == 0 && first_dir_y > 0 {
            box_start_overlays.push({
              x: first.x,
              y: first.y - 1,
              marker: "┬",
            })
          } else if first_dir_x < 0 && first_dir_y == 0 {
            box_start_overlays.push({
              x: first.x + 1,
              y: first.y,
              marker: "┤",
            })
          } else if first_dir_x > 0 && first_dir_y == 0 {
            box_start_overlays.push({
              x: first.x - 1,
              y: first.y,
              marker: "├",
            })
          } else {
            ()
          }
        None => ()
      }
    }

    let show_arrow_end = if state_layout_mode {
      layout.edge.has_arrow_end
    } else {
      true
    }
    if show_arrow_end {
      match last_drawn {
        Some(last) =>
          arrow_overlays.push({
            x: last.x,
            y: last.y,
            marker: flow_arrow_marker(last_dir_x, last_dir_y, options.use_ascii),
          })
        None => ()
      }
    }

    if state_layout_mode && layout.edge.has_arrow_start {
      match first_drawn {
        Some(first) =>
          arrow_overlays.push({
            x: first.x,
            y: first.y,
            marker: flow_arrow_marker(
              -first_dir_x,
              -first_dir_y,
              options.use_ascii,
            ),
          })
        None => ()
      }
    }

    if layout.label_line.length() == 2 {
      match layout.edge.label {
        Some(label) => {
          let (line_x1, line_y1) = state_ascii_grid_to_draw(
            column_width,
            row_height,
            layout.label_line[0],
          )
          let (line_x2, line_y2) = state_ascii_grid_to_draw(
            column_width,
            row_height,
            layout.label_line[1],
          )
          let anchor_x = line_x1.min(line_x2) +
            (line_x1.max(line_x2) - line_x1.min(line_x2)) / 2 +
            shift_x
          let anchor_y = line_y1.min(line_y2) +
            (line_y1.max(line_y2) - line_y1.min(line_y2)) / 2 +
            shift_y
          let label_x = anchor_x - label.length() / 2
          edge_label_overlays.push({ x: label_x, y: anchor_y, label })
        }
        None => ()
      }
    }
  }

  for corner in corner_overlays {
    if options.use_ascii {
      put_canvas(canvas, corner.x, corner.y, corner.marker)
      continue
    }
    if corner.x < 0 ||
      corner.y < 0 ||
      corner.y >= canvas.length() ||
      corner.x >= canvas[corner.y].length() {
      continue
    }
    let existing = canvas[corner.y][corner.x]
    let has_left = corner.x > 0 &&
      flow_connects_right(canvas[corner.y][corner.x - 1])
    let has_right = corner.x + 1 < canvas[corner.y].length() &&
      flow_connects_left(canvas[corner.y][corner.x + 1])
    let has_up = corner.y > 0 &&
      flow_connects_down(canvas[corner.y - 1][corner.x])
    let has_down = corner.y + 1 < canvas.length() &&
      flow_connects_up(canvas[corner.y + 1][corner.x])
    put_canvas(
      canvas,
      corner.x,
      corner.y,
      flow_unicode_char_for_connections(
        existing, has_left, has_right, has_up, has_down,
      ),
    )
  }
  for arrow in arrow_overlays {
    put_canvas(canvas, arrow.x, arrow.y, arrow.marker)
  }
  for box_start in box_start_overlays {
    put_canvas(canvas, box_start.x, box_start.y, box_start.marker)
  }
  for placement in edge_label_overlays {
    write_canvas_text(canvas, placement.x, placement.y, placement.label)
  }
  for group in shifted_groups {
    flow_draw_group_labels(canvas, group)
  }

  trim_flow_canvas_output(flow_canvas_to_output(canvas))
}

///|
fn render_ascii_flow_subgraphs(
  graph : MermaidGraph,
  positioned : PositionedGraph,
  options : AsciiRenderOptions,
) -> String {
  let flow_direction_horizontal = graph.direction is (LR | RL)
  let state_graph_mode = graph_has_shape(graph, StateStart) ||
    graph_has_shape(graph, StateEnd)
  let state_layout_mode = state_graph_mode && !flow_direction_horizontal
  let horizontal_state_flow_mode = state_graph_mode && flow_direction_horizontal
  let state_flat_layout_mode = state_layout_mode &&
    graph.subgraphs.length() == 0
  let state_composite_layout_mode = state_layout_mode && !state_flat_layout_mode
  let flow_with_subgraphs = !state_layout_mode && graph.subgraphs.length() > 0
  let flow_has_labeled_edges = if state_layout_mode {
    false
  } else {
    graph.edges.any(edge => edge.label is Some(_))
  }
  let flow_vertical_min_node_width = if !flow_direction_horizontal &&
    flow_has_labeled_edges {
    7
  } else {
    5
  }
  let scale_x = if state_layout_mode { 9 } else { flow_scale_x() }
  let scale_y = if state_layout_mode { 10 } else { flow_scale_y() }
  let column_width_by_x : Map[Int, Int] = {}
  for node in positioned.nodes {
    let label = flow_node_label(node)
    let column_key = if !state_layout_mode && flow_direction_horizontal {
      node.x - node.width / 2
    } else {
      node.x
    }
    let base_width = if state_layout_mode {
      match node.shape {
        StateStart | StateEnd => if flow_direction_horizontal { 4 } else { 12 }
        _ =>
          if flow_direction_horizontal {
            (label.length() + 4).max(5)
          } else {
            (label.length() + 4).max(12)
          }
      }
    } else if flow_direction_horizontal && !flow_with_subgraphs {
      if horizontal_state_flow_mode && node.shape is (StateStart | StateEnd) {
        4
      } else {
        (label.length() + 4).max(5)
      }
    } else {
      (label.length() + 4).max(flow_vertical_min_node_width)
    }
    let current = option_int_or(column_width_by_x.get(column_key), 0)
    if base_width > current {
      column_width_by_x[column_key] = base_width
    }
  }

  let mapped_nodes : Array[AsciiFlowNodeBox] = []
  let node_column_key_by_id : Map[String, Int] = {}
  let flow_horizontal_subgraph_node_inset = if !state_layout_mode &&
    flow_with_subgraphs &&
    flow_direction_horizontal {
    1
  } else {
    0
  }
  let flow_horizontal_subgraph_node_vshift = if !state_layout_mode &&
    flow_with_subgraphs &&
    flow_direction_horizontal {
    1
  } else {
    0
  }
  for node in positioned.nodes {
    let label = flow_node_label(node)
    let column_key = if !state_layout_mode && flow_direction_horizontal {
      node.x - node.width / 2
    } else {
      node.x
    }
    node_column_key_by_id[node.id] = column_key
    let (min_width, min_height) = if state_layout_mode {
      let state_min_width = match node.shape {
        StateStart | StateEnd => if flow_direction_horizontal { 4 } else { 12 }
        _ =>
          if flow_direction_horizontal {
            (label.length() + 4).max(5)
          } else {
            12
          }
      }
      (option_int_or(column_width_by_x.get(column_key), state_min_width), 5)
    } else {
      let fallback_width = if flow_direction_horizontal && !flow_with_subgraphs {
        if horizontal_state_flow_mode && node.shape is (StateStart | StateEnd) {
          4
        } else {
          (label.length() + 4).max(5)
        }
      } else {
        (label.length() + 4).max(flow_vertical_min_node_width)
      }
      (option_int_or(column_width_by_x.get(column_key), fallback_width), 5)
    }
    let horizontal_state_pseudostate = horizontal_state_flow_mode &&
      node.shape is (StateStart | StateEnd)
    let width = if horizontal_state_pseudostate {
      4
    } else if state_layout_mode {
      scale_size(node.width, scale_x, min_width)
    } else {
      min_width
    }
    let height = if state_layout_mode {
      scale_size(node.height, scale_y, min_height).max(min_height)
    } else {
      min_height
    }
    let cx = scale_coord(node.x, scale_x, options.padding_x)
    let cy = scale_coord(node.y, scale_y, options.padding_y)
    let box = AsciiFlowNodeBox::{
      id: node.id,
      label,
      left: cx - width / 2 + flow_horizontal_subgraph_node_inset,
      top: cy - height / 2 - flow_horizontal_subgraph_node_vshift,
      width,
      height,
    }
    mapped_nodes.push(box)
  }
  let flow_out_degree_by_source : Map[String, Int] = {}
  let flow_in_degree_by_target : Map[String, Int] = {}
  if !state_layout_mode && flow_direction_horizontal && !flow_with_subgraphs {
    for edge in graph.edges {
      let source_current = option_int_or(
        flow_out_degree_by_source.get(edge.source),
        0,
      )
      flow_out_degree_by_source[edge.source] = source_current + 1
      let target_current = option_int_or(
        flow_in_degree_by_target.get(edge.target),
        0,
      )
      flow_in_degree_by_target[edge.target] = target_current + 1
    }
  }

  let horizontal_label_gap_by_pair : Map[String, Int] = {}
  if !state_layout_mode && flow_direction_horizontal {
    for edge in graph.edges {
      match edge.label {
        Some(label) => {
          let pair_key = flow_node_pair_key(edge.source, edge.target)
          let current_gap = option_int_or(
            horizontal_label_gap_by_pair.get(pair_key),
            options.padding_x,
          )
          let required_gap = (label.length() + 2).max(options.padding_x)
          if required_gap > current_gap {
            horizontal_label_gap_by_pair[pair_key] = required_gap
          }
        }
        None =>
          if !flow_with_subgraphs && !horizontal_state_flow_mode {
            let target_in_degree = option_int_or(
              flow_in_degree_by_target.get(edge.target),
              0,
            )
            let target_out_degree = option_int_or(
              flow_out_degree_by_source.get(edge.target),
              0,
            )
            if target_in_degree > 1 && target_out_degree <= 1 {
              let pair_key = flow_node_pair_key(edge.source, edge.target)
              let current_gap = option_int_or(
                horizontal_label_gap_by_pair.get(pair_key),
                options.padding_x,
              )
              let required_gap = options.padding_x
              if required_gap > current_gap {
                horizontal_label_gap_by_pair[pair_key] = required_gap
              }
            }
          }
      }
    }
  }

  let node_top_level_group_by_id : Map[String, String] = {}
  if flow_with_subgraphs {
    for subgraph in graph.subgraphs {
      flow_collect_node_top_level_group_ids(
        subgraph,
        subgraph.id,
        node_top_level_group_by_id,
      )
    }
  }
  if flow_with_subgraphs && flow_direction_horizontal {
    let node_has_indirect_ancestor : Map[String, Bool] = {}
    flow_collect_node_has_indirect_ancestor(
      graph.subgraphs,
      false,
      node_has_indirect_ancestor,
    )
    for i, node in mapped_nodes {
      match node_has_indirect_ancestor.get(node.id) {
        Some(true) =>
          mapped_nodes[i] = {
            id: node.id,
            label: node.label,
            left: node.left,
            top: node.top + 1,
            width: node.width,
            height: node.height,
          }
        _ => ()
      }
    }
  }

  if !state_layout_mode {
    let row_indexes_by_center_y : Map[Int, Array[Int]] = {}
    for i, node in mapped_nodes {
      let center_y = node.top + node.height / 2
      if !row_indexes_by_center_y.contains(center_y) {
        row_indexes_by_center_y[center_y] = []
      }
      row_indexes_by_center_y[center_y].push(i)
    }

    for _, row_indexes in row_indexes_by_center_y {
      for i in 1..<row_indexes.length() {
        let mut j = i
        while j > 0 {
          let left_curr = mapped_nodes[row_indexes[j]].left
          let left_prev = mapped_nodes[row_indexes[j - 1]].left
          if left_prev <= left_curr {
            break
          }
          let temp = row_indexes[j - 1]
          row_indexes[j - 1] = row_indexes[j]
          row_indexes[j] = temp
          j = j - 1
        }
      }

      for i in 1..<row_indexes.length() {
        let prev_idx = row_indexes[i - 1]
        let curr_idx = row_indexes[i]
        let prev_node = mapped_nodes[prev_idx]
        let curr_node = mapped_nodes[curr_idx]
        let gap = option_int_or(
          horizontal_label_gap_by_pair.get(
            flow_node_pair_key(prev_node.id, curr_node.id),
          ),
          options.padding_x,
        )
        let desired_left = prev_node.left + prev_node.width + gap
        if curr_node.left != desired_left {
          mapped_nodes[curr_idx] = {
            id: curr_node.id,
            label: curr_node.label,
            left: desired_left,
            top: curr_node.top,
            width: curr_node.width,
            height: curr_node.height,
          }
        }
      }
    }
  }

  if !state_layout_mode && flow_direction_horizontal {
    let canonical_left_by_key : Map[Int, Int] = {}
    for node in mapped_nodes {
      let key = option_int_or(node_column_key_by_id.get(node.id), node.left)
      if !canonical_left_by_key.contains(key) {
        canonical_left_by_key[key] = node.left
      } else {
        let current_left = option_int_or(
          canonical_left_by_key.get(key),
          node.left,
        )
        if node.left < current_left {
          canonical_left_by_key[key] = node.left
        }
      }
    }
    for i, node in mapped_nodes {
      let key = option_int_or(node_column_key_by_id.get(node.id), node.left)
      let canonical_left = option_int_or(
        canonical_left_by_key.get(key),
        node.left,
      )
      if node.left != canonical_left {
        mapped_nodes[i] = {
          id: node.id,
          label: node.label,
          left: canonical_left,
          top: node.top,
          width: node.width,
          height: node.height,
        }
      }
    }
  }

  let node_box_by_id : Map[String, AsciiFlowNodeBox] = {}
  for box in mapped_nodes {
    node_box_by_id[box.id] = box
  }

  let mapped_groups : Array[AsciiFlowGroupBox] = if state_composite_layout_mode {
    state_mapped_groups_from_nodes(graph, node_box_by_id)
  } else {
    let groups : Array[AsciiFlowGroupBox] = []
    for group in positioned.groups {
      groups.push(
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
    groups
  }
  let flow_has_subgraph_direction_override = graph.subgraphs.any(subgraph => {
    subgraph.direction is Some(_)
  })
  let mapped_groups = if !state_layout_mode &&
    flow_with_subgraphs &&
    (flow_direction_horizontal || !flow_has_subgraph_direction_override) {
    let padded_groups : Array[AsciiFlowGroupBox] = []
    for group in mapped_groups {
      let member_nodes : Array[AsciiFlowNodeBox] = []
      for node in mapped_nodes {
        match node_top_level_group_by_id.get(node.id) {
          Some(top_level_group_id) =>
            if top_level_group_id == group.id {
              member_nodes.push(node)
            }
          None => ()
        }
      }
      padded_groups.push(
        flow_expand_group_side_padding_for_nodes(group, member_nodes, false),
      )
    }
    padded_groups
  } else {
    mapped_groups
  }
  let top_level_group_shift_by_id : Map[String, Int] = if !state_layout_mode &&
    flow_with_subgraphs &&
    flow_direction_horizontal {
    flow_lr_top_level_group_shifts(mapped_groups)
  } else {
    {}
  }
  let mapped_groups = if top_level_group_shift_by_id.length() > 0 {
    let shifted_groups : Array[AsciiFlowGroupBox] = []
    for group in mapped_groups {
      let shift_x = option_int_or(top_level_group_shift_by_id.get(group.id), 0)
      shifted_groups.push(shift_ascii_flow_group(group, shift_x, 0))
    }
    shifted_groups
  } else {
    mapped_groups
  }
  let subgraph_has_content : Map[String, Bool] = {}
  flow_collect_subgraph_content_flags(graph.subgraphs, subgraph_has_content)
  let mapped_groups = flow_filter_groups_by_subgraph_content(
    mapped_groups, subgraph_has_content,
  )
  let top_level_group_by_id : Map[String, AsciiFlowGroupBox] = {}
  for group in mapped_groups {
    top_level_group_by_id[group.id] = group
  }
  if top_level_group_shift_by_id.length() > 0 ||
    (flow_with_subgraphs && flow_direction_horizontal) {
    for i, node in mapped_nodes {
      match node_top_level_group_by_id.get(node.id) {
        Some(top_level_group_id) => {
          let shift_x = if top_level_group_shift_by_id.length() > 0 {
            option_int_or(
              top_level_group_shift_by_id.get(top_level_group_id),
              0,
            )
          } else {
            0
          }
          let mut adjusted_left = node.left + shift_x
          if flow_with_subgraphs && flow_direction_horizontal {
            match top_level_group_by_id.get(top_level_group_id) {
              Some(top_level_group) => {
                let min_left = top_level_group.left + 2
                if adjusted_left < min_left {
                  adjusted_left = min_left
                }
              }
              None => ()
            }
          }
          if adjusted_left != node.left {
            mapped_nodes[i] = {
              id: node.id,
              label: node.label,
              left: adjusted_left,
              top: node.top,
              width: node.width,
              height: node.height,
            }
          }
        }
        None => ()
      }
    }
    for box in mapped_nodes {
      node_box_by_id[box.id] = box
    }
  }
  let mapped_groups = if !state_layout_mode &&
    flow_with_subgraphs &&
    (flow_direction_horizontal || !flow_has_subgraph_direction_override) {
    let adjusted_groups : Array[AsciiFlowGroupBox] = []
    for group in mapped_groups {
      let member_nodes : Array[AsciiFlowNodeBox] = []
      for node in mapped_nodes {
        match node_top_level_group_by_id.get(node.id) {
          Some(top_level_group_id) =>
            if top_level_group_id == group.id {
              member_nodes.push(node)
            }
          None => ()
        }
      }
      adjusted_groups.push(
        flow_expand_group_side_padding_for_nodes(group, member_nodes, false),
      )
    }
    adjusted_groups
  } else {
    mapped_groups
  }
  let post_compaction_group_shift_by_id : Map[String, Int] = if !state_layout_mode &&
    flow_with_subgraphs &&
    flow_direction_horizontal {
    flow_lr_top_level_group_shifts(mapped_groups)
  } else {
    {}
  }
  let mapped_groups = if post_compaction_group_shift_by_id.length() > 0 {
    let shifted_groups : Array[AsciiFlowGroupBox] = []
    for group in mapped_groups {
      let shift_x = option_int_or(
        post_compaction_group_shift_by_id.get(group.id),
        0,
      )
      shifted_groups.push(shift_ascii_flow_group(group, shift_x, 0))
    }
    shifted_groups
  } else {
    mapped_groups
  }
  if post_compaction_group_shift_by_id.length() > 0 {
    for i, node in mapped_nodes {
      match node_top_level_group_by_id.get(node.id) {
        Some(top_level_group_id) => {
          let shift_x = option_int_or(
            post_compaction_group_shift_by_id.get(top_level_group_id),
            0,
          )
          if shift_x != 0 {
            mapped_nodes[i] = {
              id: node.id,
              label: node.label,
              left: node.left + shift_x,
              top: node.top,
              width: node.width,
              height: node.height,
            }
          }
        }
        None => ()
      }
    }
    for box in mapped_nodes {
      node_box_by_id[box.id] = box
    }
  }
  let subgraph_has_direct_nodes : Map[String, Bool] = {}
  flow_collect_subgraph_has_direct_nodes(
    graph.subgraphs,
    subgraph_has_direct_nodes,
  )
  let mapped_groups = if !state_layout_mode &&
    flow_with_subgraphs &&
    flow_direction_horizontal {
    let adjusted_groups : Array[AsciiFlowGroupBox] = []
    for group in mapped_groups {
      adjusted_groups.push(
        flow_expand_indirect_nested_group_bottom_padding(
          group, subgraph_has_direct_nodes,
        ),
      )
    }
    adjusted_groups
  } else {
    mapped_groups
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

  for group in mapped_groups {
    flow_draw_group(canvas, group, options.use_ascii)
  }

  let arrow_overlays : Array[AsciiArrowPlacement] = []
  let border_overlays : Array[AsciiArrowPlacement] = []
  let edge_label_overlays : Array[AsciiEdgeLabelPlacement] = []
  let blocked_cells : Map[String, Bool] = {}
  if state_flat_layout_mode ||
    (!state_layout_mode && flow_with_subgraphs && !flow_direction_horizontal) {
    flow_mark_blocked_cells_for_nodes(blocked_cells, mapped_nodes)
  }
  let canvas_height = canvas.length()
  let canvas_width = if canvas_height == 0 { 0 } else { canvas[0].length() }
  let non_state_out_degree_by_source : Map[String, Int] = {}
  let non_state_in_degree_by_target : Map[String, Int] = {}
  let non_state_has_labeled_incoming_target : Map[String, Bool] = {}
  if !state_layout_mode {
    for edge in graph.edges {
      let current = option_int_or(
        non_state_out_degree_by_source.get(edge.source),
        0,
      )
      non_state_out_degree_by_source[edge.source] = current + 1
      let target_current = option_int_or(
        non_state_in_degree_by_target.get(edge.target),
        0,
      )
      non_state_in_degree_by_target[edge.target] = target_current + 1
      if edge.label is Some(_) {
        non_state_has_labeled_incoming_target[edge.target] = true
      }
    }
  }
  for edge in positioned.edges {
    let line_style = if state_layout_mode { edge.style } else { Solid }
    let (h_char, v_char) = flow_line_chars(line_style, options.use_ascii)
    let mut first_x = 0
    let mut first_y = 0
    let mut end_x = 0
    let mut end_y = 0
    let mut start_dx = 0
    let mut start_dy = 0
    let mut end_dx = 0
    let mut end_dy = 0
    let mut source_anchor_x = 0
    let mut source_anchor_y = 0
    let mut target_anchor_x = 0
    let mut target_anchor_y = 0
    let mut non_state_route_points : Array[Point] = []
    let mut merge_primary_join_x = -1
    let mut merge_secondary_edge = false

    if state_layout_mode {
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
      first_x = scale_coord(first.x, scale_x, options.padding_x)
      first_y = scale_coord(first.y, scale_y, options.padding_y)
      let next_x = scale_coord(next.x, scale_x, options.padding_x)
      let next_y = scale_coord(next.y, scale_y, options.padding_y)
      start_dx = next_x - first_x
      start_dy = next_y - first_y
      let source_anchor = match node_box_by_id.get(edge.source) {
        Some(source_box) =>
          flow_edge_anchor(source_box, start_dx, start_dy, false)
        None => (first_x, first_y)
      }
      let (sx, sy) = source_anchor
      source_anchor_x = sx
      source_anchor_y = sy

      let last = points[points.length() - 1]
      let prev = points[points.length() - 2]
      end_x = scale_coord(last.x, scale_x, options.padding_x)
      end_y = scale_coord(last.y, scale_y, options.padding_y)
      let prev_x = scale_coord(prev.x, scale_x, options.padding_x)
      let prev_y = scale_coord(prev.y, scale_y, options.padding_y)
      end_dx = end_x - prev_x
      end_dy = end_y - prev_y
      let target_anchor = match node_box_by_id.get(edge.target) {
        Some(target_box) => flow_edge_anchor(target_box, end_dx, end_dy, true)
        None => (end_x, end_y)
      }
      let (tx, ty) = target_anchor
      target_anchor_x = tx
      target_anchor_y = ty
    } else {
      match (node_box_by_id.get(edge.source), node_box_by_id.get(edge.target)) {
        (Some(source_box), Some(target_box)) =>
          if edge.source == edge.target {
            source_anchor_x = source_box.left + source_box.width - 1
            source_anchor_y = source_box.top + source_box.height / 2
            target_anchor_x = source_box.left + 2
            target_anchor_y = source_box.top + source_box.height - 1
            let source_total_out = option_int_or(
              non_state_out_degree_by_source.get(edge.source),
              0,
            )
            let loop_extra = if source_total_out > 1 { 3 } else { 2 }
            let loop_right_x = source_anchor_x + loop_extra
            let loop_bottom_y = target_anchor_y + 2
            let route_points = [
              Point::{ x: source_anchor_x, y: source_anchor_y },
              { x: loop_right_x, y: source_anchor_y },
              { x: loop_right_x, y: loop_bottom_y },
              { x: target_anchor_x, y: loop_bottom_y },
              { x: target_anchor_x, y: target_anchor_y },
            ]
            non_state_route_points = route_points
            for i in 1..<non_state_route_points.length() {
              let from = non_state_route_points[i - 1]
              let to = non_state_route_points[i]
              flow_draw_segment(
                canvas,
                from.x,
                from.y,
                to.x,
                to.y,
                h_char,
                v_char,
              )
            }
            if options.use_ascii {
              flow_mark_ascii_route_bends(canvas, non_state_route_points)
            }
            let first_point = non_state_route_points[0]
            let next_point = non_state_route_points[1]
            let last_point = non_state_route_points[non_state_route_points.length() -
              1]
            let prev_point = non_state_route_points[non_state_route_points.length() -
              2]
            first_x = first_point.x
            first_y = first_point.y
            end_x = last_point.x
            end_y = last_point.y
            start_dx = next_point.x - first_point.x
            start_dy = next_point.y - first_point.y
            end_dx = last_point.x - prev_point.x
            end_dy = last_point.y - prev_point.y
          } else {
            let source_center_x = source_box.left + source_box.width / 2
            let source_center_y = source_box.top + source_box.height / 2
            let target_center_x = target_box.left + target_box.width / 2
            let target_center_y = target_box.top + target_box.height / 2
            let center_dx = target_center_x - source_center_x
            let center_dy = target_center_y - source_center_y
            let source_out_degree = option_int_or(
              non_state_out_degree_by_source.get(edge.source),
              0,
            )
            let target_in_degree = option_int_or(
              non_state_in_degree_by_target.get(edge.target),
              0,
            )
            let merge_target = false
            let merge_primary_edge = merge_target && center_dy == 0
            merge_secondary_edge = merge_target && center_dy != 0
            if merge_primary_edge {
              merge_primary_join_x = target_box.left - 3
            }
            let horizontal_first = if flow_direction_horizontal {
              if horizontal_state_flow_mode && center_dx != 0 && center_dy < 0 {
                true
              } else if !flow_with_subgraphs &&
                center_dy > 0 &&
                center_dx > 0 &&
                (source_out_degree > 1 || target_in_degree > 1) {
                false
              } else {
                !(flow_with_subgraphs && source_out_degree > 1)
              }
            } else {
              source_out_degree > 1
            }
            let mut source_dir_dx = center_dx
            let mut source_dir_dy = center_dy
            let mut target_dir_dx = center_dx
            let mut target_dir_dy = center_dy
            if center_dx != 0 && center_dy != 0 {
              if horizontal_first {
                source_dir_dy = 0
                target_dir_dx = 0
              } else {
                source_dir_dx = 0
                target_dir_dy = 0
              }
            }
            let labeled_back_edge_detour = flow_direction_horizontal &&
              center_dx < 0 &&
              (center_dy.abs() <= source_box.height || center_dy < 0) &&
              edge.label is Some(_)
            let unlabeled_back_edge_detour = flow_direction_horizontal &&
              !flow_with_subgraphs &&
              center_dx < 0 &&
              center_dy == 0 &&
              edge.label is None
            let labeled_left_descending_detour = flow_direction_horizontal &&
              center_dx < 0 &&
              center_dy > 0 &&
              source_out_degree > 1 &&
              edge.label is Some(_)
            let route_points = if labeled_back_edge_detour {
              let (sx, sy) = flow_edge_anchor(source_box, 0, 1, false)
              let (tx, ty) = flow_edge_anchor(target_box, 0, -1, true)
              let shared_source_x = if source_out_degree > 1 {
                (source_box.left - 3).max(target_box.left + 1)
              } else {
                sx
              }
              source_anchor_x = shared_source_x
              source_anchor_y = sy
              target_anchor_x = tx
              target_anchor_y = ty
              let detour_start_y = if center_dy < 0 {
                target_anchor_y + 3
              } else {
                source_anchor_y.max(target_anchor_y) + 3
              }
              let detour_y = flow_non_state_back_edge_detour_row(
                edge.source,
                edge.target,
                source_anchor_x,
                target_anchor_x,
                detour_start_y,
                mapped_nodes,
              )
              [
                Point::{ x: source_anchor_x, y: source_anchor_y },
                { x: source_anchor_x, y: detour_y },
                { x: target_anchor_x, y: detour_y },
                { x: target_anchor_x, y: target_anchor_y },
              ]
            } else if unlabeled_back_edge_detour {
              let (sx, sy) = flow_edge_anchor(source_box, 0, 1, false)
              let (tx, ty) = flow_edge_anchor(target_box, 0, -1, true)
              source_anchor_x = sx
              source_anchor_y = sy
              target_anchor_x = tx
              target_anchor_y = ty
              let detour_start_y = source_anchor_y.max(target_anchor_y) + 2
              let detour_y = flow_non_state_back_edge_detour_row(
                edge.source,
                edge.target,
                source_anchor_x,
                target_anchor_x,
                detour_start_y,
                mapped_nodes,
              )
              [
                { x: source_anchor_x, y: source_anchor_y },
                { x: source_anchor_x, y: detour_y },
                { x: target_anchor_x, y: detour_y },
                { x: target_anchor_x, y: target_anchor_y },
              ]
            } else if labeled_left_descending_detour {
              let (sx, sy) = flow_edge_anchor(source_box, center_dx, 0, false)
              let (tx, ty) = flow_edge_anchor(target_box, 0, center_dy, true)
              source_anchor_x = sx
              source_anchor_y = sy
              target_anchor_x = tx
              target_anchor_y = ty
              let shared_source_x = (source_box.left - 3).max(
                target_anchor_x + 1,
              )
              let bend_y = (source_anchor_y + target_anchor_y) / 2 + 1
              flow_compact_route_points([
                { x: source_anchor_x, y: source_anchor_y },
                { x: shared_source_x, y: source_anchor_y },
                { x: shared_source_x, y: bend_y },
                { x: target_anchor_x, y: bend_y },
                { x: target_anchor_x, y: target_anchor_y },
              ])
            } else if merge_primary_edge {
              let source_anchor = flow_edge_anchor(
                source_box, source_dir_dx, source_dir_dy, false,
              )
              let (sx, sy) = source_anchor
              source_anchor_x = sx
              source_anchor_y = sy
              let join_x = target_box.left - 3
              target_anchor_y = target_box.top + target_box.height / 2
              target_anchor_x = target_box.left
              [
                { x: source_anchor_x, y: source_anchor_y },
                { x: join_x, y: target_anchor_y },
                { x: target_anchor_x, y: target_anchor_y },
              ]
            } else if merge_secondary_edge {
              let source_anchor = flow_edge_anchor(
                source_box, source_dir_dx, source_dir_dy, false,
              )
              let (sx, sy) = source_anchor
              source_anchor_x = sx
              source_anchor_y = sy
              target_anchor_y = target_box.top + target_box.height / 2
              target_anchor_x = (target_box.left - 3).max(source_anchor_x + 1)
              if source_anchor_y > target_anchor_y {
                let bend_y = (source_anchor_y + target_anchor_y) / 2 + 1
                flow_compact_route_points([
                  { x: source_anchor_x, y: source_anchor_y },
                  { x: source_anchor_x, y: bend_y },
                  { x: target_anchor_x, y: bend_y },
                  { x: target_anchor_x, y: target_anchor_y },
                ])
              } else {
                let secondary_horizontal_first = source_anchor_y <
                  target_anchor_y
                flow_non_state_route_points(
                  source_anchor_x, source_anchor_y, target_anchor_x, target_anchor_y,
                  secondary_horizontal_first,
                )
              }
            } else {
              let source_anchor = flow_edge_anchor(
                source_box, source_dir_dx, source_dir_dy, false,
              )
              let target_anchor = flow_edge_anchor(
                target_box, target_dir_dx, target_dir_dy, true,
              )
              let (sx, sy) = source_anchor
              let (tx, ty) = target_anchor
              source_anchor_x = sx
              source_anchor_y = sy
              target_anchor_x = tx
              target_anchor_y = ty
              let fallback_route_points = flow_non_state_route_points(
                source_anchor_x, source_anchor_y, target_anchor_x, target_anchor_y,
                horizontal_first,
              )
              let shared_back_route = if flow_with_subgraphs &&
                !flow_direction_horizontal &&
                center_dx < 0 &&
                center_dy.abs() <= source_box.height &&
                edge.label is None {
                flow_non_state_shared_back_edge_route_points(
                  edge.source,
                  edge.target,
                  source_anchor_x,
                  source_anchor_y,
                  source_box.height,
                  target_anchor_x,
                  target_anchor_y,
                  source_out_degree,
                  graph.edges,
                  node_box_by_id,
                )
              } else {
                None
              }
              match shared_back_route {
                Some(route_points) => route_points
                None =>
                  if flow_with_subgraphs &&
                    !flow_direction_horizontal &&
                    flow_non_state_route_hits_blocked_cells(
                      fallback_route_points, blocked_cells,
                    ) {
                    flow_non_state_route_points_with_pathfinder(
                      source_anchor_x, source_anchor_y, target_anchor_x, target_anchor_y,
                      horizontal_first, blocked_cells, canvas_width, canvas_height,
                    )
                  } else {
                    fallback_route_points
                  }
              }
            }
            non_state_route_points = route_points
            for i in 1..<non_state_route_points.length() {
              let from = non_state_route_points[i - 1]
              let to = non_state_route_points[i]
              flow_draw_segment(
                canvas,
                from.x,
                from.y,
                to.x,
                to.y,
                h_char,
                v_char,
              )
            }
            if options.use_ascii {
              if flow_with_subgraphs && !flow_direction_horizontal {
                flow_mark_ascii_route_bends(canvas, non_state_route_points)
              } else if !flow_with_subgraphs &&
                flow_direction_horizontal &&
                center_dx < 0 &&
                non_state_route_points.length() >= 4 {
                flow_mark_ascii_route_bends(canvas, non_state_route_points)
              } else if non_state_route_points.length() == 3 {
                let bend = non_state_route_points[1]
                put_canvas(canvas, bend.x, bend.y, "+")
              }
              if !flow_with_subgraphs &&
                flow_direction_horizontal &&
                edge.label is Some(_) {
                flow_mark_ascii_route_intersections(
                  canvas, non_state_route_points,
                )
              }
            }
            let first_point = non_state_route_points[0]
            let next_point = non_state_route_points[1]
            let last_point = non_state_route_points[non_state_route_points.length() -
              1]
            let prev_point = non_state_route_points[non_state_route_points.length() -
              2]
            first_x = first_point.x
            first_y = first_point.y
            end_x = last_point.x
            end_y = last_point.y
            start_dx = next_point.x - first_point.x
            start_dy = next_point.y - first_point.y
            end_dx = last_point.x - prev_point.x
            end_dy = last_point.y - prev_point.y
          }
        _ => continue
      }
    }

    match border_join_marker(start_dx, start_dy, false, options.use_ascii) {
      Some(marker) =>
        border_overlays.push({ x: source_anchor_x, y: source_anchor_y, marker })
      None => ()
    }
    match edge.label {
      Some(label) =>
        if state_layout_mode {
          let mut has_labeled_reverse_shared_path = false
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
          let base_y = adjust_label_y_for_state_boxes(
            label_x, anchor_y, label, mapped_nodes,
          )
          let label_y = if has_labeled_reverse_shared_path {
            base_y
          } else {
            adjust_label_y_for_state_layout(
              label_x, base_y, label, mapped_nodes, edge_label_overlays,
            )
          }
          edge_label_overlays.push({ x: label_x, y: label_y, label })
        } else {
          let route_points = if non_state_route_points.length() >= 2 {
            non_state_route_points
          } else {
            flow_non_state_route_points(
              source_anchor_x, source_anchor_y, target_anchor_x, target_anchor_y,
              flow_direction_horizontal,
            )
          }
          let back_edge_detour = flow_direction_horizontal &&
            route_points.length() == 4 &&
            route_points[0].x == route_points[1].x &&
            route_points[1].y == route_points[2].y &&
            route_points[2].x == route_points[3].x &&
            route_points[0].x > route_points[3].x
          let upward_back_edge_detour = back_edge_detour &&
            route_points[0].y > route_points[3].y
          if !upward_back_edge_detour {
            edge_label_overlays.push(
              flow_non_state_edge_label_placement(
                route_points, source_anchor_x, source_anchor_y, target_anchor_x,
                target_anchor_y, label, mapped_nodes, edge_label_overlays,
              ),
            )
          }
        }
      None => ()
    }

    let show_arrow_end = (edge.has_arrow_end || !state_layout_mode) &&
      !merge_secondary_edge
    if show_arrow_end {
      let dx = end_dx
      let dy = end_dy
      let mut arrow_x = target_anchor_x - unit_step(dx)
      let arrow_y = target_anchor_y - unit_step(dy)
      if state_layout_mode && options.use_ascii && dx < 0 && dy == 0 {
        arrow_x = target_anchor_x + 3
        for gap_x in (target_anchor_x + 1)..<arrow_x {
          arrow_overlays.push({ x: gap_x, y: target_anchor_y, marker: " " })
        }
      }
      arrow_overlays.push({
        x: arrow_x,
        y: arrow_y,
        marker: flow_arrow_marker(dx, dy, options.use_ascii),
      })
    }
    if merge_primary_join_x >= 0 {
      let marker = if options.use_ascii { "+" } else { "┬" }
      arrow_overlays.push({
        x: merge_primary_join_x,
        y: target_anchor_y,
        marker,
      })
    }
    if state_layout_mode && edge.has_arrow_start {
      let dx = -start_dx
      let dy = -start_dy
      arrow_overlays.push({
        x: source_anchor_x + unit_step(dx),
        y: source_anchor_y + unit_step(dy),
        marker: flow_arrow_marker(dx, dy, options.use_ascii),
      })
    }
  }

  if !options.use_ascii {
    flow_normalize_unicode_junctions(canvas)
    flow_refine_unicode_side_tees(canvas)
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
    if options.use_ascii {
      put_canvas(canvas, join.x, join.y, join.marker)
    } else {
      flow_put_unicode_border_join(canvas, join.x, join.y)
    }
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
fn render_ascii_plan(
  plan : @renderer_ascii_layout_plan.AsciiLayoutPlan,
  options : AsciiRenderOptions,
) -> String {
  let graph = plan.graph
  match plan.kind {
    Sequence =>
      match plan.sequence_layout {
        Some(sequence_layout) =>
          render_ascii_sequence(graph, sequence_layout, options)
        None => ""
      }
    Class =>
      match plan.class_layout {
        Some(class_layout) =>
          @renderer_ascii_class_er.render_ascii_class(
            graph, class_layout, options,
          )
        None => ""
      }
    Er =>
      match plan.er_layout {
        Some(er_layout) =>
          @renderer_ascii_class_er.render_ascii_er(graph, er_layout, options)
        None => ""
      }
    StateFlatGrid =>
      match plan.state_flat_grid {
        Some(layout_plan) =>
          render_ascii_state_flat_grid(graph, layout_plan, options)
        None => ""
      }
    FlowSubgraph =>
      match plan.flow_subgraph {
        Some(flow_layout) =>
          render_ascii_flow_subgraphs(graph, flow_layout.positioned, options)
        None => ""
      }
  }
}

///|
/// Renders a mermaid graph as ASCII/Unicode text art.
pub fn render_ascii(
  graph : MermaidGraph,
  options : AsciiRenderOptions,
) -> String {
  let plan = @renderer_ascii_layout_plan.build_plan(graph)
  render_ascii_plan(plan, options)
}
