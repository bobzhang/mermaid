///|
fn flow_edge(source : String, target : String) -> MermaidEdge {
  {
    source,
    target,
    label: None,
    style: Solid,
    has_arrow_start: false,
    has_arrow_end: true,
    relation_operator: Some("-->"),
  }
}

///|
fn flow_node(id : String) -> @model.MermaidNode {
  { id, label: id, shape: Rectangle }
}

///|
fn positioned_box(id : String, x : Int, y : Int) -> PositionedNode {
  {
    id,
    label: id,
    shape: Rectangle,
    x,
    y,
    width: 80,
    height: 40,
    inline_style: None,
  }
}

///|
fn flow_graph_with_edges(edges : Array[MermaidEdge]) -> MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {}
  let node_definition_order : Array[String] = []
  let seen_node_id : Map[String, Bool] = {}
  fn append_node(id : String) -> Unit {
    nodes[id] = flow_node(id)
    if seen_node_id.contains(id) {
      return
    }
    seen_node_id[id] = true
    node_definition_order.push(id)
  }
  for edge in edges {
    append_node(edge.source)
    append_node(edge.target)
  }
  {
    diagram_kind: Flowchart,
    direction: LR,
    nodes,
    node_definition_order,
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
fn wb_point_equal(left : Point, right : Point) -> Bool {
  left.x == right.x && left.y == right.y
}

///|
fn wb_points_equal(left : Array[Point], right : Array[Point]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if !wb_point_equal(left[i], right[i]) {
      return false
    }
  }
  true
}

///|
fn find_context(
  contexts : Array[EdgeLayoutContext],
  source_id : String,
  target_id : String,
) -> EdgeLayoutContext {
  for context in contexts {
    if context.resolved_source_id == source_id &&
      context.resolved_target_id == target_id {
      return context
    }
  }
  contexts[0]
}

///|
fn context_source_anchor(context : EdgeLayoutContext) -> Point {
  let moving_forward = if context.edge_horizontal {
    context.target.x >= context.source.x
  } else {
    context.target.y >= context.source.y
  }
  @layout_engine_graph_edge_core.boundary_anchor_point(
    context.source,
    context.edge_horizontal,
    true,
    moving_forward,
    context.source_boundary_offset_minor,
  )
}

///|
fn context_target_anchor(context : EdgeLayoutContext) -> Point {
  let moving_forward = if context.edge_horizontal {
    context.target.x >= context.source.x
  } else {
    context.target.y >= context.source.y
  }
  @layout_engine_graph_edge_core.boundary_anchor_point(
    context.target,
    context.edge_horizontal,
    false,
    moving_forward,
    context.target_boundary_offset_minor,
  )
}

///|
test "Layout simplify polyline removes duplicate and interior collinear points" {
  let points : Array[Point] = [
    { x: 0, y: 0 },
    { x: 0, y: 0 },
    { x: 12, y: 0 },
    { x: 24, y: 0 },
    { x: 24, y: 10 },
    { x: 24, y: 20 },
  ]
  let simplified = @layout_engine_graph_edge_core.simplify_polyline_points(
    points,
  )
  assert_true(
    wb_points_equal(simplified, [
      { x: 0, y: 0 },
      { x: 24, y: 0 },
      { x: 24, y: 20 },
    ]),
  )
}

///|
test "Layout simplify polyline preserves turnback cusp points" {
  let points : Array[Point] = [{ x: 0, y: 0 }, { x: 0, y: 10 }, { x: 0, y: -8 }]
  let simplified = @layout_engine_graph_edge_core.simplify_polyline_points(
    points,
  )
  assert_eq(simplified.length(), 3)
  assert_true(wb_point_equal(simplified[1], { x: 0, y: 10 }))
}

///|
test "Layout endpoint stubs preserve source fanout boundary separation" {
  let points = @layout_engine_graph_edge_core.apply_endpoint_port_stubs(
    [{ x: 290, y: 155 }, { x: 290, y: 155 }, { x: 344, y: 200 }],
    { x: 290, y: 161 },
    { x: 344, y: 200 },
  )
  assert_true(wb_points_equal(points, [{ x: 290, y: 161 }, { x: 344, y: 200 }]))
}

///|
test "Layout endpoint stubs preserve reciprocal endpoint separation" {
  let points = @layout_engine_graph_edge_core.apply_endpoint_port_stubs(
    [{ x: 290, y: 155 }, { x: 290, y: 155 }, { x: 360, y: 110 }],
    { x: 290, y: 149 },
    { x: 360, y: 116 },
  )
  assert_true(wb_points_equal(points, [{ x: 290, y: 149 }, { x: 360, y: 116 }]))
}

