///|
fn xml_escape(s : String) -> String {
  s
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&#39;")
}

///|
fn style_for_edge(style : EdgeStyle) -> String {
  match style {
    Solid => ""
    Dotted => " stroke-dasharray=\"4 4\""
    Thick => " stroke-width=\"1.5\""
  }
}

///|
fn points_to_svg(points : Array[Point]) -> String {
  points.iter().map(pt => "\{pt.x},\{pt.y}").join(" ")
}

///|
fn edge_needs_curve_path(points : Array[Point]) -> Bool {
  points.length() >= 3
}

///|
fn basis_bezier_segment(
  sb : StringBuilder,
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
) -> Unit {
  let c1x = (2 * x0 + x1) / 3
  let c1y = (2 * y0 + y1) / 3
  let c2x = (x0 + 2 * x1) / 3
  let c2y = (y0 + 2 * y1) / 3
  let ex = (x0 + 4 * x1 + x2) / 6
  let ey = (y0 + 4 * y1 + y2) / 6
  sb.write_string(" C\{c1x} \{c1y} \{c2x} \{c2y} \{ex} \{ey}")
}

///|
fn basis_curve_path(points : Array[Point]) -> String {
  if points.length() < 2 {
    return ""
  }
  let sb = StringBuilder::new()
  let first = points[0]
  sb.write_string("M\{first.x} \{first.y}")
  if points.length() == 2 {
    let last = points[1]
    sb.write_string(" L\{last.x} \{last.y}")
    return sb.to_string()
  }

  let mut x0 = 0
  let mut y0 = 0
  let mut x1 = 0
  let mut y1 = 0
  let mut stage = 0
  for point in points {
    let x = point.x
    let y = point.y
    match stage {
      0 => stage = 1
      1 => stage = 2
      2 => {
        stage = 3
        let lead_x = (5 * x0 + x1) / 6
        let lead_y = (5 * y0 + y1) / 6
        sb.write_string(" L\{lead_x} \{lead_y}")
        basis_bezier_segment(sb, x0, y0, x1, y1, x, y)
      }
      _ => basis_bezier_segment(sb, x0, y0, x1, y1, x, y)
    }
    x0 = x1
    y0 = y1
    x1 = x
    y1 = y
  }
  match stage {
    3 => {
      basis_bezier_segment(sb, x0, y0, x1, y1, x1, y1)
      sb.write_string(" L\{x1} \{y1}")
    }
    2 => sb.write_string(" L\{x1} \{y1}")
    _ => ()
  }
  sb.to_string()
}

///|
fn int_sqrt(value : Int) -> Int {
  if value <= 0 {
    return 0
  }
  let mut left = 1
  let mut right = value
  let mut answer = 0
  while left <= right {
    let mid = (left + right) / 2
    if mid <= value / mid {
      answer = mid
      left = mid + 1
    } else {
      right = mid - 1
    }
  }
  answer
}

///|
fn edge_segment_length(start : Point, end_ : Point) -> Int {
  let dx = end_.x - start.x
  let dy = end_.y - start.y
  int_sqrt(dx * dx + dy * dy)
}

///|
fn edge_midpoint(points : Array[Point]) -> Point? {
  if points.length() == 0 {
    None
  } else if points.length() == 1 {
    Some(points[0])
  } else {
    let mut total = 0
    for i in 1..<points.length() {
      let start = points[i - 1]
      let end_ = points[i]
      total += edge_segment_length(start, end_)
    }
    if total <= 0 {
      return Some(points[points.length() - 1])
    }

    let mut remaining = total / 2
    for i in 1..<points.length() {
      let start = points[i - 1]
      let end_ = points[i]
      let dx = end_.x - start.x
      let dy = end_.y - start.y
      let segment = edge_segment_length(start, end_)
      if segment <= 0 {
        continue
      }
      if remaining <= segment {
        return Some({
          x: start.x + dx * remaining / segment,
          y: start.y + dy * remaining / segment,
        })
      }
      remaining = remaining - segment
    }
    Some(points[points.length() - 1])
  }
}

///|
fn is_uri_unreserved_char(ch : Char) -> Bool {
  ch is ('A'..='Z') ||
  ch is ('a'..='z') ||
  ch is ('0'..='9') ||
  ch == '-' ||
  ch == '_' ||
  ch == '.' ||
  ch == '!' ||
  ch == '~' ||
  ch == '*' ||
  ch.to_int() == 0x27 ||
  ch == '(' ||
  ch == ')'
}

///|
fn percent_hex(byte_value : Int) -> String {
  "%\{byte_value.to_byte().to_hex().to_upper()}"
}

