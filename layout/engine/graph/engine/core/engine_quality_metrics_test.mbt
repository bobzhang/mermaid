///|
fn qm_node(id : String) -> @model.MermaidNode {
  { id, label: id, shape: Rectangle }
}

///|
fn qm_edge(
  source : String,
  target : String,
  label : String?,
) -> @model.MermaidEdge {
  {
    source,
    target,
    label,
    style: Solid,
    has_arrow_start: false,
    has_arrow_end: true,
    relation_operator: Some("-->"),
  }
}

///|
fn qm_graph() -> @model.MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {
    "A": qm_node("A"),
    "B": qm_node("B"),
    "C": qm_node("C"),
    "D": qm_node("D"),
    "E": qm_node("E"),
    "F": qm_node("F"),
    "G": qm_node("G"),
    "H": qm_node("H"),
  }
  let edges : Array[@model.MermaidEdge] = [
    qm_edge("A", "C", Some("ac")),
    qm_edge("A", "D", Some("ad")),
    qm_edge("B", "D", Some("bd")),
    qm_edge("B", "E", Some("be")),
    qm_edge("C", "F", Some("cf")),
    qm_edge("D", "F", Some("df")),
    qm_edge("D", "G", Some("dg")),
    qm_edge("E", "G", Some("eg")),
    qm_edge("F", "H", Some("fh")),
    qm_edge("G", "H", Some("gh")),
    qm_edge("H", "B", Some("hb")),
    qm_edge("G", "C", Some("gc")),
  ]
  {
    diagram_kind: Flowchart,
    direction: LR,
    nodes,
    edges,
    subgraphs: [],
    class_defs: {},
    class_assignments: {},
    node_styles: {},
    sequence_actor_order: [],
    sequence_actor_kinds: {},
    sequence_blocks: [],
    sequence_notes: [],
    sequence_activation_commands: [],
  }
}

///|
priv struct QmSegment {
  edge_index : Int
  p1 : @model.Point
  p2 : @model.Point
}

///|
fn qm_segments(graph : @model.PositionedGraph) -> Array[QmSegment] {
  let segments : Array[QmSegment] = []
  for edge_index, edge in graph.edges {
    if edge.points.length() < 2 {
      continue
    }
    let segment_count = edge.points.length() - 1
    for i in 0..<segment_count {
      segments.push({ edge_index, p1: edge.points[i], p2: edge.points[i + 1] })
    }
  }
  segments
}

///|
fn qm_sign(value : Int) -> Int {
  if value < 0 {
    -1
  } else if value > 0 {
    1
  } else {
    0
  }
}

///|
fn qm_orientation(a : @model.Point, b : @model.Point, c : @model.Point) -> Int {
  qm_sign((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x))
}

///|
fn qm_in_range(value : Int, bound1 : Int, bound2 : Int) -> Bool {
  if bound1 <= bound2 {
    value >= bound1 && value <= bound2
  } else {
    value >= bound2 && value <= bound1
  }
}

///|
fn qm_on_segment(a : @model.Point, b : @model.Point, c : @model.Point) -> Bool {
  qm_orientation(a, b, c) == 0 &&
  qm_in_range(c.x, a.x, b.x) &&
  qm_in_range(c.y, a.y, b.y)
}

///|
fn qm_same_point(a : @model.Point, b : @model.Point) -> Bool {
  a.x == b.x && a.y == b.y
}

///|
fn qm_segments_intersect(a : QmSegment, b : QmSegment) -> Bool {
  if a.edge_index == b.edge_index {
    return false
  }
  if qm_same_point(a.p1, b.p1) ||
    qm_same_point(a.p1, b.p2) ||
    qm_same_point(a.p2, b.p1) ||
    qm_same_point(a.p2, b.p2) {
    return false
  }

  let o1 = qm_orientation(a.p1, a.p2, b.p1)
  let o2 = qm_orientation(a.p1, a.p2, b.p2)
  let o3 = qm_orientation(b.p1, b.p2, a.p1)
  let o4 = qm_orientation(b.p1, b.p2, a.p2)
  if o1 != o2 && o3 != o4 {
    return true
  }

  if o1 == 0 && qm_on_segment(a.p1, a.p2, b.p1) {
    return true
  }
  if o2 == 0 && qm_on_segment(a.p1, a.p2, b.p2) {
    return true
  }
  if o3 == 0 && qm_on_segment(b.p1, b.p2, a.p1) {
    return true
  }
  if o4 == 0 && qm_on_segment(b.p1, b.p2, a.p2) {
    return true
  }
  false
}

///|
fn qm_crossings(graph : @model.PositionedGraph) -> Int {
  let segments = qm_segments(graph)
  let mut crossings = 0
  for i in 0..<segments.length() {
    let mut j = i + 1
    while j < segments.length() {
      if qm_segments_intersect(segments[i], segments[j]) {
        crossings += 1
      }
      j = j + 1
    }
  }
  crossings
}

///|
fn qm_edge_manhattan_length(graph : @model.PositionedGraph) -> Int {
  let mut total = 0
  for edge in graph.edges {
    if edge.points.length() < 2 {
      continue
    }
    let segment_count = edge.points.length() - 1
    for i in 0..<segment_count {
      total += (edge.points[i + 1].x - edge.points[i].x).abs() +
        (edge.points[i + 1].y - edge.points[i].y).abs()
    }
  }
  total
}

///|
fn qm_area(graph : @model.PositionedGraph) -> Int {
  graph.width * graph.height
}

///|
test "quality metrics are stable and backend-comparable on stress graph" {
  let graph = qm_graph()
  let options = @model.RenderOptions::default()
  let legacy = dispatch_graph_layout_engine(graph, options, true, false, Legacy)
  let dagre = dispatch_graph_layout_engine(
    graph,
    options,
    true,
    false,
    DagreParity,
  )
  let elk = dispatch_graph_layout_engine(graph, options, true, false, Elk)

  let legacy_crossings = qm_crossings(legacy)
  let dagre_crossings = qm_crossings(dagre)
  let elk_crossings = qm_crossings(elk)

  let legacy_length = qm_edge_manhattan_length(legacy)
  let dagre_length = qm_edge_manhattan_length(dagre)
  let elk_length = qm_edge_manhattan_length(elk)

  let legacy_area = qm_area(legacy)
  let dagre_area = qm_area(dagre)
  let elk_area = qm_area(elk)

  assert_true(legacy_crossings >= 0)
  assert_true(dagre_crossings >= 0)
  assert_true(elk_crossings >= 0)
  assert_true(legacy_length > 0)
  assert_true(dagre_length > 0)
  assert_true(elk_length > 0)
  assert_true(legacy_area > 0)
  assert_true(dagre_area > 0)
  assert_true(elk_area > 0)

  assert_true(dagre_crossings <= legacy_crossings + 2)
  assert_true(elk_crossings <= dagre_crossings + 2)
}