///|
test "Layout back-edge lane selection avoids existing segment crossings" {
  let source : PositionedNode = {
    id: "S",
    label: "S",
    shape: Circle,
    x: 200,
    y: 100,
    width: 24,
    height: 24,
    inline_style: None,
  }
  let target : PositionedNode = {
    id: "T",
    label: "T",
    shape: Circle,
    x: 100,
    y: 100,
    width: 24,
    height: 24,
    inline_style: None,
  }
  let blocker : RoutedEdgeSegment = {
    source_id: "X",
    target_id: "Y",
    start: { x: 140, y: 20 },
    end: { x: 140, y: 80 },
    is_source_stub: false,
    is_target_stub: false,
  }

  let reservations : Array[BackEdgeLaneReservation] = []
  let bend_y = reserve_back_edge_bend_y(
    source,
    target,
    [source, target],
    [blocker],
    reservations,
  )

  assert_eq(bend_y, 138)
  assert_eq(reservations.length(), 1)
  assert_eq(reservations[0].y, 138)
}

///|
test "Layout back-edge lane selection can skip nearest lane for fewer crossings" {
  let source : PositionedNode = {
    id: "S",
    label: "S",
    shape: Circle,
    x: 200,
    y: 100,
    width: 24,
    height: 24,
    inline_style: None,
  }
  let target : PositionedNode = {
    id: "T",
    label: "T",
    shape: Circle,
    x: 100,
    y: 100,
    width: 24,
    height: 24,
    inline_style: None,
  }

  let routed_edge_segments : Array[RoutedEdgeSegment] = [
    {
      source_id: "A",
      target_id: "B",
      start: { x: 140, y: 45 },
      end: { x: 140, y: 75 },
      is_source_stub: false,
      is_target_stub: false,
    },
    {
      source_id: "C",
      target_id: "D",
      start: { x: 160, y: 120 },
      end: { x: 160, y: 150 },
      is_source_stub: false,
      is_target_stub: false,
    },
  ]

  let reservations : Array[BackEdgeLaneReservation] = []
  let bend_y = reserve_back_edge_bend_y(
    source,
    target,
    [source, target],
    routed_edge_segments,
    reservations,
  )

  assert_eq(bend_y, 42)
  assert_eq(reservations.length(), 1)
  assert_eq(reservations[0].y, 42)
}

///|
test "Layout back-edge lane node-box penalty counts intersected nodes" {
  let source : PositionedNode = {
    id: "S",
    label: "S",
    shape: Circle,
    x: 200,
    y: 100,
    width: 24,
    height: 24,
    inline_style: None,
  }
  let target : PositionedNode = {
    id: "T",
    label: "T",
    shape: Circle,
    x: 100,
    y: 100,
    width: 24,
    height: 24,
    inline_style: None,
  }
  let obstacle : PositionedNode = {
    id: "O",
    label: "O",
    shape: Rectangle,
    x: 150,
    y: 58,
    width: 40,
    height: 24,
    inline_style: None,
  }

  let blocked = back_edge_lane_node_box_penalty(
    [source, target, obstacle],
    source,
    target,
    source.x - source.width / 2,
    source.y,
    target.x + target.width / 2,
    target.y,
    58,
  )
  let clear = back_edge_lane_node_box_penalty(
    [source, target, obstacle],
    source,
    target,
    source.x - source.width / 2,
    source.y,
    target.x + target.width / 2,
    target.y,
    38,
  )

  assert_eq(blocked, 1)
  assert_eq(clear, 0)
}

///|
test "Layout back-edge column node-box penalty counts intersected nodes" {
  let source : PositionedNode = {
    id: "S",
    label: "S",
    shape: Circle,
    x: 100,
    y: 200,
    width: 24,
    height: 24,
    inline_style: None,
  }
  let target : PositionedNode = {
    id: "T",
    label: "T",
    shape: Circle,
    x: 100,
    y: 100,
    width: 24,
    height: 24,
    inline_style: None,
  }
  let obstacle : PositionedNode = {
    id: "O",
    label: "O",
    shape: Rectangle,
    x: 58,
    y: 150,
    width: 24,
    height: 48,
    inline_style: None,
  }

  let blocked = back_edge_column_node_box_penalty(
    [source, target, obstacle],
    source,
    target,
    source.x,
    source.y - source.height / 2,
    target.x,
    target.y + target.height / 2,
    58,
  )
  let clear = back_edge_column_node_box_penalty(
    [source, target, obstacle],
    source,
    target,
    source.x,
    source.y - source.height / 2,
    target.x,
    target.y + target.height / 2,
    38,
  )

  assert_eq(blocked, 1)
  assert_eq(clear, 0)
}

