///|
fn point_equals(left : Point, right : Point) -> Bool {
  left.x == right.x && left.y == right.y
}

///|
fn simplify_polyline_points(points : Array[Point]) -> Array[Point] {
  @layout_engine_graph_edge_core.simplify_polyline_points(points)
}

///|
fn edge_points_with_minor_lane_offset_with_ports(
  source : PositionedNode,
  target : PositionedNode,
  horizontal : Bool,
  minor_offset : Int,
  smooth_forward_fanout : Bool,
  source_port_minor_offset : Int,
  target_port_minor_offset : Int,
) -> Array[Point] {
  @layout_engine_graph_edge_core.edge_points_with_minor_lane_offset_with_ports(
    source, target, horizontal, minor_offset, smooth_forward_fanout, source_port_minor_offset,
    target_port_minor_offset,
  )
}

///|
fn apply_context_endpoint_port_stubs(
  points : Array[Point],
  context : EdgeLayoutContext,
) -> Array[Point] {
  let moving_forward = if context.edge_horizontal {
    context.target.x >= context.source.x
  } else {
    context.target.y >= context.source.y
  }
  let source_anchor = @layout_engine_graph_edge_core.boundary_anchor_point(
    context.source,
    context.edge_horizontal,
    true,
    moving_forward,
    context.source_boundary_offset_minor,
  )
  let target_anchor = @layout_engine_graph_edge_core.boundary_anchor_point(
    context.target,
    context.edge_horizontal,
    false,
    moving_forward,
    context.target_boundary_offset_minor,
  )
  @layout_engine_graph_edge_core.apply_endpoint_port_stubs(
    points, source_anchor, target_anchor,
  )
}

///|
fn forward_fanout_offset(slot : Int, total : Int) -> Int {
  if total <= 1 {
    return 0
  }
  let spacing = 16
  let centered = slot * 2 - (total - 1)
  centered * spacing / 2
}