///|
fn font_url_component(font : String) -> String {
  let sb = StringBuilder::new()
  for ch in font {
    if is_uri_unreserved_char(ch) {
      sb.write_char(ch)
      continue
    }
    let code = ch.to_int()
    if code <= 0x7F {
      sb.write_string(percent_hex(code))
      continue
    }
    if code <= 0x7FF {
      sb.write_string(percent_hex(0xC0 | (code >> 6)))
      sb.write_string(percent_hex(0x80 | (code & 0x3F)))
      continue
    }
    if code <= 0xFFFF {
      sb.write_string(percent_hex(0xE0 | (code >> 12)))
      sb.write_string(percent_hex(0x80 | ((code >> 6) & 0x3F)))
      sb.write_string(percent_hex(0x80 | (code & 0x3F)))
      continue
    }
    sb.write_string(percent_hex(0xF0 | (code >> 18)))
    sb.write_string(percent_hex(0x80 | ((code >> 12) & 0x3F)))
    sb.write_string(percent_hex(0x80 | ((code >> 6) & 0x3F)))
    sb.write_string(percent_hex(0x80 | (code & 0x3F)))
  }
  sb.to_string()
}

///|
fn text_svg_with_attrs(
  x : Int,
  y : Int,
  content : String,
  class_name : String,
  extra_attrs : String,
) -> String {
  if content == "" {
    ""
  } else {
    "<text class=\"\{class_name}\" x=\"\{x}\" y=\"\{y}\" text-anchor=\"middle\" dominant-baseline=\"middle\"\{extra_attrs}>\{xml_escape(content)}</text>"
  }
}

///|
fn text_svg(x : Int, y : Int, content : String, class_name : String) -> String {
  text_svg_with_attrs(x, y, content, class_name, "")
}

///|
fn polygon_svg(points : String, class_name : String, attrs : String) -> String {
  "<polygon class=\"\{class_name}\" points=\"\{points}\"\{attrs} />"
}

///|
fn style_value(style : Map[String, String]?, key : String) -> String? {
  match style {
    Some(values) => values.get(key)
    None => None
  }
}

///|
fn attr(name : String, value : String?) -> String {
  match value {
    Some(found) => " \{name}=\"\{xml_escape(found)}\""
    None => ""
  }
}

///|
fn node_shape_attrs(node : PositionedNode) -> String {
  attr("fill", style_value(node.inline_style, "fill")) +
  attr("stroke", style_value(node.inline_style, "stroke")) +
  attr("stroke-width", style_value(node.inline_style, "stroke-width")) +
  attr("stroke-dasharray", style_value(node.inline_style, "stroke-dasharray"))
}

///|
fn node_label_attrs(node : PositionedNode) -> String {
  attr("fill", style_value(node.inline_style, "color"))
}

///|
fn sequence_is_actor_node(node : PositionedNode) -> Bool {
  match style_value(node.inline_style, "__sequence_kind") {
    Some(kind) => kind == "actor"
    None => false
  }
}

///|
fn class_like_lines(node : PositionedNode) -> (String, Array[String]) {
  let lines = node.label.split("\n").map(part => part.to_string()).to_array()
  if lines.length() == 0 {
    (node.label, [])
  } else {
    let rows : Array[String] = []
    for i in 1..<lines.length() {
      rows.push(lines[i])
    }
    (lines[0], rows)
  }
}

///|
fn render_class_like_label(node : PositionedNode) -> String {
  let left = node.x - node.width / 2
  let top = node.y - node.height / 2
  let (header, rows) = class_like_lines(node)
  let header_height = 32
  let row_height = 16
  let sb = StringBuilder::new()
  sb.write_string(
    text_svg_with_attrs(
      node.x,
      top + header_height / 2,
      header,
      "label class-header-text",
      node_label_attrs(node),
    ),
  )
  if rows.length() == 0 {
    sb.write_string(
      "<text class=\"class-row\" x=\"\{node.x}\" y=\"\{top + header_height + 14}\" text-anchor=\"middle\">(no attributes)</text>",
    )
    return sb.to_string()
  }

  for i, row in rows {
    let y = top + header_height + 14 + i * row_height
    sb.write_string(
      "<text class=\"class-row\" x=\"\{left + 8}\" y=\"\{y}\" text-anchor=\"start\">\{xml_escape(row)}</text>",
    )
  }
  sb.to_string()
}