///|
test "Layout back-edge lane score prefers fewer crossings over side congestion" {
  assert_true(back_edge_lane_score_is_better(0, 1, 80, 3, 1, 0, 2, 20, 0, 0))
}

///|
test "Layout back-edge lane score uses node-box avoidance as crossing tie-breaker" {
  assert_true(back_edge_lane_score_is_better(0, 2, 20, 0, 0, 1, 2, 20, 0, 1))
}

///|
test "Layout long-span back-edge lane search can use extended candidates" {
  let source : PositionedNode = {
    id: "S",
    label: "S",
    shape: Circle,
    x: 700,
    y: 100,
    width: 24,
    height: 24,
    inline_style: None,
  }
  let target : PositionedNode = {
    id: "T",
    label: "T",
    shape: Circle,
    x: 100,
    y: 100,
    width: 24,
    height: 24,
    inline_style: None,
  }

  let reservations : Array[BackEdgeLaneReservation] = []
  for blocked_y in [58, 40, 22] {
    reservations.push({ left: 112, right: 688, y: blocked_y })
  }

  let routed_edge_segments : Array[RoutedEdgeSegment] = [
    {
      source_id: "U",
      target_id: "V",
      start: { x: 400, y: 120 },
      end: { x: 400, y: 260 },
      is_source_stub: false,
      is_target_stub: false,
    },
  ]

  let bend_y = reserve_back_edge_bend_y(
    source,
    target,
    [source, target],
    routed_edge_segments,
    reservations,
  )

  assert_eq(bend_y, 62)
  assert_eq(reservations.length(), 4)
  assert_eq(reservations[3].y, 62)
}

///|
test "Layout mid-long span back-edge lane search upgrades to dense candidate spacing" {
  let source : PositionedNode = {
    id: "S",
    label: "S",
    shape: Circle,
    x: 580,
    y: 100,
    width: 24,
    height: 24,
    inline_style: None,
  }
  let target : PositionedNode = {
    id: "T",
    label: "T",
    shape: Circle,
    x: 100,
    y: 100,
    width: 24,
    height: 24,
    inline_style: None,
  }

  let reservations : Array[BackEdgeLaneReservation] = []
  for
    blocked_y in [
      58, 40, 38, 22, 18, 142, 160, 162, 178, 182, 196, 202, 214, 222, 232, 242,
      262,
    ] {
    reservations.push({ left: 112, right: 568, y: blocked_y })
  }
  let routed_edge_segments : Array[RoutedEdgeSegment] = [
    {
      source_id: "U",
      target_id: "V",
      start: { x: 300, y: 236 },
      end: { x: 300, y: 246 },
      is_source_stub: false,
      is_target_stub: false,
    },
  ]

  let bend_y = reserve_back_edge_bend_y(
    source,
    target,
    [source, target],
    routed_edge_segments,
    reservations,
  )

  assert_eq(bend_y, 62)
  assert_eq(reservations.length(), 18)
  assert_eq(reservations[17].y, 62)
}

///|
test "Layout polyline crossing count ignores shared endpoints" {
  let left : Array[Point] = [{ x: 0, y: 0 }, { x: 10, y: 10 }]
  let right : Array[Point] = [{ x: 0, y: 0 }, { x: 10, y: 0 }, { x: 0, y: 10 }]

  assert_eq(count_polyline_crossings([left, right]), 0)
}

///|
test "Layout polyline crossing count counts each pair at most once" {
  let left : Array[Point] = [{ x: 0, y: 0 }, { x: 10, y: 10 }, { x: 0, y: 20 }]
  let right : Array[Point] = [
    { x: 10, y: 0 },
    { x: 0, y: 10 },
    { x: 10, y: 20 },
  ]

  assert_eq(count_polyline_crossings([left, right]), 1)
}

