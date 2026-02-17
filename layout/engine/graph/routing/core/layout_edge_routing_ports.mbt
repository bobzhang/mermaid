///|
fn point_equals(left : Point, right : Point) -> Bool {
  left.x == right.x && left.y == right.y
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
