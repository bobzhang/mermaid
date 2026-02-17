///|
fn rectangular_boundary_anchor_point(
  node : PositionedNode,
  horizontal : Bool,
  source_endpoint : Bool,
  moving_forward : Bool,
  minor_offset : Int,
) -> Point {
  if horizontal {
    let clamped_minor = clamp_minor_boundary_offset(node, true, minor_offset)
    let delta_x = if source_endpoint {
      if moving_forward {
        node.width / 2
      } else {
        -node.width / 2
      }
    } else if moving_forward {
      -node.width / 2
    } else {
      node.width / 2
    }
    { x: node.x + delta_x, y: node.y + clamped_minor }
  } else {
    let clamped_minor = clamp_minor_boundary_offset(node, false, minor_offset)
    let delta_y = if source_endpoint {
      if moving_forward {
        node.height / 2
      } else {
        -node.height / 2
      }
    } else if moving_forward {
      -node.height / 2
    } else {
      node.height / 2
    }
    { x: node.x + clamped_minor, y: node.y + delta_y }
  }
}

///|
fn boundary_anchor_point(
  source : PositionedNode,
  horizontal : Bool,
  source_endpoint : Bool,
  moving_forward : Bool,
  minor_offset : Int,
) -> Point {
  let polygon = boundary_polygon_points(source)
  if horizontal {
    let side_is_right = if source_endpoint {
      moving_forward
    } else {
      !moving_forward
    }
    let clamped_minor = clamp_minor_boundary_offset(source, true, minor_offset)
    let y = source.y + clamped_minor
    match polygon {
      Some(points) =>
        match polygon_boundary_x_for_y(points, y, side_is_right) {
          Some(x) => return { x, y }
          None => ()
        }
      None => ()
    }
    rectangular_boundary_anchor_point(
      source, horizontal, source_endpoint, moving_forward, minor_offset,
    )
  } else {
    let side_is_bottom = if source_endpoint {
      moving_forward
    } else {
      !moving_forward
    }
    let clamped_minor = clamp_minor_boundary_offset(source, false, minor_offset)
    let x = source.x + clamped_minor
    match polygon {
      Some(points) =>
        match polygon_boundary_y_for_x(points, x, side_is_bottom) {
          Some(y) => return { x, y }
          None => ()
        }
      None => ()
    }
    rectangular_boundary_anchor_point(
      source, horizontal, source_endpoint, moving_forward, minor_offset,
    )
  }
}

///|
fn boundary_anchor_prefers_direct_base(node : PositionedNode) -> Bool {
  boundary_polygon_points(node) is Some(_)
}

///|
fn point_equals(left : Point, right : Point) -> Bool {
  left.x == right.x && left.y == right.y
}

///|
fn point_is_between_on_axis(value : Int, left : Int, right : Int) -> Bool {
  let min_value = left.min(right)
  let max_value = left.max(right)
  value >= min_value && value <= max_value
}

///|
fn point_collinear(first : Point, middle : Point, last : Point) -> Bool {
  let cross = (middle.x - first.x) * (last.y - first.y) -
    (middle.y - first.y) * (last.x - first.x)
  if cross != 0 {
    return false
  }
  point_is_between_on_axis(middle.x, first.x, last.x) &&
  point_is_between_on_axis(middle.y, first.y, last.y)
}

///|
fn simplify_polyline_points(points : Array[Point]) -> Array[Point] {
  let simplified : Array[Point] = []
  for point in points {
    if simplified.length() == 0 ||
      !point_equals(simplified[simplified.length() - 1], point) {
      simplified.push(point)
    }
    while simplified.length() >= 3 {
      let first = simplified[simplified.length() - 3]
      let middle = simplified[simplified.length() - 2]
      let last = simplified[simplified.length() - 1]
      if point_collinear(first, middle, last) {
        let _ = simplified.remove(simplified.length() - 2)
      } else {
        break
      }
    }
  }
  simplified
}