///|
test "Layout deferred minor-axis key uses y for horizontal edges" {
  let source : PositionedNode = {
    id: "S",
    label: "S",
    shape: Rectangle,
    x: 40,
    y: 120,
    width: 80,
    height: 40,
    inline_style: None,
  }
  let target : PositionedNode = {
    id: "T",
    label: "T",
    shape: Rectangle,
    x: 260,
    y: 60,
    width: 80,
    height: 40,
    inline_style: None,
  }
  let context : EdgeLayoutContext = {
    edge: flow_edge("S", "T"),
    resolved_source_id: "S",
    resolved_target_id: "T",
    source,
    target,
    edge_horizontal: true,
    compact_endpoint_port_priority: false,
    source_boundary_cohort_size: 0,
    source_boundary_offset_minor: 0,
    target_boundary_offset_minor: 0,
  }

  assert_eq(deferred_back_edge_minor_axis_key(context, 0), 120)
  assert_eq(deferred_back_edge_minor_axis_key(context, 1), 60)
  assert_eq(deferred_back_edge_minor_axis_key(context, 2), 180)
}

///|
test "Layout deferred minor-axis key uses x for vertical edges" {
  let source : PositionedNode = {
    id: "S",
    label: "S",
    shape: Rectangle,
    x: 30,
    y: 240,
    width: 80,
    height: 40,
    inline_style: None,
  }
  let target : PositionedNode = {
    id: "T",
    label: "T",
    shape: Rectangle,
    x: 150,
    y: 40,
    width: 80,
    height: 40,
    inline_style: None,
  }
  let context : EdgeLayoutContext = {
    edge: flow_edge("S", "T"),
    resolved_source_id: "S",
    resolved_target_id: "T",
    source,
    target,
    edge_horizontal: false,
    compact_endpoint_port_priority: false,
    source_boundary_cohort_size: 0,
    source_boundary_offset_minor: 0,
    target_boundary_offset_minor: 0,
  }

  assert_eq(deferred_back_edge_minor_axis_key(context, 0), 30)
  assert_eq(deferred_back_edge_minor_axis_key(context, 1), 150)
  assert_eq(deferred_back_edge_minor_axis_key(context, 2), 180)
}

///|
test "Layout boundary offsets keep source fanout separation on large graphs" {
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B1"),
    flow_edge("A", "B2"),
    flow_edge("A", "B3"),
  ]
  for i in 0..<21 {
    edges.push(flow_edge("F\{i}", "F\{i + 1}"))
  }
  let graph = flow_graph_with_edges(edges)
  assert_true(graph.edges.length() > 20)

  let positioned_by_id : Map[String, PositionedNode] = {}
  let node_horizontal_by_id : Map[String, Bool] = {}
  positioned_by_id["A"] = positioned_box("A", 100, 100)
  positioned_by_id["B1"] = positioned_box("B1", 300, 40)
  positioned_by_id["B2"] = positioned_box("B2", 300, 100)
  positioned_by_id["B3"] = positioned_box("B3", 300, 160)
  node_horizontal_by_id["A"] = true
  node_horizontal_by_id["B1"] = true
  node_horizontal_by_id["B2"] = true
  node_horizontal_by_id["B3"] = true
  for i in 0..<=21 {
    let node_id = "F\{i}"
    positioned_by_id[node_id] = positioned_box(
      node_id,
      40 + i * 22,
      260 + i % 2 * 40,
    )
    node_horizontal_by_id[node_id] = true
  }

  let (contexts, _) = collect_edge_layout_contexts(
    graph,
    true,
    false,
    {},
    {},
    positioned_by_id,
    node_horizontal_by_id,
  )
  assign_edge_boundary_offsets_to_contexts(graph, false, false, false, contexts)

  let fanout_offsets : Map[Int, Bool] = {}
  for context in contexts {
    if context.resolved_source_id == "A" {
      fanout_offsets[context.source_boundary_offset_minor] = true
    }
  }
  assert_eq(fanout_offsets.length(), 3)
}