///|
fn sequence_block_type_text(block_type : SequenceBlockType) -> String {
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
fn render_sequence_block(block : PositionedSequenceBlock) -> String {
  let sb = StringBuilder::new()
  sb.write_string(
    "<rect class=\"sequence-block\" x=\"\{block.x}\" y=\"\{block.y}\" width=\"\{block.width}\" height=\"\{block.height}\" />",
  )
  let label_text = if block.label == "" {
    sequence_block_type_text(block.block_type)
  } else {
    "\{sequence_block_type_text(block.block_type)} [\{block.label}]"
  }
  let tab_width = label_text.length() * 7 + 16
  let tab_height = 18
  sb.write_string(
    "<rect class=\"sequence-block-tab\" x=\"\{block.x}\" y=\"\{block.y}\" width=\"\{tab_width}\" height=\"\{tab_height}\" />",
  )
  sb.write_string(
    "<text class=\"sequence-block-label\" x=\"\{block.x + 6}\" y=\"\{block.y + tab_height / 2}\" dominant-baseline=\"middle\">\{xml_escape(label_text)}</text>",
  )
  for divider in block.dividers {
    sb.write_string(
      "<line class=\"sequence-divider\" x1=\"\{block.x}\" y1=\"\{divider.y}\" x2=\"\{block.x + block.width}\" y2=\"\{divider.y}\" />",
    )
    if divider.label != "" {
      sb.write_string(
        "<text class=\"sequence-divider-label\" x=\"\{block.x + 8}\" y=\"\{divider.y + 14}\">[\{xml_escape(divider.label)}]</text>",
      )
    }
  }
  sb.to_string()
}

///|
fn render_sequence_activation(
  activation : PositionedSequenceActivation,
) -> String {
  let height = activation.bottom_y - activation.top_y
  if height <= 0 {
    ""
  } else {
    "<rect class=\"sequence-activation\" x=\"\{activation.x}\" y=\"\{activation.top_y}\" width=\"\{activation.width}\" height=\"\{height}\" />"
  }
}

///|
fn render_sequence_note(note : PositionedSequenceNote) -> String {
  let fold = 6
  let sb = StringBuilder::new()
  sb.write_string(
    "<rect class=\"sequence-note\" x=\"\{note.x}\" y=\"\{note.y}\" width=\"\{note.width}\" height=\"\{note.height}\" />",
  )
  sb.write_string(
    "<polygon class=\"sequence-note-fold\" points=\"\{note.x + note.width - fold},\{note.y} \{note.x + note.width},\{note.y + fold} \{note.x + note.width - fold},\{note.y + fold}\" />",
  )
  let text_x = note.x + note.width / 2
  let text_y = note.y + note.height / 2
  sb.write_string(
    "<text class=\"sequence-note-text\" x=\"\{text_x}\" y=\"\{text_y}\" text-anchor=\"middle\" dominant-baseline=\"middle\">\{xml_escape(note.text)}</text>",
  )
  sb.to_string()
}

///|
fn subgraph_header_height() -> Int {
  24
}

///|
fn render_group(group : PositionedGroup) -> String {
  let header_height = subgraph_header_height()
  let sb = StringBuilder::new()
  sb.write_string(
    "<rect class=\"group-outer\" x=\"\{group.x}\" y=\"\{group.y}\" width=\"\{group.width}\" height=\"\{group.height}\" rx=\"0\" ry=\"0\" fill=\"var(--_group-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"1\" />",
  )
  sb.write_string(
    "<rect class=\"group-header\" x=\"\{group.x}\" y=\"\{group.y}\" width=\"\{group.width}\" height=\"\{header_height}\" rx=\"0\" ry=\"0\" fill=\"var(--_group-hdr)\" stroke=\"var(--_node-stroke)\" stroke-width=\"1\" />",
  )
  sb.write_string(
    "<text class=\"group-label\" x=\"\{group.x + 8}\" y=\"\{group.y + header_height / 2}\" dominant-baseline=\"middle\" text-anchor=\"start\" fill=\"var(--_text-sec)\">\{xml_escape(group.label)}</text>",
  )
  for child in group.children {
    sb.write_string(render_group(child))
  }
  sb.to_string()
}

///|
fn render_node_label(node : PositionedNode) -> String {
  if node.label == "" {
    return ""
  }
  if node.shape == StateStart {
    return ""
  }
  if node.shape == SequenceParticipant && sequence_is_actor_node(node) {
    return "<text class=\"label\" x=\"\{node.x}\" y=\"\{node.y + node.height / 2 + 14}\" text-anchor=\"middle\"\{node_label_attrs(node)}>\{xml_escape(node.label)}</text>"
  }
  if node.shape is (ClassEntity | ErEntity) {
    return render_class_like_label(node)
  }
  let lines = node.label.split("\n").map(part => part.to_string()).to_array()
  if lines.length() <= 1 {
    return text_svg_with_attrs(
      node.x,
      node.y,
      node.label,
      "label",
      node_label_attrs(node),
    )
  }

  let line_height = 14
  let start_y = node.y - (lines.length() - 1) * line_height / 2
  let sb = StringBuilder::new()
  sb.write_string(
    "<text class=\"label\" x=\"\{node.x}\" text-anchor=\"middle\"\{node_label_attrs(node)}>",
  )
  for i, line in lines {
    let y = start_y + i * line_height
    sb.write_string(
      "<tspan x=\"\{node.x}\" y=\"\{y}\">\{xml_escape(line)}</tspan>",
    )
  }
  sb.write_string("</text>")
  sb.to_string()
}

///|
fn is_sequence_render(graph : PositionedGraph) -> Bool {
  if graph.nodes.length() == 0 {
    return false
  }
  for node in graph.nodes {
    if node.shape != SequenceParticipant {
      return false
    }
  }
  true
}

///|
fn is_class_render(graph : PositionedGraph) -> Bool {
  if graph.nodes.length() == 0 {
    return false
  }
  for node in graph.nodes {
    if node.shape != ClassEntity {
      return false
    }
  }
  true
}

///|
fn is_er_render(graph : PositionedGraph) -> Bool {
  if graph.nodes.length() == 0 {
    return false
  }
  for node in graph.nodes {
    if node.shape != ErEntity {
      return false
    }
  }
  true
}

///|
fn marker_attr(name : String, marker_id : String?) -> String {
  match marker_id {
    Some(marker) => " \{name}=\"url(#\{marker})\""
    None => ""
  }
}

///|
fn css_var_attr(name : String, value : String?) -> String {
  match value {
    Some(found) => ";\{name}:\{found}"
    None => ""
  }
}

///|
fn edge_label_bg_size(label : String) -> (Int, Int) {
  let width = (label.length() * 6 + 16).max(18)
  let height = 27
  (width, height)
}

///|
fn marker_start_for_class(operator : String?) -> String? {
  match operator {
    Some(op) =>
      if op.has_prefix("<|") {
        Some("class-inherit")
      } else if op.has_prefix("*") {
        Some("class-composition")
      } else if op.has_prefix("o") {
        Some("class-aggregation")
      } else if op.contains("<") {
        Some("class-arrow")
      } else {
        None
      }
    None => None
  }
}

///|
fn marker_end_for_class(operator : String?) -> String? {
  match operator {
    Some(op) =>
      if op.has_suffix("|>") {
        Some("class-inherit")
      } else if op.has_suffix("*") {
        Some("class-composition")
      } else if op.has_suffix("o") {
        Some("class-aggregation")
      } else if op.contains(">") {
        Some("class-arrow")
      } else {
        None
      }
    None => None
  }
}

///|
fn marker_end_for_sequence(operator : String?) -> String? {
  match operator {
    Some(op) =>
      if op.contains(">>") || op.contains("x") {
        Some("seq-arrow")
      } else if op.contains(">") || op.contains(")") {
        Some("seq-arrow-open")
      } else {
        None
      }
    None => None
  }
}

///|
fn er_endpoint_tokens(operator : String?) -> (String?, String?) {
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
        (Some(start), Some(end)) => {
          let start_token = (try! op[:start]).to_string().trim().to_string()
          let end_token = (try! op[end + 1:]).to_string().trim().to_string()
          let start_value = if start_token == "" {
            None
          } else {
            Some(start_token)
          }
          let end_value = if end_token == "" { None } else { Some(end_token) }
          (start_value, end_value)
        }
        _ => (None, None)
      }
    }
    None => (None, None)
  }
}