///|
fn shift_endpoint_boundary_run_to_anchor(
  points : Array[Point],
  anchor : Point,
  source_endpoint : Bool,
) -> Unit {
  if points.length() == 0 {
    return
  }
  let endpoint_index = if source_endpoint { 0 } else { points.length() - 1 }
  let endpoint = points[endpoint_index]
  let delta_x = anchor.x - endpoint.x
  let delta_y = anchor.y - endpoint.y
  if delta_x == 0 && delta_y == 0 {
    return
  }
  if delta_x != 0 && delta_y != 0 {
    return
  }
  points[endpoint_index] = anchor
}

///|
fn apply_endpoint_port_stubs(
  core_points : Array[Point],
  source_anchor : Point,
  target_anchor : Point,
) -> Array[Point] {
  if core_points.length() == 0 {
    if point_equals(source_anchor, target_anchor) {
      [source_anchor]
    } else {
      [source_anchor, target_anchor]
    }
  } else {
    let routed_points : Array[Point] = []
    for point in core_points {
      if routed_points.length() == 0 ||
        !point_equals(routed_points[routed_points.length() - 1], point) {
        routed_points.push(point)
      }
    }
    shift_endpoint_boundary_run_to_anchor(routed_points, source_anchor, true)
    shift_endpoint_boundary_run_to_anchor(routed_points, target_anchor, false)
    let final_points : Array[Point] = []
    if !point_equals(source_anchor, routed_points[0]) {
      final_points.push(source_anchor)
    }
    for point in routed_points {
      if final_points.length() == 0 ||
        !point_equals(final_points[final_points.length() - 1], point) {
        final_points.push(point)
      }
    }
    if !point_equals(target_anchor, final_points[final_points.length() - 1]) {
      final_points.push(target_anchor)
    }
    simplify_polyline_points(final_points)
  }
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
  if horizontal {
    let moving_right = target.x >= source.x
    let start_anchor = boundary_anchor_point(
      source, true, true, moving_right, source_port_minor_offset,
    )
    let start_base = if boundary_anchor_prefers_direct_base(source) {
      start_anchor
    } else {
      boundary_anchor_point(source, true, true, moving_right, 0)
    }
    let end_anchor = boundary_anchor_point(
      target, true, false, moving_right, target_port_minor_offset,
    )
    let end_base = if boundary_anchor_prefers_direct_base(target) {
      end_anchor
    } else {
      boundary_anchor_point(target, true, false, moving_right, 0)
    }
    let lane_y = source.y + minor_offset
    if smooth_forward_fanout {
      let mid_x = (start_base.x + end_base.x) / 2
      return apply_endpoint_port_stubs(
        [start_base, { x: mid_x, y: lane_y }, end_base],
        start_anchor,
        end_anchor,
      )
    }
    return apply_endpoint_port_stubs(
      [
        start_base,
        { x: start_base.x, y: lane_y },
        { x: end_base.x, y: lane_y },
        end_base,
      ],
      start_anchor,
      end_anchor,
    )
  }

  let moving_down = target.y >= source.y
  let start_anchor = boundary_anchor_point(
    source, false, true, moving_down, source_port_minor_offset,
  )
  let start_base = if boundary_anchor_prefers_direct_base(source) {
    start_anchor
  } else {
    boundary_anchor_point(source, false, true, moving_down, 0)
  }
  let end_anchor = boundary_anchor_point(
    target, false, false, moving_down, target_port_minor_offset,
  )
  let end_base = if boundary_anchor_prefers_direct_base(target) {
    end_anchor
  } else {
    boundary_anchor_point(target, false, false, moving_down, 0)
  }
  let lane_x = source.x + minor_offset
  apply_endpoint_port_stubs(
    [
      start_base,
      { x: lane_x, y: start_base.y },
      { x: lane_x, y: end_base.y },
      end_base,
    ],
    start_anchor,
    end_anchor,
  )
}