///|
test "Layout compact cohort assignment can rebalance preassigned source offsets" {
  let source = positioned_box("A", 100, 100)
  let target_1 = positioned_box("B1", 300, 40)
  let target_2 = positioned_box("B2", 300, 100)
  let target_3 = positioned_box("B3", 300, 160)
  let contexts : Array[EdgeLayoutContext] = [
    {
      edge: flow_edge("A", "B1"),
      resolved_source_id: "A",
      resolved_target_id: "B1",
      source,
      target: target_1,
      edge_horizontal: true,
      compact_endpoint_port_priority: true,
      source_boundary_cohort_size: 0,
      source_boundary_offset_minor: 0,
      target_boundary_offset_minor: 0,
    },
    {
      edge: flow_edge("A", "B2"),
      resolved_source_id: "A",
      resolved_target_id: "B2",
      source,
      target: target_2,
      edge_horizontal: true,
      compact_endpoint_port_priority: true,
      source_boundary_cohort_size: 0,
      source_boundary_offset_minor: 0,
      target_boundary_offset_minor: 0,
    },
    {
      edge: flow_edge("A", "B3"),
      resolved_source_id: "A",
      resolved_target_id: "B3",
      source,
      target: target_3,
      edge_horizontal: true,
      compact_endpoint_port_priority: true,
      source_boundary_cohort_size: 0,
      source_boundary_offset_minor: 0,
      target_boundary_offset_minor: 0,
    },
  ]
  let cohort_assignments : Array[BoundaryEndpointAssignment] = [
    {
      context_index: 0,
      source_endpoint: true,
      side: Right,
      peer_major: target_1.x,
      peer_minor: target_1.y,
      edge_span: edge_layout_context_span(contexts[0]),
    },
    {
      context_index: 1,
      source_endpoint: true,
      side: Right,
      peer_major: target_2.x,
      peer_minor: target_2.y,
      edge_span: edge_layout_context_span(contexts[1]),
    },
    {
      context_index: 2,
      source_endpoint: true,
      side: Right,
      peer_major: target_3.x,
      peer_minor: target_3.y,
      edge_span: edge_layout_context_span(contexts[2]),
    },
  ]
  let preserved_offsets : Map[Int, Int] = { 0: 0 }
  assign_compact_boundary_offsets_for_cohort(
    cohort_assignments, contexts, true, preserved_offsets, true,
  )
  assert_eq(option_int_or(preserved_offsets.get(0), -999), 0)

  let rebalanced_offsets : Map[Int, Int] = { 0: 0 }
  assign_compact_boundary_offsets_for_cohort(
    cohort_assignments, contexts, true, rebalanced_offsets, false,
  )
  assert_true(option_int_or(rebalanced_offsets.get(0), 0) != 0)
  let unique_offsets : Map[Int, Bool] = {}
  for _, offset in rebalanced_offsets {
    unique_offsets[offset] = true
  }
  assert_eq(unique_offsets.length(), 3)
}

///|
test "Layout boundary offsets keep reciprocal and fanout anchors separated on flow pattern" {
  let edges : Array[MermaidEdge] = [
    flow_edge("Start", "Check"),
    flow_edge("Check", "Build"),
    flow_edge("Check", "Fix"),
    flow_edge("Fix", "Check"),
    flow_edge("Build", "Ship"),
  ]
  let graph = flow_graph_with_edges(edges)
  let positioned_by_id : Map[String, PositionedNode] = {
    "Start": positioned_box("Start", 80, 100),
    "Check": positioned_box("Check", 200, 100),
    "Build": positioned_box("Build", 380, 60),
    "Fix": positioned_box("Fix", 380, 140),
    "Ship": positioned_box("Ship", 520, 60),
  }
  let node_horizontal_by_id : Map[String, Bool] = {
    "Start": true,
    "Check": true,
    "Build": true,
    "Fix": true,
    "Ship": true,
  }
  let (contexts, _) = collect_edge_layout_contexts(
    graph,
    true,
    false,
    {},
    {},
    positioned_by_id,
    node_horizontal_by_id,
  )
  assign_edge_boundary_offsets_to_contexts(graph, false, false, true, contexts)

  let check_build = find_context(contexts, "Check", "Build")
  let check_fix = find_context(contexts, "Check", "Fix")
  let start_check = find_context(contexts, "Start", "Check")
  let fix_check = find_context(contexts, "Fix", "Check")

  assert_eq(check_build.source_boundary_cohort_size, 2)
  assert_eq(check_fix.source_boundary_cohort_size, 2)
  assert_true(
    check_build.source_boundary_offset_minor !=
    check_fix.source_boundary_offset_minor,
  )

  let start_check_target_anchor = context_target_anchor(start_check)
  let fix_check_target_anchor = context_target_anchor(fix_check)
  assert_true(
    !wb_point_equal(start_check_target_anchor, fix_check_target_anchor),
  )

  let check_build_source_anchor = context_source_anchor(check_build)
  let check_fix_source_anchor = context_source_anchor(check_fix)
  assert_true(
    !wb_point_equal(check_build_source_anchor, check_fix_source_anchor),
  )
}
