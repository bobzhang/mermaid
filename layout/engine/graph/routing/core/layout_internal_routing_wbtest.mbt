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
  assert_eq(simplified, [{ x: 0, y: 0 }, { x: 24, y: 0 }, { x: 24, y: 20 }])
}

///|
test "Layout simplify polyline preserves turnback cusp points" {
  let points : Array[Point] = [{ x: 0, y: 0 }, { x: 0, y: 10 }, { x: 0, y: -8 }]
  let simplified = @layout_engine_graph_edge_core.simplify_polyline_points(
    points,
  )
  assert_eq(simplified.length(), 3)
  assert_eq(simplified[1], { x: 0, y: 10 })
}

///|
test "Layout endpoint stubs preserve source fanout boundary separation" {
  let points = @layout_engine_graph_edge_core.apply_endpoint_port_stubs(
    [{ x: 290, y: 155 }, { x: 290, y: 155 }, { x: 344, y: 200 }],
    { x: 290, y: 161 },
    { x: 344, y: 200 },
  )
  assert_eq(points, [{ x: 290, y: 161 }, { x: 344, y: 200 }])
}

///|
test "Layout endpoint stubs preserve reciprocal endpoint separation" {
  let points = @layout_engine_graph_edge_core.apply_endpoint_port_stubs(
    [{ x: 290, y: 155 }, { x: 290, y: 155 }, { x: 360, y: 110 }],
    { x: 290, y: 149 },
    { x: 360, y: 116 },
  )
  assert_eq(points, [{ x: 290, y: 149 }, { x: 360, y: 116 }])
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