///|
fn edge_points_for_with_ports(
  source : PositionedNode,
  target : PositionedNode,
  horizontal : Bool,
  back_edge_bend_y : Int?,
  back_edge_bend_x : Int?,
  forward_fanout_offset_y : Int?,
  smooth_forward_fanout : Bool,
  source_port_minor_offset : Int,
  target_port_minor_offset : Int,
) -> Array[Point] {
  if horizontal {
    let moving_right = target.x >= source.x
    let start_anchor = boundary_anchor_point(
      source, true, true, moving_right, source_port_minor_offset,
    )
    let start_base = if boundary_anchor_prefers_direct_base(source) {
      start_anchor
    } else {
      boundary_anchor_point(source, true, true, moving_right, 0)
    }
    let end_anchor = boundary_anchor_point(
      target, true, false, moving_right, target_port_minor_offset,
    )
    let end_base = if boundary_anchor_prefers_direct_base(target) {
      end_anchor
    } else {
      boundary_anchor_point(target, true, false, moving_right, 0)
    }
    match back_edge_bend_y {
      Some(bend_y) =>
        if !moving_right {
          return apply_endpoint_port_stubs(
            [
              start_base,
              { x: start_base.x, y: bend_y },
              { x: end_base.x, y: bend_y },
              end_base,
            ],
            start_anchor,
            end_anchor,
          )
        }
      None => ()
    }
    match forward_fanout_offset_y {
      Some(offset_y) =>
        if moving_right && offset_y != 0 {
          return edge_points_with_minor_lane_offset_with_ports(
            source, target, true, offset_y, smooth_forward_fanout, source_port_minor_offset,
            target_port_minor_offset,
          )
        }
      None => ()
    }
    if smooth_forward_fanout && moving_right && start_base.y != end_base.y {
      let mid_x = (start_base.x + end_base.x) / 2
      return apply_endpoint_port_stubs(
        [start_base, { x: mid_x, y: end_base.y }, end_base],
        start_anchor,
        end_anchor,
      )
    }
    apply_endpoint_port_stubs([start_base, end_base], start_anchor, end_anchor)
  } else {
    let moving_down = target.y >= source.y
    let start_anchor = boundary_anchor_point(
      source, false, true, moving_down, source_port_minor_offset,
    )
    let start_base = if boundary_anchor_prefers_direct_base(source) {
      start_anchor
    } else {
      boundary_anchor_point(source, false, true, moving_down, 0)
    }
    let end_anchor = boundary_anchor_point(
      target, false, false, moving_down, target_port_minor_offset,
    )
    let end_base = if boundary_anchor_prefers_direct_base(target) {
      end_anchor
    } else {
      boundary_anchor_point(target, false, false, moving_down, 0)
    }
    match back_edge_bend_x {
      Some(bend_x) =>
        if !moving_down {
          return apply_endpoint_port_stubs(
            [
              start_base,
              { x: bend_x, y: start_base.y },
              { x: bend_x, y: end_base.y },
              end_base,
            ],
            start_anchor,
            end_anchor,
          )
        }
      None => ()
    }
    match forward_fanout_offset_y {
      Some(offset_x) =>
        if moving_down && offset_x != 0 {
          return edge_points_with_minor_lane_offset_with_ports(
            source, target, false, offset_x, smooth_forward_fanout, source_port_minor_offset,
            target_port_minor_offset,
          )
        }
      None => ()
    }
    apply_endpoint_port_stubs([start_base, end_base], start_anchor, end_anchor)
  }
}

///|
fn edge_points_for(
  source : PositionedNode,
  target : PositionedNode,
  horizontal : Bool,
  back_edge_bend_y : Int?,
  back_edge_bend_x : Int?,
  forward_fanout_offset_y : Int?,
  smooth_forward_fanout : Bool,
) -> Array[Point] {
  edge_points_for_with_ports(
    source, target, horizontal, back_edge_bend_y, back_edge_bend_x, forward_fanout_offset_y,
    smooth_forward_fanout, 0, 0,
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
  let source_anchor = boundary_anchor_point(
    context.source,
    context.edge_horizontal,
    true,
    moving_forward,
    context.source_boundary_offset_minor,
  )
  let target_anchor = boundary_anchor_point(
    context.target,
    context.edge_horizontal,
    false,
    moving_forward,
    context.target_boundary_offset_minor,
  )
  apply_endpoint_port_stubs(points, source_anchor, target_anchor)
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
