///|

///|
fn label_position_for(edges : Array[PositionedEdge], label : String) -> Point? {
  for edge in edges {
    match (edge.label, edge.label_position) {
      (Some(text), Some(point)) => if text == label { return Some(point) }
      _ => ()
    }
  }
  None
}

///|
fn find_positioned_node(
  nodes : Array[PositionedNode],
  node_id : String,
) -> PositionedNode raise {
  for node in nodes {
    if node.id == node_id {
      return node
    }
  }
  fail("missing positioned node \{node_id}")
}

///|
fn find_positioned_edge(
  edges : Array[PositionedEdge],
  source_id : String,
  target_id : String,
) -> PositionedEdge raise {
  for edge in edges {
    if edge.source == source_id && edge.target == target_id {
      return edge
    }
  }
  fail("missing positioned edge \{source_id} -> \{target_id}")
}

///|
fn test_label_dimensions(label : String) -> (Int, Int) {
  let lines = label.split("\n").map(part => part.to_string()).to_array()
  let mut longest_line = 0
  for line in lines {
    longest_line = longest_line.max(line.length())
  }
  let width = (longest_line * 7 + 12).max(18)
  let height = (lines.length() * 14 + 12).max(18)
  (width, height)
}

///|
fn test_rects_overlap(
  left : Int,
  right : Int,
  top : Int,
  bottom : Int,
  other_left : Int,
  other_right : Int,
  other_top : Int,
  other_bottom : Int,
) -> Bool {
  spans_overlap(left, right, other_left, other_right) &&
  spans_overlap(top, bottom, other_top, other_bottom)
}

///|
fn spans_overlap(
  a_left : Int,
  a_right : Int,
  b_left : Int,
  b_right : Int,
) -> Bool {
  !(a_right < b_left || b_right < a_left)
}

///|
fn point_equals(left : Point, right : Point) -> Bool {
  left.x == right.x && left.y == right.y
}

///|
fn diamond_boundary_x_at_y(
  node : PositionedNode,
  y : Int,
  right_side : Bool,
) -> Int {
  let half_height = node.height / 2
  if half_height <= 0 {
    return node.x
  }
  let half_width = node.width / 2
  let y_offset = (y - node.y).abs().min(half_height)
  let x_offset = half_width * (half_height - y_offset) / half_height
  if right_side {
    node.x + x_offset
  } else {
    node.x - x_offset
  }
}

///|
fn point_near_diamond_side(
  node : PositionedNode,
  point : Point,
  right_side : Bool,
) -> Bool {
  let top = node.y - node.height / 2
  let bottom = node.y + node.height / 2
  if point.y < top || point.y > bottom {
    return false
  }
  let boundary_x = diamond_boundary_x_at_y(node, point.y, right_side)
  if right_side {
    point.x >= node.x && (point.x - boundary_x).abs() <= 1
  } else {
    point.x <= node.x && (point.x - boundary_x).abs() <= 1
  }
}

///|
fn int_sign(value : Int) -> Int {
  if value > 0 {
    1
  } else if value < 0 {
    -1
  } else {
    0
  }
}

///|
fn segment_intersects_horizontal_span(
  start : Point,
  end : Point,
  left : Int,
  right : Int,
  y : Int,
) -> Bool {
  let top = start.y.min(end.y)
  let bottom = start.y.max(end.y)
  if y < top || y > bottom {
    return false
  }

  if start.y == end.y {
    if start.y != y {
      return false
    }
    let segment_left = start.x.min(end.x)
    let segment_right = start.x.max(end.x)
    return spans_overlap(left, right, segment_left, segment_right)
  }

  let dx = end.x - start.x
  let dy = end.y - start.y
  let numerator = start.x * dy + dx * (y - start.y)
  if dy > 0 {
    left * dy <= numerator && numerator <= right * dy
  } else {
    right * dy <= numerator && numerator <= left * dy
  }
}

///|
fn segments_properly_intersect(
  a_start : Point,
  a_end : Point,
  b_start : Point,
  b_end : Point,
) -> Bool {
  let o1 = int_sign(
    (a_end.x - a_start.x) * (b_start.y - a_start.y) -
    (a_end.y - a_start.y) * (b_start.x - a_start.x),
  )
  let o2 = int_sign(
    (a_end.x - a_start.x) * (b_end.y - a_start.y) -
    (a_end.y - a_start.y) * (b_end.x - a_start.x),
  )
  let o3 = int_sign(
    (b_end.x - b_start.x) * (a_start.y - b_start.y) -
    (b_end.y - b_start.y) * (a_start.x - b_start.x),
  )
  let o4 = int_sign(
    (b_end.x - b_start.x) * (a_end.y - b_start.y) -
    (b_end.y - b_start.y) * (a_end.x - b_start.x),
  )
  o1 != 0 && o2 != 0 && o3 != 0 && o4 != 0 && o1 != o2 && o3 != o4
}

///|
fn edges_have_proper_intersection(
  left : PositionedEdge,
  right : PositionedEdge,
) -> Bool {
  if left.points.length() < 2 || right.points.length() < 2 {
    return false
  }

  for i in 1..<left.points.length() {
    let left_start = left.points[i - 1]
    let left_end = left.points[i]
    for j in 1..<right.points.length() {
      let right_start = right.points[j - 1]
      let right_end = right.points[j]
      if segments_properly_intersect(
          left_start, left_end, right_start, right_end,
        ) {
        return true
      }
    }
  }
  false
}

///|
fn points_form_exact_reverse(left : Array[Point], right : Array[Point]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    let left_point = left[i]
    let right_point = right[right.length() - 1 - i]
    if left_point.x != right_point.x || left_point.y != right_point.y {
      return false
    }
  }
  true
}

///|
fn points_arrays_equal(left : Array[Point], right : Array[Point]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    let left_point = left[i]
    let right_point = right[i]
    if left_point.x != right_point.x || left_point.y != right_point.y {
      return false
    }
  }
  true
}

///|
fn has_horizontal_segment(points : Array[Point]) -> Bool {
  if points.length() < 2 {
    return false
  }
  for i in 1..<points.length() {
    let start = points[i - 1]
    let end = points[i]
    if start.y == end.y && start.x != end.x {
      return true
    }
  }
  false
}

///|
fn has_vertical_segment(points : Array[Point]) -> Bool {
  if points.length() < 2 {
    return false
  }
  for i in 1..<points.length() {
    let start = points[i - 1]
    let end = points[i]
    if start.x == end.x && start.y != end.y {
      return true
    }
  }
  false
}

///|
fn has_interior_horizontal_bend_segment(points : Array[Point]) -> Bool {
  if points.length() < 4 {
    return false
  }
  for i in 1..<(points.length() - 1) {
    let start = points[i]
    let end = points[i + 1]
    if start.y == end.y && start.x != end.x {
      return true
    }
  }
  false
}

///|
fn has_interior_vertical_bend_segment(points : Array[Point]) -> Bool {
  if points.length() < 4 {
    return false
  }
  for i in 1..<(points.length() - 1) {
    let start = points[i]
    let end = points[i + 1]
    if start.x == end.x && start.y != end.y {
      return true
    }
  }
  false
}