///|
fn endpoint_text_positions(points : Array[Point]) -> (Point, Point) {
  let start = points[0]
  let end = points[points.length() - 1]
  let horizontal = (end.x - start.x).abs() >= (end.y - start.y).abs()
  if horizontal {
    let moving_right = end.x >= start.x
    let start_pos = Point::{
      x: start.x + (if moving_right { 10 } else { -10 }),
      y: start.y - 6,
    }
    let end_pos = Point::{
      x: end.x + (if moving_right { -10 } else { 10 }),
      y: end.y - 6,
    }
    (start_pos, end_pos)
  } else {
    let moving_down = end.y >= start.y
    let start_pos = Point::{
      x: start.x + 8,
      y: start.y + (if moving_down { 10 } else { -10 }),
    }
    let end_pos = Point::{
      x: end.x + 8,
      y: end.y + (if moving_down { -10 } else { 10 }),
    }
    (start_pos, end_pos)
  }
}

///|
fn er_endpoint_text_svg(edge : PositionedEdge) -> String {
  let (start_token, end_token) = er_endpoint_tokens(edge.relation_operator)
  match (start_token, end_token) {
    (None, None) => ""
    _ => {
      let (start_pos, end_pos) = endpoint_text_positions(edge.points)
      let sb = StringBuilder::new()
      match start_token {
        Some(token) =>
          sb.write_string(
            "<text class=\"edge-endpoint\" x=\"\{start_pos.x}\" y=\"\{start_pos.y}\" text-anchor=\"middle\">\{xml_escape(token)}</text>",
          )
        None => ()
      }
      match end_token {
        Some(token) =>
          sb.write_string(
            "<text class=\"edge-endpoint\" x=\"\{end_pos.x}\" y=\"\{end_pos.y}\" text-anchor=\"middle\">\{xml_escape(token)}</text>",
          )
        None => ()
      }
      sb.to_string()
    }
  }
}