///|
fn count_logical_edge_crossings(
  positioned : PositionedGraph,
  edges : Array[MermaidEdge],
) -> Int {
  let node_by_id : Map[String, PositionedNode] = {}
  for node in positioned.nodes {
    node_by_id[node.id] = node
  }

  let mut crossings = 0
  for i in 0..<edges.length() {
    let left = edges[i]
    match (node_by_id.get(left.source), node_by_id.get(left.target)) {
      (Some(left_source), Some(left_target)) =>
        for j in (i + 1)..<edges.length() {
          let right = edges[j]
          if left.source == right.source ||
            left.source == right.target ||
            left.target == right.source ||
            left.target == right.target {
            continue
          }
          match (node_by_id.get(right.source), node_by_id.get(right.target)) {
            (Some(right_source), Some(right_target)) =>
              if segments_properly_intersect(
                  { x: left_source.x, y: left_source.y },
                  { x: left_target.x, y: left_target.y },
                  { x: right_source.x, y: right_source.y },
                  { x: right_target.x, y: right_target.y },
                ) {
                crossings += 1
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
  crossings
}

///|
test "Layout engine dagre-parity mode preserves legacy output in scaffold phase" {
  let graph = @parser.parse_mermaid(
    (
      #|graph LR
      #|A[Start] --> B[Middle]
      #|B --> C[End]
      #|A -.-> C
    ),
  )
  let legacy_positioned = layout_graph(graph, RenderOptions::default())
  let parity_positioned = layout_graph(graph, {
    ..RenderOptions::default(),
    layout_engine: Some(DagreParity),
  })

  assert_eq(parity_positioned.nodes, legacy_positioned.nodes)
  assert_eq(parity_positioned.edges, legacy_positioned.edges)
  assert_eq(parity_positioned.groups, legacy_positioned.groups)
}

///|
test "Layout reciprocal edges avoid exact reverse overlap in both engines" {
  let graph = @parser.parse_mermaid(
    (
      #|flowchart LR
      #|A --> B
      #|B --> A
    ),
  )
  let legacy_positioned = layout_graph(graph, RenderOptions::default())
  let parity_positioned = layout_graph(graph, {
    ..RenderOptions::default(),
    layout_engine: Some(DagreParity),
  })
  let legacy_ab = find_positioned_edge(legacy_positioned.edges, "A", "B")
  let legacy_ba = find_positioned_edge(legacy_positioned.edges, "B", "A")
  let parity_ab = find_positioned_edge(parity_positioned.edges, "A", "B")
  let parity_ba = find_positioned_edge(parity_positioned.edges, "B", "A")

  assert_eq(parity_positioned.nodes, legacy_positioned.nodes)
  assert_eq(parity_positioned.groups, legacy_positioned.groups)
  assert_true(!points_form_exact_reverse(legacy_ab.points, legacy_ba.points))
  assert_true(!points_form_exact_reverse(parity_ab.points, parity_ba.points))
}

///|
test "Layout LR long-span edges keep non-crossing sink order" {
  let graph = @parser.parse_mermaid(
    (
      #|graph LR
      #|A
      #|B
      #|M
      #|X
      #|Y
      #|A --> M
      #|B --> M
      #|M --> X
      #|M --> Y
      #|A --> Y
      #|B --> X
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let a = find_positioned_node(positioned.nodes, "A")
  let b = find_positioned_node(positioned.nodes, "B")
  let x = find_positioned_node(positioned.nodes, "X")
  let y = find_positioned_node(positioned.nodes, "Y")

  assert_true(a.y < b.y)
  assert_true(y.y < x.y)
}

///|
test "Layout fanin fanout logical crossings stay bounded on stress case" {
  let graph = @parser.parse_mermaid(
    (
      #|graph LR
      #|I1[I1]
      #|I2[I2]
      #|I3[I3]
      #|I4[I4]
      #|I5[I5]
      #|I6[I6]
      #|I7[I7]
      #|I8[I8]
      #|A1[A1]
      #|A2[A2]
      #|A3[A3]
      #|A4[A4]
      #|P1[P1]
      #|P2[P2]
      #|P3[P3]
      #|P4[P4]
      #|P5[P5]
      #|P6[P6]
      #|G1[G1]
      #|G2[G2]
      #|G3[G3]
      #|O1[O1]
      #|O2[O2]
      #|O3[O3]
      #|O4[O4]
      #|O5[O5]
      #|I1 --> A1
      #|I2 --> A1
      #|I3 --> A2
      #|I4 --> A2
      #|I5 --> A3
      #|I6 --> A3
      #|I7 --> A4
      #|I8 --> A4
      #|I2 --> A2
      #|I3 --> A3
      #|I4 --> A4
      #|I5 --> A1
      #|I6 --> A4
      #|I7 --> A1
      #|A1 --> P1
      #|A1 --> P2
      #|A2 --> P2
      #|A2 --> P3
      #|A3 --> P3
      #|A3 --> P4
      #|A4 --> P4
      #|A4 --> P5
      #|A1 --> P6
      #|A2 --> P5
      #|A3 --> P1
      #|A4 --> P2
      #|P1 --> G1
      #|P2 --> G1
      #|P2 --> G2
      #|P3 --> G2
      #|P3 --> G3
      #|P4 --> G3
      #|P5 --> G3
      #|P6 --> G2
      #|G1 --> O1
      #|G1 --> O2
      #|G2 --> O2
      #|G2 --> O3
      #|G3 --> O3
      #|G3 --> O4
      #|G2 --> O5
      #|O3 --> A2
      #|O4 --> P2
      #|O5 --> G1
      #|P6 --> A1
      #|G3 --> P3
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let crossings = count_logical_edge_crossings(positioned, graph.edges)
  assert_true(crossings <= 40)
}

///|
test "Layout segment-span intersection handles fractional crossing exactly" {
  assert_true(
    segment_intersects_horizontal_span({ x: 0, y: 0 }, { x: 3, y: 2 }, 1, 2, 1),
  )
  assert_eq(
    segment_intersects_horizontal_span({ x: 0, y: 0 }, { x: 3, y: 2 }, 2, 3, 1),
    false,
  )
}

///|
test "Layout cyclic LR flowchart without metadata keeps loop routing vertically separated" {
  let graph = @parser.parse_mermaid(
    (
      #|graph LR
      #|0
      #|1
      #|2
      #|3
      #|4
      #|5
      #|start --- 0
      #|0 -- [a-b] --> 3
      #|1 -- c --> 2
      #|2 -- d --> 4
      #|3 -.-> 1
      #|3 -.-> 4
      #|4 -.-> 0
      #|4 -.-> 5
      #|5 --- #0
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  let start = find_positioned_node(positioned.nodes, "start")
  let q0 = find_positioned_node(positioned.nodes, "0")
  let q1 = find_positioned_node(positioned.nodes, "1")
  let q2 = find_positioned_node(positioned.nodes, "2")
  let q3 = find_positioned_node(positioned.nodes, "3")
  let q4 = find_positioned_node(positioned.nodes, "4")
  let q5 = find_positioned_node(positioned.nodes, "5")
  let accept = find_positioned_node(positioned.nodes, "#0")

  assert_true(start.x < q0.x)
  assert_true(q0.x < q3.x)
  assert_true(q3.x < q4.x)
  assert_true(q4.x < q5.x)
  assert_true(q5.x < accept.x)

  assert_eq(start.y, q0.y)
  assert_true(q3.y < q0.y)
  assert_eq(q0.y, q4.y)
  assert_eq(q4.y, q5.y)
  assert_eq(q1.y, q2.y)
  assert_true(q1.y <= q3.y)
  assert_true(q1.x < q2.x)

  let back_edge = find_positioned_edge(positioned.edges, "4", "0")
  let return_edge = find_positioned_edge(positioned.edges, "3", "1")
  assert_eq(edges_have_proper_intersection(back_edge, return_edge), false)
}

///|
test "Layout class cycle keeps controller and model in the same row" {
  let graph = @parser.parse_mermaid(
    (
      #|classDiagram
      #|  class Model {
      #|    -data Map
      #|    +getData() Map
      #|    +setData(key, val) void
      #|    +notify() void
      #|  }
      #|  class View {
      #|    -model Model
      #|    +render() void
      #|    +update() void
      #|  }
      #|  class Controller {
      #|    -model Model
      #|    -view View
      #|    +handleInput(event) void
      #|    +updateModel(data) void
      #|  }
      #|  Controller --> Model : updates
      #|  Controller --> View : refreshes
      #|  View --> Model : reads
      #|  Model ..> View : notifies
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  let model = find_positioned_node(positioned.nodes, "Model")
  let view = find_positioned_node(positioned.nodes, "View")
  let controller = find_positioned_node(positioned.nodes, "Controller")

  assert_eq(controller.y, model.y)
  assert_true(view.y > model.y)
  assert_true(controller.x != model.x)
}

///|
test "Layout NFA dotted back edge prefers lower lane when upper span is crowded" {
  let graph = @parser.parse_mermaid(
    (
      #|graph LR
      #|0@{shape: circ}
      #|1@{shape: circ}
      #|2@{shape: circ}
      #|3@{shape: circ}
      #|4@{shape: circ}
      #|5@{shape: circ}
      #|start@{shape: f-circ} --- 0
      #|0 -- [a-b] --> 3
      #|1 -- c --> 2
      #|2 -- d --> 4
      #|3 -.-> 1
      #|3 -.-> 4
      #|4 -.-> 0
      #|4 -.-> 5
      #|5 --- #0@{shape: dbl-circ}
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  let q0 = find_positioned_node(positioned.nodes, "0")
  let q4 = find_positioned_node(positioned.nodes, "4")
  let back_edge = find_positioned_edge(positioned.edges, "4", "0")

  assert_true(back_edge.points.length() >= 4)
  assert_true(back_edge.points[1].y > q0.y)
  assert_true(back_edge.points[2].y > q4.y)
}

///|
test "Layout long-span solid back edge uses reserved bend lane" {
  let graph = @parser.parse_mermaid(
    (
      #|graph LR
      #|A
      #|B
      #|C
      #|D
      #|E
      #|F
      #|G
      #|A --> B
      #|B --> C
      #|C --> D
      #|D --> E
      #|E --> F
      #|F --> G
      #|G --> A
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let back_edge = find_positioned_edge(positioned.edges, "G", "A")

  assert_true(back_edge.points.length() >= 4)
  assert_true(has_vertical_segment(back_edge.points))
  assert_true(has_interior_horizontal_bend_segment(back_edge.points))
}

///|
test "Layout long-span vertical solid back edge uses reserved bend column" {
  let graph = @parser.parse_mermaid(
    (
      #|graph TD
      #|A
      #|B
      #|C
      #|D
      #|E
      #|F
      #|G
      #|A --> B
      #|B --> C
      #|C --> D
      #|D --> E
      #|E --> F
      #|F --> G
      #|G --> A
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let back_edge = find_positioned_edge(positioned.edges, "G", "A")

  assert_true(back_edge.points.length() >= 4)
  assert_true(has_horizontal_segment(back_edge.points))
  assert_true(has_interior_vertical_bend_segment(back_edge.points))
}

///|
test "Layout medium-span horizontal solid back edge uses reserved bend lane" {
  let graph = @parser.parse_mermaid(
    (
      #|graph LR
      #|A
      #|B
      #|C
      #|D
      #|E
      #|A --> B
      #|B --> C
      #|C --> D
      #|D --> E
      #|E --> B
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let back_edge = find_positioned_edge(positioned.edges, "E", "B")

  assert_true(back_edge.points.length() >= 4)
  assert_true(has_vertical_segment(back_edge.points))
  assert_true(has_interior_horizontal_bend_segment(back_edge.points))
}

///|
test "Layout medium-span vertical solid back edge uses reserved bend column" {
  let graph = @parser.parse_mermaid(
    (
      #|graph TD
      #|A
      #|B
      #|C
      #|D
      #|A --> B
      #|B --> C
      #|C --> D
      #|D --> A
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let back_edge = find_positioned_edge(positioned.edges, "D", "A")

  assert_true(back_edge.points.length() >= 4)
  assert_true(has_horizontal_segment(back_edge.points))
  assert_true(has_interior_vertical_bend_segment(back_edge.points))
}

///|
test "Layout preserves declared edge order after deferred back-edge routing" {
  let graph = @parser.parse_mermaid(
    (
      #|graph LR
      #|A
      #|B
      #|C
      #|D
      #|A --> B
      #|B --> C
      #|C --> A
      #|A --> D
      #|D --> B
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_eq(positioned.edges.length(), graph.edges.length())
  for i in 0..<graph.edges.length() {
    let expected = graph.edges[i]
    let actual = positioned.edges[i]
    assert_eq(actual.source, expected.source)
    assert_eq(actual.target, expected.target)
  }
}

///|
test "Layout separates reciprocal short LR edges to avoid exact overlap" {
  let graph = @parser.parse_mermaid(
    (
      #|flowchart LR
      #|Start([Start]) --> Check{Valid input?}
      #|Check -->|yes| Build[Build artifact]
      #|Check -->|no| Fix[Fix source]
      #|Fix --> Check
      #|Build --> Ship([Ship])
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let check = find_positioned_node(positioned.nodes, "Check")
  let forward = find_positioned_edge(positioned.edges, "Check", "Fix")
  let backward = find_positioned_edge(positioned.edges, "Fix", "Check")
  let branch_yes = find_positioned_edge(positioned.edges, "Check", "Build")
  let backward_target_anchor = backward.points[backward.points.length() - 1]

  assert_true(backward.points.length() >= 2)
  assert_eq(points_form_exact_reverse(forward.points, backward.points), false)
  assert_true(
    (forward.points[0].y - branch_yes.points[0].y).abs() >= check.height / 2,
  )
  assert_true(!point_equals(forward.points[0], branch_yes.points[0]))
  assert_true(!point_equals(backward_target_anchor, branch_yes.points[0]))
}

///|
test "Layout keeps diamond anchors on shape boundary for reciprocal fanout" {
  let graph = @parser.parse_mermaid(
    (
      #|flowchart LR
      #|Start([Start]) --> Check{Valid input?}
      #|Check -->|yes| Build[Build artifact]
      #|Check -->|no| Fix[Fix source]
      #|Fix --> Check
      #|Build --> Ship([Ship])
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let check = find_positioned_node(positioned.nodes, "Check")
  let check_build = find_positioned_edge(positioned.edges, "Check", "Build")
  let check_fix = find_positioned_edge(positioned.edges, "Check", "Fix")
  let fix_check = find_positioned_edge(positioned.edges, "Fix", "Check")
  let fix_check_target = fix_check.points[fix_check.points.length() - 1]

  assert_true(check.shape is Diamond)
  assert_true(point_near_diamond_side(check, check_build.points[0], true))
  assert_true(point_near_diamond_side(check, check_fix.points[0], true))
  assert_true(point_near_diamond_side(check, fix_check_target, true))
}

///|
test "Layout horizontal rank spacing keeps wide adjacent nodes separated" {
  let graph = @parser.parse_mermaid(
    (
      #|flowchart LR
      #|Start([Start]) --> Check{Valid input?}
      #|Check -->|yes| Build[Build artifact]
      #|Check -->|no| Fix[Fix source]
      #|Fix --> Check
      #|Build --> Ship([Ship])
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let build = find_positioned_node(positioned.nodes, "Build")
  let ship = find_positioned_node(positioned.nodes, "Ship")
  let required_gap = (resolve_node_spacing(RenderOptions::default()) / 5).max(
    16,
  )

  if build.x <= ship.x {
    let gap = ship.x - ship.width / 2 - (build.x + build.width / 2)
    assert_true(gap >= required_gap)
  } else {
    let gap = build.x - build.width / 2 - (ship.x + ship.width / 2)
    assert_true(gap >= required_gap)
  }
}

///|
test "Layout reserves horizontal rank gap for labeled edge clearance" {
  let graph = @parser.parse_mermaid(
    (
      #|flowchart LR
      #|Start([Start]) --> Check{Valid input?}
      #|Check -->|yes| Build[Build artifact]
      #|Check -->|no| Fix[Fix source]
      #|Fix --> Check
      #|Build --> Ship([Ship])
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let check = find_positioned_node(positioned.nodes, "Check")
  let build = find_positioned_node(positioned.nodes, "Build")
  let (label_width, _) = test_label_dimensions("yes")
  let min_gap = (label_width - 4).max(24)

  let check_right = check.x + check.width / 2
  let build_left = build.x - build.width / 2
  let gap = if build_left >= check_right { build_left - check_right } else { 0 }
  assert_true(gap >= min_gap)
}

///|
test "Layout keeps Check->Build label clear of endpoint node boxes" {
  let graph = @parser.parse_mermaid(
    (
      #|flowchart LR
      #|Start([Start]) --> Check{Valid input?}
      #|Check -->|yes| Build[Build artifact]
      #|Check -->|no| Fix[Fix source]
      #|Fix --> Check
      #|Build --> Ship([Ship])
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let check = find_positioned_node(positioned.nodes, "Check")
  let build = find_positioned_node(positioned.nodes, "Build")
  let edge = find_positioned_edge(positioned.edges, "Check", "Build")

  assert_true(edge.points.length() >= 2)
  let label = match edge.label {
    Some(text) => text
    None => fail("missing label for Check->Build")
  }
  let label_position = match edge.label_position {
    Some(point) => point
    None => fail("missing label position for Check->Build")
  }
  let (label_width, label_height) = test_label_dimensions(label)
  let label_left = label_position.x - label_width / 2
  let label_right = label_position.x + (label_width + 1) / 2
  let label_top = label_position.y - label_height / 2
  let label_bottom = label_position.y + (label_height + 1) / 2

  let check_left = check.x - check.width / 2
  let check_right = check.x + check.width / 2
  let check_top = check.y - check.height / 2
  let check_bottom = check.y + check.height / 2
  let build_left = build.x - build.width / 2
  let build_right = build.x + build.width / 2
  let build_top = build.y - build.height / 2
  let build_bottom = build.y + build.height / 2

  assert_true(
    !test_rects_overlap(
      label_left, label_right, label_top, label_bottom, check_left, check_right,
      check_top, check_bottom,
    ),
  )
  assert_true(
    !test_rects_overlap(
      label_left, label_right, label_top, label_bottom, build_left, build_right,
      build_top, build_bottom,
    ),
  )
}

///|
test "Layout reciprocal flow loop avoids polyline crossing at opposite ports" {
  let graph = @parser.parse_mermaid(
    (
      #|flowchart LR
      #|Start([Start]) --> Check{Valid input?}
      #|Check -->|yes| Build[Build artifact]
      #|Check -->|no| Fix[Fix source]
      #|Fix --> Check
      #|Build --> Ship([Ship])
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let check_fix = find_positioned_edge(positioned.edges, "Check", "Fix")
  let fix_check = find_positioned_edge(positioned.edges, "Fix", "Check")

  assert_true(!edges_have_proper_intersection(check_fix, fix_check))
}

///|
test "Layout reciprocal fanout avoids pairwise crossings" {
  let graph = @parser.parse_mermaid(
    (
      #|flowchart LR
      #|A{A}
      #|B[B]
      #|C[C]
      #|A --> B
      #|A --> C
      #|B --> A
      #|C --> A
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let edge_ab = find_positioned_edge(positioned.edges, "A", "B")
  let edge_ac = find_positioned_edge(positioned.edges, "A", "C")
  let edge_ba = find_positioned_edge(positioned.edges, "B", "A")
  let edge_ca = find_positioned_edge(positioned.edges, "C", "A")

  assert_true(edge_ab.points.length() >= 2)
  assert_true(edge_ac.points.length() >= 2)
  assert_true(!point_equals(edge_ab.points[0], edge_ac.points[0]))
  assert_true(!edges_have_proper_intersection(edge_ab, edge_ac))
  assert_true(!edges_have_proper_intersection(edge_ab, edge_ba))
  assert_true(!edges_have_proper_intersection(edge_ab, edge_ca))
  assert_true(!edges_have_proper_intersection(edge_ac, edge_ba))
  assert_true(!edges_have_proper_intersection(edge_ac, edge_ca))
  assert_true(!edges_have_proper_intersection(edge_ba, edge_ca))
}

///|
test "Layout spreads source anchors for horizontal fanout edges" {
  let graph = @parser.parse_mermaid(
    (
      #|flowchart LR
      #|A
      #|B
      #|C
      #|D
      #|A --> B
      #|A --> C
      #|A --> D
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let edge_ab = find_positioned_edge(positioned.edges, "A", "B")
  let edge_ac = find_positioned_edge(positioned.edges, "A", "C")
  let edge_ad = find_positioned_edge(positioned.edges, "A", "D")

  assert_true(edge_ab.points.length() >= 2)
  assert_true(edge_ac.points.length() >= 2)
  assert_true(edge_ad.points.length() >= 2)
  assert_true(!point_equals(edge_ab.points[0], edge_ac.points[0]))
  assert_true(!point_equals(edge_ab.points[0], edge_ad.points[0]))
  assert_true(!point_equals(edge_ac.points[0], edge_ad.points[0]))
  assert_true(!points_arrays_equal(edge_ab.points, edge_ac.points))
  assert_true(!points_arrays_equal(edge_ac.points, edge_ad.points))
}

///|
test "Layout dotted fanout follows target lanes with a single elbow" {
  let graph = @parser.parse_mermaid(
    (
      #|graph LR
      #|0@{shape: circ}
      #|1@{shape: circ}
      #|2@{shape: circ}
      #|3@{shape: circ}
      #|4@{shape: circ}
      #|5@{shape: circ}
      #|6@{shape: circ}
      #|7@{shape: circ}
      #|8@{shape: circ}
      #|start@{shape: f-circ} --- 8
      #|0 -- A --> 1
      #|1 -- B --> 2
      #|2 -- C --> 3
      #|3 --- #0@{shape: dbl-circ}
      #|4 -- A --> 5
      #|5 -- B --> 6
      #|6 -- C --> 7
      #|7 --- #1@{shape: dbl-circ}
      #|8 -.-> 0
      #|8 -.-> 4
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let upper_edge = find_positioned_edge(positioned.edges, "8", "0")
  let lower_edge = find_positioned_edge(positioned.edges, "8", "4")

  assert_true(upper_edge.points.length() >= 3)
  assert_true(lower_edge.points.length() >= 3)
  assert_true(has_horizontal_segment(upper_edge.points))
  assert_true(has_horizontal_segment(lower_edge.points))
}

///|
test "Layout solid long-span fanout separates branch routes" {
  let graph = @parser.parse_mermaid(
    (
      #|graph LR
      #|A
      #|B
      #|C
      #|D
      #|E
      #|A --> B
      #|B --> C
      #|C --> D
      #|D --> E
      #|A --> D
      #|A --> E
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let branch_d = find_positioned_edge(positioned.edges, "A", "D")
  let branch_e = find_positioned_edge(positioned.edges, "A", "E")

  assert_true(branch_d.points.length() >= 2)
  assert_true(branch_e.points.length() >= 2)
  assert_true(!points_arrays_equal(branch_d.points, branch_e.points))
  assert_true(has_horizontal_segment(branch_d.points))
  assert_true(has_horizontal_segment(branch_e.points))
}

///|
test "Layout vertical long-span fanout separates branch routes" {
  let graph = @parser.parse_mermaid(
    (
      #|graph TD
      #|A
      #|B
      #|C
      #|D
      #|E
      #|A --> B
      #|B --> C
      #|C --> D
      #|D --> E
      #|A --> D
      #|A --> E
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let branch_d = find_positioned_edge(positioned.edges, "A", "D")
  let branch_e = find_positioned_edge(positioned.edges, "A", "E")

  assert_true(branch_d.points.length() >= 2)
  assert_true(branch_e.points.length() >= 2)
  assert_true(!points_arrays_equal(branch_d.points, branch_e.points))
  assert_true(has_vertical_segment(branch_d.points))
  assert_true(has_vertical_segment(branch_e.points))
}

///|
test "Layout LR promotes late-defined source for dotted back-reference" {
  let graph = @parser.parse_mermaid(
    (
      #|graph LR
      #|A
      #|B
      #|C
      #|C -.-> A
      #|A --> B
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let a = find_positioned_node(positioned.nodes, "A")
  let b = find_positioned_node(positioned.nodes, "B")
  let c = find_positioned_node(positioned.nodes, "C")

  assert_true(c.x < a.x)
  assert_true(a.x < b.x)
}

///|
test "Layout LR late-defined fanout source still places branches to the right" {
  let graph = @parser.parse_mermaid(
    (
      #|graph LR
      #|0
      #|1
      #|2
      #|3
      #|4
      #|5
      #|6
      #|7
      #|8
      #|start --- 8
      #|0 -- A --> 1
      #|1 -- B --> 2
      #|2 -- C --> 3
      #|3 --- #0
      #|4 -- A --> 5
      #|5 -- B --> 6
      #|6 -- C --> 7
      #|7 --- #1
      #|8 -.-> 0
      #|8 -.-> 4
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let start = find_positioned_node(positioned.nodes, "start")
  let branch = find_positioned_node(positioned.nodes, "8")
  let upper = find_positioned_node(positioned.nodes, "0")
  let lower = find_positioned_node(positioned.nodes, "4")

  assert_true(start.x < branch.x)
  assert_true(branch.x < upper.x)
  assert_true(branch.x < lower.x)
  assert_true(upper.y < lower.y)
}

///|
test "Layout dotted forward transition bends toward target lane" {
  let graph = @parser.parse_mermaid(
    (
      #|graph LR
      #|0@{shape: circ}
      #|1@{shape: circ}
      #|2@{shape: circ}
      #|3@{shape: circ}
      #|4@{shape: circ}
      #|5@{shape: circ}
      #|start@{shape: f-circ} --- 0
      #|0 -- [a-b] --> 3
      #|1 -- c --> 2
      #|2 -- d --> 4
      #|3 -.-> 1
      #|3 -.-> 4
      #|4 -.-> 0
      #|4 -.-> 5
      #|5 --- #0@{shape: dbl-circ}
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())
  let edge = find_positioned_edge(positioned.edges, "3", "4")

  assert_true(edge.points.length() >= 3)
  assert_true(has_horizontal_segment(edge.points))
}

///|
test "Layout invariants: nodes stay inside canvas" {
  let graph = @parser.parse_mermaid(
    (
      #|graph TD
      #|A[Start] --> B{Check} --> C((Done))
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  for node in positioned.nodes {
    assert_true(node.x - node.width / 2 >= 0)
    assert_true(node.y - node.height / 2 >= 0)
    assert_true(node.x + node.width / 2 <= positioned.width)
    assert_true(node.y + node.height / 2 <= positioned.height)
  }
}

///|
test "Layout builds positioned groups for flowchart subgraphs" {
  let graph = @parser.parse_mermaid(
    (
      #|graph TD
      #|subgraph Backend
      #|A --> B
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_eq(positioned.groups.length(), 1)
  let group = positioned.groups[0]
  assert_eq(group.label, "Backend")

  let node_a = find_positioned_node(positioned.nodes, "A")
  let node_b = find_positioned_node(positioned.nodes, "B")

  assert_true(node_a.x - node_a.width / 2 >= group.x)
  assert_true(node_a.y - node_a.height / 2 >= group.y)
  assert_true(node_b.x + node_b.width / 2 <= group.x + group.width)
  assert_true(node_b.y + node_b.height / 2 <= group.y + group.height)
}

///|
test "Layout keeps nested positioned groups inside parent group" {
  let graph = @parser.parse_mermaid(
    (
      #|graph TD
      #|subgraph Outer
      #|subgraph Inner
      #|A --> B
      #|end
      #|C --> D
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_eq(positioned.groups.length(), 1)
  let outer = positioned.groups[0]
  assert_eq(outer.label, "Outer")
  assert_eq(outer.children.length(), 1)

  let inner = outer.children[0]
  assert_eq(inner.label, "Inner")
  assert_true(inner.x >= outer.x)
  assert_true(inner.y >= outer.y)
  assert_true(inner.x + inner.width <= outer.x + outer.width)
  assert_true(inner.y + inner.height <= outer.y + outer.height)
}

///|
test "Layout flowchart subgraph direction override keeps single-edge axis stable" {
  let base_graph = @parser.parse_mermaid(
    (
      #|graph TD
      #|subgraph one
      #|A --> B
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let override_graph = @parser.parse_mermaid(
    (
      #|graph TD
      #|subgraph one
      #|direction LR
      #|A --> B
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )

  let base_positioned = layout_graph(base_graph, RenderOptions::default())
  let override_positioned = layout_graph(
    override_graph,
    RenderOptions::default(),
  )

  let base_a = find_positioned_node(base_positioned.nodes, "A")
  let base_b = find_positioned_node(base_positioned.nodes, "B")
  let override_a = find_positioned_node(override_positioned.nodes, "A")
  let override_b = find_positioned_node(override_positioned.nodes, "B")

  let base_dx = (base_b.x - base_a.x).abs()
  let base_dy = (base_b.y - base_a.y).abs()
  let override_dx = (override_b.x - override_a.x).abs()
  let override_dy = (override_b.y - override_a.y).abs()

  assert_true(base_dy > base_dx)
  assert_true(override_dy >= override_dx)

  let base_edge = find_positioned_edge(base_positioned.edges, "A", "B")
  let override_edge = find_positioned_edge(override_positioned.edges, "A", "B")
  let base_edge_dx = (base_edge.points[1].x - base_edge.points[0].x).abs()
  let base_edge_dy = (base_edge.points[1].y - base_edge.points[0].y).abs()
  let override_edge_dx = (override_edge.points[1].x - override_edge.points[0].x).abs()
  let override_edge_dy = (override_edge.points[1].y - override_edge.points[0].y).abs()

  assert_true(base_edge_dy > base_edge_dx)
  assert_true(override_edge_dy >= override_edge_dx)
}

///|
test "Layout state composite direction override changes internal axis" {
  let base_graph = @parser.parse_mermaid(
    (
      #|stateDiagram-v2
      #|state Processing {
      #|  parse --> validate
      #|}
      #|[*] --> Processing
      #|Processing --> [*]
      #|
    )
    .trim_end()
    .to_string(),
  )
  let override_graph = @parser.parse_mermaid(
    (
      #|stateDiagram-v2
      #|state Processing {
      #|  direction LR
      #|  parse --> validate
      #|}
      #|[*] --> Processing
      #|Processing --> [*]
      #|
    )
    .trim_end()
    .to_string(),
  )

  let base_positioned = layout_graph(base_graph, RenderOptions::default())
  let override_positioned = layout_graph(
    override_graph,
    RenderOptions::default(),
  )

  let base_parse = find_positioned_node(base_positioned.nodes, "parse")
  let base_validate = find_positioned_node(base_positioned.nodes, "validate")
  let override_parse = find_positioned_node(override_positioned.nodes, "parse")
  let override_validate = find_positioned_node(
    override_positioned.nodes,
    "validate",
  )

  let base_dx = (base_validate.x - base_parse.x).abs()
  let base_dy = (base_validate.y - base_parse.y).abs()
  let override_dx = (override_validate.x - override_parse.x).abs()
  let override_dy = (override_validate.y - override_parse.y).abs()

  assert_true(base_dy > base_dx)
  assert_true(override_dx > override_dy)

  let base_edge = find_positioned_edge(
    base_positioned.edges,
    "parse",
    "validate",
  )
  let override_edge = find_positioned_edge(
    override_positioned.edges,
    "parse",
    "validate",
  )
  let base_edge_dx = (base_edge.points[1].x - base_edge.points[0].x).abs()
  let base_edge_dy = (base_edge.points[1].y - base_edge.points[0].y).abs()
  let override_edge_dx = (override_edge.points[1].x - override_edge.points[0].x).abs()
  let override_edge_dy = (override_edge.points[1].y - override_edge.points[0].y).abs()

  assert_true(base_edge_dy > base_edge_dx)
  assert_true(override_edge_dx > override_edge_dy)
}

///|
test "Layout ascii state composite keeps node edge targets over group anchors" {
  let graph = @parser.parse_mermaid(
    (
      #|stateDiagram-v2
      #|  [*] --> Idle
      #|  Idle --> Processing : submit
      #|  state Processing {
      #|    parse --> validate
      #|    validate --> execute
      #|  }
      #|  Processing --> Complete : done
      #|  Processing --> Error : fail
      #|  Error --> Idle : retry
      #|  Complete --> [*]
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph_for_ascii(graph, RenderOptions::default())

  let processing_edge = find_positioned_edge(
    positioned.edges,
    "Idle",
    "Processing",
  )
  let edge_end = processing_edge.points[processing_edge.points.length() - 1]

  let mut processing_group_x = -1
  for group in positioned.groups {
    if group.id == "Processing" {
      processing_group_x = group.x
      break
    }
  }

  assert_true(processing_group_x >= 0)
  assert_true(edge_end.x < processing_group_x)
}

///|
test "Layout keeps subgraph-defined-first content near top in TD" {
  let graph = @parser.parse_mermaid(
    (
      #|graph TD
      #|subgraph Pipeline
      #|ZZ1[Push Code] --> ZZ2{Tests Pass?}
      #|ZZ2 -->|Yes| ZZ3[Build Image]
      #|end
      #|ZZ3 --> AA([Deploy])
      #|AA --> BB{QA?}
      #|BB -->|Yes| CC((Production))
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_eq(positioned.groups.length(), 1)
  let group = positioned.groups[0]
  let deploy = find_positioned_node(positioned.nodes, "AA")

  let group_bottom = group.y + group.height
  let deploy_top = deploy.y - deploy.height / 2
  assert_true(group_bottom <= deploy_top)
}

///|
test "Layout subgraph direction override arranges child subgraphs horizontally" {
  let graph = @parser.parse_mermaid(
    (
      #|graph TD
      #|subgraph Outer
      #|direction LR
      #|subgraph Left
      #|A --> B
      #|end
      #|subgraph Right
      #|C --> D
      #|end
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_eq(positioned.groups.length(), 1)
  let outer = positioned.groups[0]
  assert_eq(outer.children.length(), 2)
  let left_group = outer.children[0]
  let right_group = outer.children[1]

  assert_true(right_group.x > left_group.x + left_group.width)
  assert_true((right_group.y - left_group.y).abs() <= left_group.height)
}

///|
test "Layout subgraph direction override arranges empty child subgraphs horizontally" {
  let graph = @parser.parse_mermaid(
    (
      #|graph TD
      #|subgraph Outer
      #|direction LR
      #|subgraph Left
      #|end
      #|subgraph Right
      #|end
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_eq(positioned.groups.length(), 1)
  let outer = positioned.groups[0]
  assert_eq(outer.children.length(), 2)
  let left_group = outer.children[0]
  let right_group = outer.children[1]

  assert_true(right_group.x > left_group.x + left_group.width)
  assert_true((right_group.y - left_group.y).abs() <= left_group.height)
}

///|
test "Layout invariants: edges have endpoints and labels have positions" {
  let graph = @parser.parse_mermaid(
    (
      #|graph LR
      #|A -->|yes| B
      #|B -.- C
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  for edge in positioned.edges {
    assert_true(edge.points.length() >= 2)
    match edge.label {
      Some(_) => assert_true(edge.label_position is Some(_))
      None => assert_true(edge.label_position is None)
    }
  }
}

///|
test "Layout invariants: LR is wider, TD is taller" {
  let lr_graph = @parser.parse_mermaid(
    (
      #|graph LR
      #|A --> B --> C
      #|
    )
    .trim_end()
    .to_string(),
  )
  let td_graph = @parser.parse_mermaid(
    (
      #|graph TD
      #|A --> B --> C
      #|
    )
    .trim_end()
    .to_string(),
  )

  let lr_layout = layout_graph(lr_graph, RenderOptions::default())
  let td_layout = layout_graph(td_graph, RenderOptions::default())

  assert_true(lr_layout.width > td_layout.width)
  assert_true(td_layout.height > lr_layout.height)
}

///|
test "Layout RL reverses horizontal node ordering and edge direction" {
  let rl_graph = @parser.parse_mermaid(
    (
      #|graph RL
      #|A --> B --> C
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(rl_graph, RenderOptions::default())

  let node_a = find_positioned_node(positioned.nodes, "A")
  let node_b = find_positioned_node(positioned.nodes, "B")
  let node_c = find_positioned_node(positioned.nodes, "C")

  assert_true(node_a.x > node_b.x)
  assert_true(node_b.x > node_c.x)

  let edge_ab = find_positioned_edge(positioned.edges, "A", "B")
  let edge_bc = find_positioned_edge(positioned.edges, "B", "C")
  assert_true(edge_ab.points[0].x > edge_ab.points[1].x)
  assert_true(edge_bc.points[0].x > edge_bc.points[1].x)
}

///|
test "Layout BT reverses vertical node ordering and edge direction" {
  let bt_graph = @parser.parse_mermaid(
    (
      #|graph BT
      #|A --> B --> C
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(bt_graph, RenderOptions::default())

  let node_a = find_positioned_node(positioned.nodes, "A")
  let node_b = find_positioned_node(positioned.nodes, "B")
  let node_c = find_positioned_node(positioned.nodes, "C")

  assert_true(node_a.y > node_b.y)
  assert_true(node_b.y > node_c.y)

  let edge_ab = find_positioned_edge(positioned.edges, "A", "B")
  let edge_bc = find_positioned_edge(positioned.edges, "B", "C")
  assert_true(edge_ab.points[0].y > edge_ab.points[1].y)
  assert_true(edge_bc.points[0].y > edge_bc.points[1].y)
}

///|
test "Layout resolves inline styles with node override precedence" {
  let graph = @parser.parse_mermaid(
    (
      #|graph TD
      #|A[Start]:::entry --> B[End]
      #|classDef entry fill:#f9f,stroke:#333,color:#111
      #|style A stroke:#000,color:#fff
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  let mut style_a : Map[String, String]? = None
  let mut style_b : Map[String, String]? = None

  for node in positioned.nodes {
    if node.id == "A" {
      style_a = node.inline_style
    }
    if node.id == "B" {
      style_b = node.inline_style
    }
  }

  match style_a {
    Some(style) => {
      assert_eq(style.get("fill"), Some("#f9f"))
      assert_eq(style.get("stroke"), Some("#000"))
      assert_eq(style.get("color"), Some("#fff"))
    }
    None => fail("missing inline style for A")
  }
  assert_true(style_b is None)
}

///|
test "Layout sequence messages are vertically separated" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|Alice->>Bob: Hello
      #|Bob-->>Alice: Hi
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 2)
  let first_y = positioned.edges[0].points[0].y
  let second_y = positioned.edges[1].points[0].y
  assert_true(second_y > first_y)
}

///|
test "Layout sequence adds block and divider spacing" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Login
      #|alt Success
      #|B-->>A: 200
      #|else Failure
      #|B-->>A: 500
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_eq(positioned.edges.length(), 3)
  assert_eq(positioned.sequence_blocks.length(), 1)
  let y0 = positioned.edges[0].points[0].y
  let y1 = positioned.edges[1].points[0].y
  let y2 = positioned.edges[2].points[0].y
  assert_eq(y1 - y0, 68)
  assert_eq(y2 - y1, 64)
  assert_true(positioned.sequence_blocks[0].dividers.length() == 1)
}

///|
test "Layout sequence includes notes and activation bars" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|actor U as User
      #|participant S as Server
      #|U->>+S: Request
      #|Note right of S: Process
      #|S-->>-U: Response
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_notes.length() == 1)
  assert_true(positioned.sequence_activations.length() == 1)
  assert_true(positioned.sequence_lifelines.length() == 2)
  assert_true(
    positioned.sequence_activations[0].bottom_y >
    positioned.sequence_activations[0].top_y,
  )
}

///|
test "Layout sequence increases divider offset on horizontal label overlap" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|C->>S: Login
      #|alt Valid credentials
      #|S-->>C: 200 OK
      #|else Bad
      #|S-->>C: 401
      #|else Account locked
      #|S-->>C: 403 Forbidden
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  assert_true(positioned.sequence_blocks[0].dividers.length() == 2)
  let first_divider = positioned.sequence_blocks[0].dividers[0]
  let second_divider = positioned.sequence_blocks[0].dividers[1]

  let first_message_y = positioned.edges[2].points[0].y
  let second_message_y = positioned.edges[3].points[0].y

  assert_eq(first_message_y - first_divider.y, 28)
  assert_eq(second_message_y - second_divider.y, 36)
}

///|
test "Layout sequence ignores standalone activate/deactivate commands" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|participant A
      #|participant B
      #|activate A
      #|A->>B: Work
      #|deactivate A
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_activations.length() == 0)
}

///|
test "Layout sequence keeps block header tab above first in-block message label" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Before
      #|loop Repeat
      #|A->>B: Inside
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  assert_true(positioned.edges.length() == 2)

  let block = positioned.sequence_blocks[0]
  let first_in_block_message_y = positioned.edges[1].points[0].y
  let tab_bottom = block.y + 18
  let message_label_y = first_in_block_message_y - 6

  assert_true(tab_bottom < message_label_y)
  assert_true(message_label_y - tab_bottom >= 10)
}

///|
test "Layout sequence keeps block header below previous message arrow" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Previous
      #|alt Valid
      #|B->>A: Response
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  assert_true(positioned.edges.length() == 2)

  let previous_message_y = positioned.edges[0].points[0].y
  let block_top = positioned.sequence_blocks[0].y

  assert_true(previous_message_y < block_top)
  assert_true(block_top - previous_message_y >= 20)
}

///|
test "Layout sequence keeps divider label above following message label" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Login
      #|alt Success
      #|B->>A: 200
      #|else Failure
      #|B->>A: 500
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(block.dividers.length() == 1)
  assert_true(positioned.edges.length() == 3)

  let divider = block.dividers[0]
  let next_message_y = positioned.edges[2].points[0].y
  let divider_label_bottom = divider.y + 14
  let message_label_y = next_message_y - 6

  assert_true(divider_label_bottom < message_label_y)
  assert_true(message_label_y - divider_label_bottom >= 2)
}

///|
test "Layout sequence ignores activation commands with self messages" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|participant A
      #|activate A
      #|A->>A: Think
      #|deactivate A
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 1)
  assert_true(positioned.sequence_activations.length() == 0)
  assert_true(positioned.edges[0].points.length() >= 4)
}

///|
test "Layout sequence height increases with block header extra spacing" {
  let plain_graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: One
      #|B->>A: Two
      #|A->>B: Three
      #|
    )
    .trim_end()
    .to_string(),
  )
  let block_graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: One
      #|loop Repeat
      #|B->>A: Two
      #|end
      #|A->>B: Three
      #|
    )
    .trim_end()
    .to_string(),
  )

  let plain_positioned = layout_graph(plain_graph, RenderOptions::default())
  let block_positioned = layout_graph(block_graph, RenderOptions::default())

  assert_true(block_positioned.height > plain_positioned.height)
  assert_eq(block_positioned.height - plain_positioned.height, 28)
}

///|
test "Layout sequence height increases with divider extra spacing" {
  let no_divider_graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: M1
      #|B->>A: M2
      #|A->>B: M3
      #|B->>A: M4
      #|
    )
    .trim_end()
    .to_string(),
  )
  let with_divider_graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: M1
      #|alt Case1
      #|B->>A: M2
      #|else Case2
      #|A->>B: M3
      #|else Case3
      #|B->>A: M4
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )

  let no_divider_positioned = layout_graph(
    no_divider_graph,
    RenderOptions::default(),
  )
  let with_divider_positioned = layout_graph(
    with_divider_graph,
    RenderOptions::default(),
  )

  assert_true(with_divider_positioned.height > no_divider_positioned.height)
  assert_eq(with_divider_positioned.height - no_divider_positioned.height, 76)
}

///|
test "Layout sequence block top stays above first in-block message by pad" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Before
      #|loop Retry
      #|A->>B: Inside
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  assert_true(positioned.edges.length() == 2)

  let block = positioned.sequence_blocks[0]
  let first_in_block_message_y = positioned.edges[1].points[0].y

  assert_true(block.y < first_in_block_message_y)
  assert_eq(first_in_block_message_y - block.y, 40)
}

///|
test "Layout sequence divider row is between adjacent messages" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Login
      #|alt Success
      #|B->>A: 200
      #|else Failure
      #|B->>A: 500
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(block.dividers.length() == 1)
  assert_true(positioned.edges.length() == 3)

  let divider_y = block.dividers[0].y
  let before_divider_message_y = positioned.edges[1].points[0].y
  let after_divider_message_y = positioned.edges[2].points[0].y

  assert_true(divider_y > before_divider_message_y)
  assert_true(divider_y < after_divider_message_y)
}

///|
test "Layout sequence block height encloses in-block messages" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Before
      #|alt Yes
      #|B->>A: Response 1
      #|else No
      #|B->>A: Response 2
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(positioned.edges.length() == 3)

  let first_in_block_message_y = positioned.edges[1].points[0].y
  let last_in_block_message_y = positioned.edges[2].points[0].y

  assert_true(block.y < first_in_block_message_y)
  assert_true(block.y + block.height > last_in_block_message_y)
}

///|
test "Layout sequence base spacing is uniform without blocks" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: First
      #|B->>A: Second
      #|A->>B: Third
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 3)
  let y0 = positioned.edges[0].points[0].y
  let y1 = positioned.edges[1].points[0].y
  let y2 = positioned.edges[2].points[0].y
  assert_eq(y1 - y0, 40)
  assert_eq(y2 - y1, 40)
}

///|
test "Layout sequence spacing after block returns to base row height" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Before
      #|loop Retry
      #|A->>B: Attempt
      #|end
      #|A->>B: After
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 3)
  let y0 = positioned.edges[0].points[0].y
  let y1 = positioned.edges[1].points[0].y
  let y2 = positioned.edges[2].points[0].y
  assert_eq(y1 - y0, 68)
  assert_eq(y2 - y1, 40)
}

///|
test "Layout sequence multiple dividers each add divider extra spacing" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|C->>S: Login
      #|alt Valid
      #|S-->>C: 200
      #|else Invalid
      #|S-->>C: 401
      #|else Locked
      #|S-->>C: 403
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 4)
  let y0 = positioned.edges[0].points[0].y
  let y1 = positioned.edges[1].points[0].y
  let y2 = positioned.edges[2].points[0].y
  let y3 = positioned.edges[3].points[0].y
  assert_eq(y1 - y0, 68)
  assert_eq(y2 - y1, 64)
  assert_eq(y3 - y2, 64)
}

///|
test "Layout sequence par divider spacing matches alt divider spacing" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|G->>A: Validate
      #|par Fetch user
      #|G->>U: Get user
      #|and Fetch orders
      #|G->>O: Get orders
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 3)
  let y0 = positioned.edges[0].points[0].y
  let y1 = positioned.edges[1].points[0].y
  let y2 = positioned.edges[2].points[0].y
  assert_eq(y1 - y0, 68)
  assert_eq(y2 - y1, 64)
}

///|
test "Layout sequence note right of last actor stays within diagram bounds" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Hello
      #|Note right of B: Right-side note
      #|B-->>A: Hi
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  for note in positioned.sequence_notes {
    assert_true(note.x >= 0)
    assert_true(note.x + note.width <= positioned.width)
  }
}

///|
test "Layout sequence note left of first actor stays within diagram bounds" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Hello
      #|Note left of A: Left-side note
      #|B-->>A: Hi
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  for note in positioned.sequence_notes {
    assert_true(note.x >= 0)
    assert_true(note.x + note.width <= positioned.width)
  }
}

///|
test "Layout sequence notes on both sides stay within diagram bounds" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Hello
      #|Note left of A: Left note
      #|Note right of B: Right note
      #|B-->>A: Hi
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_eq(positioned.sequence_notes.length(), 2)
  for note in positioned.sequence_notes {
    assert_true(note.x >= 0)
    assert_true(note.x + note.width <= positioned.width)
  }
}

///|
test "Layout state cycle offsets opposite-direction edge labels" {
  let graph = @parser.parse_mermaid(
    (
      #|stateDiagram-v2
      #|[*] --> Ready
      #|Ready --> Running : start
      #|Running --> Paused : pause
      #|Paused --> Running : resume
      #|Running --> Stopped : stop
      #|Stopped --> [*]
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  let pause_label = label_position_for(positioned.edges, "pause")
  let resumed_label = label_position_for(positioned.edges, "resume")

  match (pause_label, resumed_label) {
    (Some(pause), Some(resumed)) => {
      assert_true(pause.x != resumed.x || pause.y != resumed.y)
      assert_true(
        (pause.x - resumed.x).abs() >= 8 || (pause.y - resumed.y).abs() >= 8,
      )
    }
    _ => fail("missing pause/resume label positions")
  }
}

///|
test "Layout sequence note over actor stays within diagram bounds" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Hello
      #|Note over A: Centered note
      #|B-->>A: Hi
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  for note in positioned.sequence_notes {
    assert_true(note.x >= 0)
    assert_true(note.x + note.width <= positioned.width)
  }
}

///|
test "Layout sequence shift preserves actor message and lifeline alignment" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Hello
      #|Note left of A: This shifts everything
      #|B-->>A: Reply
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  let actor_node : Map[String, PositionedNode] = {}
  for node in positioned.nodes {
    actor_node[node.id] = node
  }

  for edge in positioned.edges {
    match (actor_node.get(edge.source), actor_node.get(edge.target)) {
      (Some(source), Some(target)) => {
        let start_expected = source.x +
          (if target.x > source.x {
            source.width / 2
          } else {
            -source.width / 2
          })
        let end_expected = target.x +
          (if target.x > source.x {
            -target.width / 2
          } else {
            target.width / 2
          })
        assert_eq(edge.points[0].x, start_expected)
        assert_eq(edge.points[edge.points.length() - 1].x, end_expected)
      }
      _ => fail("missing source/target actor in positioned nodes")
    }
  }

  for lifeline in positioned.sequence_lifelines {
    match actor_node.get(lifeline.actor_id) {
      Some(node) => assert_eq(lifeline.x, node.x)
      None => fail("missing actor for lifeline")
    }
  }
}

///|
test "Layout sequence without notes has no extra horizontal shift" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Hello
      #|B-->>A: Hi
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.nodes.length() >= 1)
  let first = positioned.nodes[0]
  let first_left = first.x - first.width / 2
  assert_eq(first_left, resolve_padding(RenderOptions::default()))
}

///|
test "Layout sequence right-side note expands diagram width" {
  let without_note_graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Hello
      #|B-->>A: Hi
      #|
    )
    .trim_end()
    .to_string(),
  )
  let with_note_graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Hello
      #|Note right of B: Extra wide note text here
      #|B-->>A: Hi
      #|
    )
    .trim_end()
    .to_string(),
  )

  let without_note = layout_graph(without_note_graph, RenderOptions::default())
  let with_note = layout_graph(with_note_graph, RenderOptions::default())

  assert_true(with_note.width > without_note.width)
}

///|
test "Layout sequence left-side note shifts actors right" {
  let without_note_graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Hello
      #|B-->>A: Hi
      #|
    )
    .trim_end()
    .to_string(),
  )
  let with_note_graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Hello
      #|Note left of A: Left note
      #|B-->>A: Hi
      #|
    )
    .trim_end()
    .to_string(),
  )

  let without_note = layout_graph(without_note_graph, RenderOptions::default())
  let with_note = layout_graph(with_note_graph, RenderOptions::default())

  assert_true(without_note.nodes.length() >= 1)
  assert_true(with_note.nodes.length() >= 1)
  assert_true(with_note.nodes[0].x > without_note.nodes[0].x)
  assert_true(with_note.sequence_notes.length() >= 1)
  assert_true(with_note.sequence_notes[0].x >= 0)
}

///|
test "Layout sequence opt block header adds extra spacing" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Request
      #|opt Cache available
      #|B-->>A: Cached response
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 2)
  let y0 = positioned.edges[0].points[0].y
  let y1 = positioned.edges[1].points[0].y
  assert_eq(y1 - y0, 68)
}

///|
test "Layout sequence critical block header adds extra spacing" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>DB: BEGIN
      #|critical Transaction
      #|A->>DB: UPDATE
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 2)
  let y0 = positioned.edges[0].points[0].y
  let y1 = positioned.edges[1].points[0].y
  assert_eq(y1 - y0, 68)
}

///|
test "Layout sequence multiple dividers are between corresponding messages" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|C->>S: Login
      #|alt Valid
      #|S-->>C: 200
      #|else Invalid
      #|S-->>C: 401
      #|else Locked
      #|S-->>C: 403
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(block.dividers.length() == 2)
  assert_true(positioned.edges.length() == 4)

  assert_true(block.dividers[0].y > positioned.edges[1].points[0].y)
  assert_true(block.dividers[0].y < positioned.edges[2].points[0].y)
  assert_true(block.dividers[1].y > positioned.edges[2].points[0].y)
  assert_true(block.dividers[1].y < positioned.edges[3].points[0].y)
}

///|
test "Layout sequence divider line stays below previous message arrow" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Login
      #|alt Success
      #|B->>A: 200 OK
      #|else Failure
      #|B->>A: 500 Error
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(block.dividers.length() == 1)
  assert_true(positioned.edges.length() == 3)

  let divider_y = block.dividers[0].y
  let previous_message_y = positioned.edges[1].points[0].y
  assert_true(previous_message_y < divider_y)
  assert_true(divider_y - previous_message_y >= 10)
}

///|
test "Layout sequence three-branch alt keeps header and divider clearance" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|C->>S: Login
      #|alt Valid
      #|S-->>C: 200
      #|else Invalid
      #|S-->>C: 401
      #|else Locked
      #|S-->>C: 403
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(block.dividers.length() == 2)
  assert_true(positioned.edges.length() == 4)

  let tab_bottom = block.y + 18
  let first_in_block_label_y = positioned.edges[1].points[0].y - 6
  assert_true(tab_bottom < first_in_block_label_y)

  for i in 0..<block.dividers.length() {
    let divider = block.dividers[i]
    let message_after = positioned.edges[i + 2]
    let divider_label_bottom = divider.y + 14
    let message_label_y = message_after.points[0].y - 6
    assert_true(divider_label_bottom < message_label_y)
  }

  assert_true(block.dividers[0].y > positioned.edges[1].points[0].y)
  assert_true(block.dividers[1].y > positioned.edges[2].points[0].y)
}

///|
test "Layout sequence long divider labels trigger larger offset" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|participant C as Client
      #|participant S as Server
      #|C->>S: Login
      #|alt Valid credentials
      #|S-->>C: 200 OK
      #|else Account locked
      #|S-->>C: 403 Forbidden
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(block.dividers.length() == 1)
  assert_true(positioned.edges.length() == 3)

  let divider = block.dividers[0]
  let message_after = positioned.edges[2]
  let divider_label_baseline = divider.y + 14
  let message_label_baseline = message_after.points[0].y - 6
  let baseline_clearance = message_label_baseline - divider_label_baseline

  assert_true(baseline_clearance >= 14)
}

///|
test "Layout sequence short divider labels keep default offset" {
  let graph = @parser.parse_mermaid(
    (
      #|sequenceDiagram
      #|A->>B: Login
      #|alt Yes
      #|B->>A: 200
      #|else No
      #|B->>A: 500
      #|end
      #|
    )
    .trim_end()
    .to_string(),
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(block.dividers.length() == 1)
  assert_true(positioned.edges.length() == 3)

  let divider = block.dividers[0]
  let message_after = positioned.edges[2]
  let baseline_clearance = message_after.points[0].y - 6 - (divider.y + 14)

  assert_eq(baseline_clearance, 8)
}