///|
fn render_node_shape(node : PositionedNode) -> String {
  let left = node.x - node.width / 2
  let top = node.y - node.height / 2
  let right = node.x + node.width / 2
  let bottom = node.y + node.height / 2
  let center_x = node.x
  let center_y = node.y
  let attrs = node_shape_attrs(node)

  match node.shape {
    Rectangle =>
      "<rect class=\"node-shape\" x=\"\{left}\" y=\"\{top}\" width=\"\{node.width}\" height=\"\{node.height}\" rx=\"0\" ry=\"0\"\{attrs} />"
    Rounded =>
      "<rect class=\"node-shape\" x=\"\{left}\" y=\"\{top}\" width=\"\{node.width}\" height=\"\{node.height}\" rx=\"6\" ry=\"6\"\{attrs} />"
    Stadium =>
      "<rect class=\"node-shape\" x=\"\{left}\" y=\"\{top}\" width=\"\{node.width}\" height=\"\{node.height}\" rx=\"\{node.height / 2}\" ry=\"\{node.height / 2}\"\{attrs} />"
    Circle => {
      let radius = node.width.min(node.height) / 2
      "<circle class=\"node-shape\" cx=\"\{center_x}\" cy=\"\{center_y}\" r=\"\{radius}\"\{attrs} />"
    }
    DoubleCircle => {
      let outer_r = node.width.min(node.height) / 2
      let inner_r = (outer_r - 5).max(1)
      "<circle class=\"node-shape\" cx=\"\{center_x}\" cy=\"\{center_y}\" r=\"\{outer_r}\"\{attrs} /><circle class=\"node-shape\" cx=\"\{center_x}\" cy=\"\{center_y}\" r=\"\{inner_r}\"\{attrs} />"
    }
    Diamond =>
      polygon_svg(
        "\{center_x},\{top} \{right},\{center_y} \{center_x},\{bottom} \{left},\{center_y}",
        "node-shape",
        attrs,
      )
    Hexagon => {
      let offset = node.height / 4
      polygon_svg(
        "\{left + offset},\{top} \{right - offset},\{top} \{right},\{center_y} \{right - offset},\{bottom} \{left + offset},\{bottom} \{left},\{center_y}",
        "node-shape",
        attrs,
      )
    }
    Asymmetric =>
      polygon_svg(
        "\{left + 12},\{top} \{right},\{top} \{right},\{bottom} \{left + 12},\{bottom} \{left},\{center_y}",
        "node-shape",
        attrs,
      )
    Trapezoid => {
      let offset = node.width * 15 / 100
      polygon_svg(
        "\{left + offset},\{top} \{right - offset},\{top} \{right},\{bottom} \{left},\{bottom}",
        "node-shape",
        attrs,
      )
    }
    TrapezoidAlt => {
      let offset = node.width * 15 / 100
      polygon_svg(
        "\{left},\{top} \{right},\{top} \{right - offset},\{bottom} \{left + offset},\{bottom}",
        "node-shape",
        attrs,
      )
    }
    Subroutine =>
      "<rect class=\"node-shape\" x=\"\{left}\" y=\"\{top}\" width=\"\{node.width}\" height=\"\{node.height}\" rx=\"0\" ry=\"0\"\{attrs} /><line class=\"node-shape\" x1=\"\{left + 8}\" y1=\"\{top}\" x2=\"\{left + 8}\" y2=\"\{bottom}\"\{attrs} /><line class=\"node-shape\" x1=\"\{right - 8}\" y1=\"\{top}\" x2=\"\{right - 8}\" y2=\"\{bottom}\"\{attrs} />"
    Cylinder => {
      let ry = 7
      let fill_attr = attr("fill", style_value(node.inline_style, "fill"))
      let stroke_attrs = attr(
          "stroke",
          style_value(node.inline_style, "stroke"),
        ) +
        attr("stroke-width", style_value(node.inline_style, "stroke-width")) +
        attr(
          "stroke-dasharray",
          style_value(node.inline_style, "stroke-dasharray"),
        )
      "<rect class=\"node-shape\" x=\"\{left}\" y=\"\{top + ry}\" width=\"\{node.width}\" height=\"\{node.height - 2 * ry}\" rx=\"0\"\{fill_attr} stroke=\"none\" /><line class=\"node-shape\" x1=\"\{left}\" y1=\"\{top + ry}\" x2=\"\{left}\" y2=\"\{bottom - ry}\"\{stroke_attrs} /><line class=\"node-shape\" x1=\"\{right}\" y1=\"\{top + ry}\" x2=\"\{right}\" y2=\"\{bottom - ry}\"\{stroke_attrs} /><ellipse class=\"node-shape\" cx=\"\{center_x}\" cy=\"\{top + ry}\" rx=\"\{node.width / 2}\" ry=\"\{ry}\"\{attrs} /><ellipse class=\"node-shape\" cx=\"\{center_x}\" cy=\"\{bottom - ry}\" rx=\"\{node.width / 2}\" ry=\"\{ry}\"\{attrs} />"
    }
    StateStart => {
      let radius = (node.width.min(node.height) / 2 - 2).max(1)
      "<circle class=\"state-start\" cx=\"\{center_x}\" cy=\"\{center_y}\" r=\"\{radius}\" fill=\"var(--_text)\" stroke=\"none\" />"
    }
    StateEnd => {
      let outer_r = (node.width.min(node.height) / 2 - 2).max(1)
      let inner_r = (outer_r - 4).max(1)
      "<circle class=\"node-shape\" cx=\"\{center_x}\" cy=\"\{center_y}\" r=\"\{outer_r}\" fill=\"none\" stroke=\"var(--_text)\" stroke-width=\"1.5\" /><circle class=\"state-start\" cx=\"\{center_x}\" cy=\"\{center_y}\" r=\"\{inner_r}\" fill=\"var(--_text)\" stroke=\"none\" />"
    }
    ClassEntity | ErEntity => {
      let header_height = 32
      let divider_y = top + header_height
      "<rect class=\"node-shape\" x=\"\{left}\" y=\"\{top}\" width=\"\{node.width}\" height=\"\{node.height}\" rx=\"0\"\{attrs} /><rect class=\"node-header\" x=\"\{left}\" y=\"\{top}\" width=\"\{node.width}\" height=\"\{header_height}\" rx=\"0\"\{attrs} /><line class=\"node-divider\" x1=\"\{left}\" y1=\"\{divider_y}\" x2=\"\{right}\" y2=\"\{divider_y}\" />"
    }
    SequenceParticipant =>
      if sequence_is_actor_node(node) {
        let outer_r = (node.height / 2 - 2).max(10)
        let head_r = (outer_r / 3).max(3)
        let head_cy = center_y - outer_r / 3
        let shoulder_y = center_y + outer_r / 3
        let shoulder_left = center_x - outer_r / 2
        let shoulder_right = center_x + outer_r / 2
        "<circle class=\"sequence-actor\" cx=\"\{center_x}\" cy=\"\{center_y}\" r=\"\{outer_r}\" /><circle class=\"sequence-actor\" cx=\"\{center_x}\" cy=\"\{head_cy}\" r=\"\{head_r}\" /><path class=\"sequence-actor\" d=\"M\{shoulder_left} \{shoulder_y} Q \{center_x} \{shoulder_y + head_r} \{shoulder_right} \{shoulder_y}\" />"
      } else {
        "<rect class=\"node-shape\" x=\"\{left}\" y=\"\{top}\" width=\"\{node.width}\" height=\"\{node.height}\" rx=\"4\"\{attrs} />"
      }
  }
}

///|
/// Renders a positioned graph as an SVG string.
pub fn render_svg(
  graph : PositionedGraph,
  colors : DiagramColors,
  font : String,
  transparent : Bool,
) -> String {
  let sequence_mode = is_sequence_render(graph)
  let class_mode = is_class_render(graph)
  let er_mode = is_er_render(graph)
  let font_url = font_url_component(font)
  let root_style = {
    let sb = StringBuilder::new()
    sb.write_string("--bg:\{colors.bg};--fg:\{colors.fg}")
    sb.write_string(css_var_attr("--line", colors.line))
    sb.write_string(css_var_attr("--accent", colors.accent))
    sb.write_string(css_var_attr("--muted", colors.muted))
    sb.write_string(css_var_attr("--surface", colors.surface))
    sb.write_string(css_var_attr("--border", colors.border))
    if !transparent {
      sb.write_string(";background:var(--bg)")
    }
    sb.to_string()
  }

  let sb = StringBuilder::new()
  sb.write_string(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\{graph.width}\" height=\"\{graph.height}\" viewBox=\"0 0 \{graph.width} \{graph.height}\" style=\"\{root_style}\">",
  )
  sb.write_string(
    "<style>@import url('https://fonts.googleapis.com/css2?family=\{font_url}:wght@400;500;600;700&amp;display=swap');text{font-family:'\{xml_escape(font)}',system-ui,sans-serif}svg{--_text:var(--fg);--_text-sec:var(--muted,color-mix(in srgb,var(--fg) 60%,var(--bg)));--_text-muted:var(--muted,color-mix(in srgb,var(--fg) 40%,var(--bg)));--_text-faint:color-mix(in srgb,var(--fg) 25%,var(--bg));--_line:var(--line,color-mix(in srgb,var(--fg) 30%,var(--bg)));--_arrow:var(--accent,color-mix(in srgb,var(--fg) 50%,var(--bg)));--_node-fill:var(--surface,color-mix(in srgb,var(--fg) 3%,var(--bg)));--_node-stroke:var(--border,color-mix(in srgb,var(--fg) 20%,var(--bg)));--_group-fill:var(--bg);--_group-hdr:color-mix(in srgb,var(--fg) 5%,var(--bg));--_inner-stroke:color-mix(in srgb,var(--fg) 12%,var(--bg));--_key-badge:color-mix(in srgb,var(--fg) 10%,var(--bg));}</style>",
  )
  sb.write_string("<defs>")
  sb.write_string(
    "<marker id=\"arrowhead\" markerWidth=\"8\" markerHeight=\"4.8\" refX=\"8\" refY=\"2.4\" orient=\"auto\"><polygon points=\"0 0, 8 2.4, 0 4.8\" fill=\"var(--_arrow)\" /></marker>",
  )
  sb.write_string(
    "<marker id=\"arrowhead-start\" markerWidth=\"8\" markerHeight=\"4.8\" refX=\"0\" refY=\"2.4\" orient=\"auto-start-reverse\"><polygon points=\"8 0, 0 2.4, 8 4.8\" fill=\"var(--_arrow)\" /></marker>",
  )
  sb.write_string(
    "<marker id=\"seq-arrow\" markerWidth=\"8\" markerHeight=\"4.8\" refX=\"8\" refY=\"2.4\" orient=\"auto-start-reverse\"><polygon points=\"0 0, 8 2.4, 0 4.8\" fill=\"var(--_arrow)\" /></marker>",
  )
  sb.write_string(
    "<marker id=\"seq-arrow-open\" markerWidth=\"8\" markerHeight=\"4.8\" refX=\"8\" refY=\"2.4\" orient=\"auto-start-reverse\"><polyline points=\"0 0, 8 2.4, 0 4.8\" fill=\"none\" stroke=\"var(--_arrow)\" stroke-width=\"1\" /></marker>",
  )
  sb.write_string(
    "<marker id=\"class-arrow\" markerWidth=\"8\" markerHeight=\"6\" refX=\"8\" refY=\"3\" orient=\"auto-start-reverse\"><polyline points=\"0 0, 8 3, 0 6\" fill=\"none\" stroke=\"var(--_arrow)\" stroke-width=\"1.5\" /></marker>",
  )
  sb.write_string(
    "<marker id=\"class-inherit\" markerWidth=\"12\" markerHeight=\"10\" refX=\"12\" refY=\"5\" orient=\"auto-start-reverse\"><polygon points=\"0 0, 12 5, 0 10\" fill=\"var(--bg)\" stroke=\"var(--_arrow)\" stroke-width=\"1.5\" /></marker>",
  )
  sb.write_string(
    "<marker id=\"class-composition\" markerWidth=\"12\" markerHeight=\"10\" refX=\"0\" refY=\"5\" orient=\"auto-start-reverse\"><polygon points=\"6 0, 12 5, 6 10, 0 5\" fill=\"var(--_arrow)\" stroke=\"var(--_arrow)\" stroke-width=\"1\" /></marker>",
  )
  sb.write_string(
    "<marker id=\"class-aggregation\" markerWidth=\"12\" markerHeight=\"10\" refX=\"0\" refY=\"5\" orient=\"auto-start-reverse\"><polygon points=\"6 0, 12 5, 6 10, 0 5\" fill=\"var(--bg)\" stroke=\"var(--_arrow)\" stroke-width=\"1.5\" /></marker>",
  )
  sb.write_string(
    "<style>.node-shape{fill:var(--_node-fill);stroke:var(--_node-stroke);stroke-width:1.5}.node-header{fill:var(--_group-hdr);stroke:var(--_node-stroke);stroke-width:1}.node-divider{stroke:var(--_node-stroke);stroke-width:1}.edge{fill:none;stroke:var(--_line);stroke-width:0.75}.lifeline{fill:none;stroke:var(--_line);stroke-width:0.75;stroke-dasharray:6 4}.label{fill:var(--_text);font-size:13px}.class-header-text{font-weight:700}.class-row{fill:var(--_text-muted);font-size:11px}.edge-endpoint{fill:var(--_text-muted);font-size:11px}.edge-label-bg{fill:var(--bg);stroke:var(--_inner-stroke);stroke-width:0.5}.edge-label{fill:var(--_text-muted);font-size:11px}.state-start{fill:var(--_text)}.sequence-actor{fill:none;stroke:var(--_line);stroke-width:1.5}.sequence-block{fill:none;stroke:var(--_node-stroke);stroke-width:1}.sequence-block-tab{fill:var(--_group-hdr);stroke:var(--_node-stroke);stroke-width:1}.sequence-block-label{fill:var(--_text-sec);font-size:11px;font-weight:600}.sequence-divider{stroke:var(--_line);stroke-width:0.75;stroke-dasharray:6 4}.sequence-divider-label{fill:var(--_text-muted);font-size:11px}.sequence-activation{fill:var(--_node-fill);stroke:var(--_node-stroke);stroke-width:0.75}.sequence-note{fill:var(--_group-hdr);stroke:var(--_node-stroke);stroke-width:0.75}.sequence-note-fold{fill:var(--_inner-stroke)}.sequence-note-text{fill:var(--_text-muted);font-size:11px}</style>",
  )
  sb.write_string("</defs>")

  if !transparent {
    sb.write_string(
      "<rect width=\"\{graph.width}\" height=\"\{graph.height}\" fill=\"var(--bg)\" />",
    )
  }

  for group in graph.groups {
    sb.write_string(render_group(group))
  }

  if sequence_mode {
    for block in graph.sequence_blocks {
      sb.write_string(render_sequence_block(block))
    }
    if graph.sequence_lifelines.length() > 0 {
      for lifeline in graph.sequence_lifelines {
        sb.write_string(
          "<line class=\"lifeline\" x1=\"\{lifeline.x}\" y1=\"\{lifeline.top_y}\" x2=\"\{lifeline.x}\" y2=\"\{lifeline.bottom_y}\" />",
        )
      }
    } else {
      for node in graph.nodes {
        let top = node.y + node.height / 2
        let bottom = graph.height - 40
        sb.write_string(
          "<line class=\"lifeline\" x1=\"\{node.x}\" y1=\"\{top}\" x2=\"\{node.x}\" y2=\"\{bottom}\" />",
        )
      }
    }
    for activation in graph.sequence_activations {
      sb.write_string(render_sequence_activation(activation))
    }
  }

  for edge in graph.edges {
    if edge.points.length() < 2 {
      continue
    }
    let edge_style = if class_mode && edge.style == Dotted {
      " stroke-dasharray=\"6 4\""
    } else {
      style_for_edge(edge.style)
    }
    let (marker_start, marker_end) = if class_mode {
      (
        marker_attr(
          "marker-start",
          marker_start_for_class(edge.relation_operator),
        ),
        marker_attr("marker-end", marker_end_for_class(edge.relation_operator)),
      )
    } else if sequence_mode {
      (
        "",
        marker_attr(
          "marker-end",
          marker_end_for_sequence(edge.relation_operator),
        ),
      )
    } else if edge.has_arrow_start || edge.has_arrow_end {
      (
        if edge.has_arrow_start {
          " marker-start=\"url(#arrowhead-start)\""
        } else {
          ""
        },
        if edge.has_arrow_end {
          " marker-end=\"url(#arrowhead)\""
        } else {
          ""
        },
      )
    } else {
      ("", "")
    }
    if !sequence_mode && edge_needs_curve_path(edge.points) {
      let path_d = basis_curve_path(edge.points)
      sb.write_string(
        "<path class=\"edge\" d=\"\{path_d}\"\{edge_style}\{marker_start}\{marker_end} />",
      )
    } else {
      sb.write_string(
        "<polyline class=\"edge\" points=\"\{points_to_svg(edge.points)}\"\{edge_style}\{marker_start}\{marker_end} />",
      )
    }
    if er_mode {
      sb.write_string(er_endpoint_text_svg(edge))
    }
    match edge.label {
      Some(label) => {
        let resolved_pos = match edge.label_position {
          Some(pos) => Some(pos)
          None => edge_midpoint(edge.points)
        }
        match resolved_pos {
          Some(pos) => {
            let label_y = pos.y
            let (bg_width, bg_height) = edge_label_bg_size(label)
            let bg_x = pos.x - bg_width / 2
            let bg_y = label_y - bg_height / 2
            sb.write_string(
              "<rect class=\"edge-label-bg\" x=\"\{bg_x}\" y=\"\{bg_y}\" width=\"\{bg_width}\" height=\"\{bg_height}\" rx=\"4\" ry=\"4\" />",
            )
            sb.write_string(text_svg(pos.x, label_y, label, "edge-label"))
          }
          None => ()
        }
      }
      None => ()
    }
  }

  if sequence_mode {
    for note in graph.sequence_notes {
      sb.write_string(render_sequence_note(note))
    }
  }

  for node in graph.nodes {
    sb.write_string(render_node_shape(node))
    sb.write_string(render_node_label(node))
  }

  sb.write_string("</svg>")
  sb.to_string()
}
