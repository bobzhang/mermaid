///|
fn boundary_side_minor_limit(
  node : PositionedNode,
  side_is_vertical : Bool,
) -> Int {
  if side_is_vertical {
    (node.height / 2 - 6).max(0)
  } else {
    (node.width / 2 - 6).max(0)
  }
}

///|
priv struct BackEdgeLaneReservation {
  left : Int
  right : Int
  y : Int
}

///|
priv struct BackEdgeColumnReservation {
  top : Int
  bottom : Int
  x : Int
}

///|
priv struct EdgeLayoutContext {
  edge : MermaidEdge
  resolved_source_id : String
  resolved_target_id : String
  source : PositionedNode
  target : PositionedNode
  edge_horizontal : Bool
  compact_endpoint_port_priority : Bool
  source_boundary_cohort_size : Int
  source_boundary_offset_minor : Int
  target_boundary_offset_minor : Int
}

///|
priv enum NodeBoundarySide {
  Left
  Right
  Top
  Bottom
}

///|
priv struct BoundaryEndpointAssignment {
  context_index : Int
  source_endpoint : Bool
  side : NodeBoundarySide
  peer_major : Int
  peer_minor : Int
  edge_span : Int
}

///|
priv struct RoutedEdgeSegment {
  source_id : String
  target_id : String
  start : Point
  end : Point
  is_source_stub : Bool
  is_target_stub : Bool
}

///|
priv struct RoutedLabelBox {
  left : Int
  right : Int
  top : Int
  bottom : Int
}

///|
fn edge_layout_context_span(context : EdgeLayoutContext) -> Int {
  if context.edge_horizontal {
    int_abs(context.target.x - context.source.x)
  } else {
    int_abs(context.target.y - context.source.y)
  }
}

///|
fn boundary_side_key(side : NodeBoundarySide) -> String {
  match side {
    Left => "L"
    Right => "R"
    Top => "T"
    Bottom => "B"
  }
}

///|
fn boundary_bucket_key(node_id : String, side : NodeBoundarySide) -> String {
  "\{node_id}:\{boundary_side_key(side)}"
}

///|
fn opposite_boundary_side(side : NodeBoundarySide) -> NodeBoundarySide {
  match side {
    Left => Right
    Right => Left
    Top => Bottom
    Bottom => Top
  }
}

///|
fn boundary_side_is_horizontal(side : NodeBoundarySide) -> Bool {
  side is (Left | Right)
}

///|
fn context_source_boundary_side(
  context : EdgeLayoutContext,
) -> NodeBoundarySide {
  if context.edge_horizontal {
    if context.target.x >= context.source.x {
      Right
    } else {
      Left
    }
  } else if context.target.y >= context.source.y {
    Bottom
  } else {
    Top
  }
}

///|
fn boundary_side_minor_span_limit(
  node : PositionedNode,
  side : NodeBoundarySide,
) -> Int {
  match side {
    Left | Right => boundary_side_minor_limit(node, true)
    Top | Bottom => boundary_side_minor_limit(node, false)
  }
}

///|
fn distributed_boundary_port_offset(
  slot : Int,
  total : Int,
  half_span_limit : Int,
) -> Int {
  if total <= 1 || half_span_limit <= 0 {
    return 0
  }
  let max_span = half_span_limit * 2
  let min_step = 2
  // Spread ports to use more of the boundary when space allows, while keeping
  // a cap so long edges do not over-detour on large nodes.
  let max_step = max_span.min(36).max(min_step)
  let fit_step = if total <= 1 {
    min_step
  } else {
    (max_span / (total - 1)).max(min_step)
  }
  let step = fit_step.min(max_step)
  let centered = slot * 2 - (total - 1)
  let raw_offset = centered * step / 2
  if raw_offset > half_span_limit {
    half_span_limit
  } else if raw_offset < -half_span_limit {
    -half_span_limit
  } else {
    raw_offset
  }
}

///|
fn choose_available_boundary_offset(
  preferred_offset : Int,
  candidate_offsets : Array[Int],
  used_offsets : Map[Int, Bool],
) -> Int {
  if !used_offsets.contains(preferred_offset) {
    return preferred_offset
  }
  let mut has_candidate = false
  let mut best_offset = preferred_offset
  let mut best_distance = 0
  let mut best_magnitude = 0
  for candidate in candidate_offsets {
    if used_offsets.contains(candidate) {
      continue
    }
    let distance = int_abs(candidate - preferred_offset)
    let magnitude = int_abs(candidate)
    if !has_candidate ||
      distance < best_distance ||
      (distance == best_distance && magnitude < best_magnitude) ||
      (
        distance == best_distance &&
        magnitude == best_magnitude &&
        candidate < best_offset
      ) {
      has_candidate = true
      best_offset = candidate
      best_distance = distance
      best_magnitude = magnitude
    }
  }
  if has_candidate {
    best_offset
  } else {
    preferred_offset
  }
}

///|
fn assign_compact_boundary_offsets_for_cohort(
  cohort_assignments : Array[BoundaryEndpointAssignment],
  edge_layout_contexts : Array[EdgeLayoutContext],
  source_endpoint : Bool,
  offsets_by_context_index : Map[Int, Int],
) -> Unit {
  if cohort_assignments.length() <= 1 {
    return
  }
  cohort_assignments.sort_by((left, right) => {
    if left.peer_minor != right.peer_minor {
      return left.peer_minor.compare(right.peer_minor)
    }
    if left.peer_major != right.peer_major {
      return left.peer_major.compare(right.peer_major)
    }
    left.context_index.compare(right.context_index)
  })
  let first_assignment = cohort_assignments[0]
  let first_context = edge_layout_contexts[first_assignment.context_index]
  let endpoint_node = if source_endpoint {
    first_context.source
  } else {
    first_context.target
  }
  let half_span_limit = boundary_side_minor_span_limit(
    endpoint_node,
    first_assignment.side,
  )
  let candidate_offsets : Array[Int] = []
  for slot, _ in cohort_assignments {
    candidate_offsets.push(
      distributed_boundary_port_offset(
        slot,
        cohort_assignments.length(),
        half_span_limit,
      ),
    )
  }
  let used_offsets : Map[Int, Bool] = {}
  for assignment in cohort_assignments {
    match offsets_by_context_index.get(assignment.context_index) {
      Some(offset) => used_offsets[offset] = true
      None => ()
    }
  }
  for slot, assignment in cohort_assignments {
    if offsets_by_context_index.contains(assignment.context_index) {
      continue
    }
    let preferred_offset = candidate_offsets[slot]
    let chosen_offset = choose_available_boundary_offset(
      preferred_offset, candidate_offsets, used_offsets,
    )
    offsets_by_context_index[assignment.context_index] = chosen_offset
    used_offsets[chosen_offset] = true
  }
}

///|
fn boundary_offset_candidate_values(
  half_span_limit : Int,
  preferred_total : Int,
) -> Array[Int] {
  let candidates : Array[Int] = []
  if half_span_limit <= 0 {
    candidates.push(0)
    return candidates
  }

  let normalized_total = preferred_total.max(1)
  for slot in 0..<normalized_total {
    let candidate = distributed_boundary_port_offset(
      slot, normalized_total, half_span_limit,
    )
    if !candidates.contains(candidate) {
      candidates.push(candidate)
    }
  }

  let mut offset = -half_span_limit
  while offset <= half_span_limit {
    if !candidates.contains(offset) {
      candidates.push(offset)
    }
    offset += 2
  }

  candidates
}

///|
fn rebalance_boundary_offsets_for_bucket(
  assignments : Array[BoundaryEndpointAssignment],
  edge_layout_contexts : Array[EdgeLayoutContext],
  source_boundary_offset_by_context_index : Map[Int, Int],
  target_boundary_offset_by_context_index : Map[Int, Int],
) -> Unit {
  if assignments.length() <= 1 {
    return
  }

  let ordered_assignments : Array[BoundaryEndpointAssignment] = []
  for assignment in assignments {
    ordered_assignments.push(assignment)
  }
  ordered_assignments.sort_by((left, right) => {
    if left.source_endpoint != right.source_endpoint {
      if left.source_endpoint {
        -1
      } else {
        1
      }
    } else if left.peer_minor != right.peer_minor {
      left.peer_minor.compare(right.peer_minor)
    } else if left.edge_span != right.edge_span {
      right.edge_span.compare(left.edge_span)
    } else if left.peer_major != right.peer_major {
      left.peer_major.compare(right.peer_major)
    } else {
      left.context_index.compare(right.context_index)
    }
  })

  let first_assignment = ordered_assignments[0]
  let first_context = edge_layout_contexts[first_assignment.context_index]
  let endpoint_node = if first_assignment.source_endpoint {
    first_context.source
  } else {
    first_context.target
  }
  let half_span_limit = boundary_side_minor_span_limit(
    endpoint_node,
    first_assignment.side,
  )
  let candidate_offsets = boundary_offset_candidate_values(
    half_span_limit,
    ordered_assignments.length(),
  )
  let used_offsets : Map[Int, Bool] = {}
  let normalized_total = ordered_assignments.length().max(1)
  for slot, assignment in ordered_assignments {
    let existing_offset = if assignment.source_endpoint {
      option_int_or(
        source_boundary_offset_by_context_index.get(assignment.context_index),
        distributed_boundary_port_offset(
          slot, normalized_total, half_span_limit,
        ),
      )
    } else {
      option_int_or(
        target_boundary_offset_by_context_index.get(assignment.context_index),
        distributed_boundary_port_offset(
          slot, normalized_total, half_span_limit,
        ),
      )
    }
    let chosen_offset = choose_available_boundary_offset(
      existing_offset, candidate_offsets, used_offsets,
    )
    used_offsets[chosen_offset] = true
    if assignment.source_endpoint {
      source_boundary_offset_by_context_index[assignment.context_index] = chosen_offset
    } else {
      target_boundary_offset_by_context_index[assignment.context_index] = chosen_offset
    }
  }
}

///|
fn bucket_has_source_target_offset_conflict(
  assignments : Array[BoundaryEndpointAssignment],
  source_boundary_offset_by_context_index : Map[Int, Int],
  target_boundary_offset_by_context_index : Map[Int, Int],
  edge_layout_contexts : Array[EdgeLayoutContext],
) -> Bool {
  if assignments.length() == 0 {
    return false
  }
  let source_offsets : Map[Int, Bool] = {}
  let target_offsets : Map[Int, Bool] = {}
  let normalized_total = assignments.length().max(1)
  for slot, assignment in assignments {
    let context = edge_layout_contexts[assignment.context_index]
    let endpoint_node = if assignment.source_endpoint {
      context.source
    } else {
      context.target
    }
    let half_span_limit = boundary_side_minor_span_limit(
      endpoint_node,
      assignment.side,
    )
    let fallback_offset = distributed_boundary_port_offset(
      slot, normalized_total, half_span_limit,
    )
    let resolved_offset = if assignment.source_endpoint {
      option_int_or(
        source_boundary_offset_by_context_index.get(assignment.context_index),
        fallback_offset,
      )
    } else {
      option_int_or(
        target_boundary_offset_by_context_index.get(assignment.context_index),
        fallback_offset,
      )
    }
    if assignment.source_endpoint {
      source_offsets[resolved_offset] = true
    } else {
      target_offsets[resolved_offset] = true
    }
  }
  for offset, _ in source_offsets {
    if target_offsets.contains(offset) {
      return true
    }
  }
  false
}

///|
fn deferred_back_edge_minor_axis_key(
  context : EdgeLayoutContext,
  key_mode : Int,
) -> Int {
  let source_minor = if context.edge_horizontal {
    context.source.y
  } else {
    context.source.x
  }
  let target_minor = if context.edge_horizontal {
    context.target.y
  } else {
    context.target.x
  }
  if key_mode == 1 {
    target_minor
  } else if key_mode == 2 {
    source_minor + target_minor
  } else {
    source_minor
  }
}

///|
fn build_deferred_back_edge_order(
  deferred_context_indices : Array[Int],
  edge_layout_contexts : Array[EdgeLayoutContext],
  row_key_mode : Int,
  row_first : Bool,
  row_desc : Bool,
  span_desc : Bool,
) -> Array[Int] {
  let ordered_context_indices : Array[Int] = []
  for context_index in deferred_context_indices {
    ordered_context_indices.push(context_index)
  }

  ordered_context_indices.sort_by((left_index, right_index) => {
    let left_context = edge_layout_contexts[left_index]
    let right_context = edge_layout_contexts[right_index]
    let left_row_key = deferred_back_edge_minor_axis_key(
      left_context, row_key_mode,
    )
    let right_row_key = deferred_back_edge_minor_axis_key(
      right_context, row_key_mode,
    )
    let row_cmp = if row_desc {
      right_row_key.compare(left_row_key)
    } else {
      left_row_key.compare(right_row_key)
    }
    let left_span = edge_layout_context_span(left_context)
    let right_span = edge_layout_context_span(right_context)
    let span_cmp = if span_desc {
      right_span.compare(left_span)
    } else {
      left_span.compare(right_span)
    }
    if row_first {
      if row_cmp != 0 {
        return row_cmp
      }
      if span_cmp != 0 {
        return span_cmp
      }
    } else {
      if span_cmp != 0 {
        return span_cmp
      }
      if row_cmp != 0 {
        return row_cmp
      }
    }
    left_index.compare(right_index)
  })
  ordered_context_indices
}

///|
fn append_routed_segments_for_points(
  routed_edge_segments : Array[RoutedEdgeSegment],
  source_id : String,
  target_id : String,
  points : Array[Point],
) -> Unit {
  if points.length() < 2 {
    return
  }
  let last_segment_index = points.length() - 1
  for i in 1..<points.length() {
    routed_edge_segments.push({
      source_id,
      target_id,
      start: points[i - 1],
      end: points[i],
      is_source_stub: i == 1,
      is_target_stub: i == last_segment_index,
    })
  }
}

///|
fn points_equal(left : Point, right : Point) -> Bool {
  left.x == right.x && left.y == right.y
}

///|
fn point_on_segment(a : Point, b : Point, c : Point) -> Bool {
  b.x >= a.x.min(c.x) &&
  b.x <= a.x.max(c.x) &&
  b.y >= a.y.min(c.y) &&
  b.y <= a.y.max(c.y)
}

///|
fn back_edge_segments_intersect(
  left_start : Point,
  left_end : Point,
  right_start : Point,
  right_end : Point,
) -> Bool {
  let o1 = back_edge_segment_orientation(left_start, left_end, right_start)
  let o2 = back_edge_segment_orientation(left_start, left_end, right_end)
  let o3 = back_edge_segment_orientation(right_start, right_end, left_start)
  let o4 = back_edge_segment_orientation(right_start, right_end, left_end)

  let opposite = ((o1 > 0 && o2 < 0) || (o1 < 0 && o2 > 0)) &&
    ((o3 > 0 && o4 < 0) || (o3 < 0 && o4 > 0))
  if opposite {
    return true
  }

  if o1 == 0 && point_on_segment(left_start, right_start, left_end) {
    return true
  }
  if o2 == 0 && point_on_segment(left_start, right_end, left_end) {
    return true
  }
  if o3 == 0 && point_on_segment(right_start, left_start, right_end) {
    return true
  }
  if o4 == 0 && point_on_segment(right_start, left_end, right_end) {
    return true
  }
  false
}

///|
fn polylines_share_endpoint(
  left_polyline : Array[Point],
  right_polyline : Array[Point],
) -> Bool {
  if left_polyline.length() < 2 || right_polyline.length() < 2 {
    return false
  }

  let left_start = left_polyline[0]
  let left_end = left_polyline[left_polyline.length() - 1]
  let right_start = right_polyline[0]
  let right_end = right_polyline[right_polyline.length() - 1]

  points_equal(left_start, right_start) ||
  points_equal(left_start, right_end) ||
  points_equal(left_end, right_start) ||
  points_equal(left_end, right_end)
}

///|
fn count_polyline_crossings(polylines : Array[Array[Point]]) -> Int {
  let mut crossings = 0
  for i in 0..<polylines.length() {
    let left_polyline = polylines[i]
    for j in (i + 1)..<polylines.length() {
      let right_polyline = polylines[j]
      if polylines_share_endpoint(left_polyline, right_polyline) {
        continue
      }

      let mut crossed = false
      let mut left_segment_index = 0
      while left_segment_index + 1 < left_polyline.length() && !crossed {
        let left_start = left_polyline[left_segment_index]
        let left_end = left_polyline[left_segment_index + 1]
        let mut right_segment_index = 0
        while right_segment_index + 1 < right_polyline.length() && !crossed {
          let right_start = right_polyline[right_segment_index]
          let right_end = right_polyline[right_segment_index + 1]
          if points_equal(left_start, right_start) ||
            points_equal(left_start, right_end) ||
            points_equal(left_end, right_start) ||
            points_equal(left_end, right_end) {
            right_segment_index = right_segment_index + 1
            continue
          }
          if back_edge_segments_intersect(
              left_start, left_end, right_start, right_end,
            ) {
            crossings += 1
            crossed = true
          }
          right_segment_index = right_segment_index + 1
        }
        left_segment_index = left_segment_index + 1
      }
    }
  }
  crossings
}

///|
fn simulate_deferred_back_edge_order_crossings(
  deferred_order : Array[Int],
  edge_layout_contexts : Array[EdgeLayoutContext],
  positioned_nodes : Array[PositionedNode],
  base_routed_edge_segments : Array[RoutedEdgeSegment],
  base_back_edge_lane_reservations : Array[BackEdgeLaneReservation],
  base_back_edge_column_reservations : Array[BackEdgeColumnReservation],
  base_polylines : Array[Array[Point]],
  enhanced_horizontal_state_flow : Bool,
) -> Int {
  let candidate_routed_edge_segments : Array[RoutedEdgeSegment] = []
  let candidate_back_edge_lane_reservations : Array[BackEdgeLaneReservation] = []
  let candidate_back_edge_column_reservations : Array[BackEdgeColumnReservation] = []
  for segment in base_routed_edge_segments {
    candidate_routed_edge_segments.push(segment)
  }
  for reservation in base_back_edge_lane_reservations {
    candidate_back_edge_lane_reservations.push(reservation)
  }
  for reservation in base_back_edge_column_reservations {
    candidate_back_edge_column_reservations.push(reservation)
  }

  let candidate_polylines : Array[Array[Point]] = []
  for polyline in base_polylines {
    candidate_polylines.push(polyline)
  }

  for context_index in deferred_order {
    let context = edge_layout_contexts[context_index]
    let source = context.source
    let target = context.target
    let back_edge_bend_y = if context.edge_horizontal {
      Some(
        reserve_back_edge_bend_y(
          source, target, positioned_nodes, candidate_routed_edge_segments, candidate_back_edge_lane_reservations,
        ),
      )
    } else {
      None
    }
    let back_edge_bend_x = if !context.edge_horizontal {
      Some(
        reserve_back_edge_bend_x(
          source, target, positioned_nodes, candidate_routed_edge_segments, candidate_back_edge_column_reservations,
        ),
      )
    } else {
      None
    }
    let points = @layout_engine_graph_edge_core.edge_points_for_with_ports(
      source,
      target,
      context.edge_horizontal,
      back_edge_bend_y,
      back_edge_bend_x,
      None,
      enhanced_horizontal_state_flow,
      context.source_boundary_offset_minor,
      context.target_boundary_offset_minor,
    )
    candidate_polylines.push(points)
    append_routed_segments_for_points(
      candidate_routed_edge_segments,
      context.resolved_source_id,
      context.resolved_target_id,
      points,
    )
  }

  count_polyline_crossings(candidate_polylines)
}

///|
fn optimize_deferred_back_edge_order_locally(
  initial_order : Array[Int],
  edge_layout_contexts : Array[EdgeLayoutContext],
  positioned_nodes : Array[PositionedNode],
  base_routed_edge_segments : Array[RoutedEdgeSegment],
  base_back_edge_lane_reservations : Array[BackEdgeLaneReservation],
  base_back_edge_column_reservations : Array[BackEdgeColumnReservation],
  base_polylines : Array[Array[Point]],
  enhanced_horizontal_state_flow : Bool,
) -> Array[Int] {
  fn copy_order(order : Array[Int]) -> Array[Int] {
    let copied : Array[Int] = []
    for context_index in order {
      copied.push(context_index)
    }
    copied
  }

  fn build_relocated_order(
    order : Array[Int],
    from_index : Int,
    to_index : Int,
  ) -> Array[Int] {
    if from_index == to_index ||
      from_index < 0 ||
      from_index >= order.length() ||
      to_index < 0 ||
      to_index >= order.length() {
      return copy_order(order)
    }
    let moved_context_index = order[from_index]
    let relocated : Array[Int] = []
    let mut inserted = false
    for i, context_index in order {
      if i == from_index {
        continue
      }
      if !inserted && relocated.length() == to_index {
        relocated.push(moved_context_index)
        inserted = true
      }
      relocated.push(context_index)
    }
    if !inserted {
      relocated.push(moved_context_index)
    }
    relocated
  }

  let mut optimized_order : Array[Int] = []
  for context_index in initial_order {
    optimized_order.push(context_index)
  }
  if optimized_order.length() < 2 {
    return optimized_order
  }

  let mut best_crossings = simulate_deferred_back_edge_order_crossings(
    optimized_order, edge_layout_contexts, positioned_nodes, base_routed_edge_segments,
    base_back_edge_lane_reservations, base_back_edge_column_reservations, base_polylines,
    enhanced_horizontal_state_flow,
  )
  let max_evaluations = (optimized_order.length() * 30).max(90).min(512)
  let mut evaluations = 0

  let mut pass = 0
  while pass < 6 && evaluations < max_evaluations {
    let mut changed = false
    let mut i = 0
    while i + 1 < optimized_order.length() && evaluations < max_evaluations {
      let left_context_index = optimized_order[i]
      let right_context_index = optimized_order[i + 1]
      optimized_order[i] = right_context_index
      optimized_order[i + 1] = left_context_index

      let candidate_crossings = simulate_deferred_back_edge_order_crossings(
        optimized_order, edge_layout_contexts, positioned_nodes, base_routed_edge_segments,
        base_back_edge_lane_reservations, base_back_edge_column_reservations, base_polylines,
        enhanced_horizontal_state_flow,
      )
      evaluations = evaluations + 1

      if candidate_crossings < best_crossings {
        best_crossings = candidate_crossings
        changed = true
      } else {
        optimized_order[i] = left_context_index
        optimized_order[i + 1] = right_context_index
      }
      i = i + 1
    }
    if !changed {
      break
    }
    pass = pass + 1
  }

  if optimized_order.length() >= 3 && evaluations < max_evaluations {
    let mut insertion_round = 0
    while insertion_round < 2 && evaluations < max_evaluations {
      let mut has_round_best = false
      let mut round_best_crossings = best_crossings
      let mut round_best_order : Array[Int] = []

      for from_index in 0..<optimized_order.length() {
        if evaluations >= max_evaluations {
          break
        }
        for to_index in 0..<optimized_order.length() {
          if evaluations >= max_evaluations {
            break
          }
          if from_index == to_index {
            continue
          }
          let relocated_order = build_relocated_order(
            optimized_order, from_index, to_index,
          )
          let candidate_crossings = simulate_deferred_back_edge_order_crossings(
            relocated_order, edge_layout_contexts, positioned_nodes, base_routed_edge_segments,
            base_back_edge_lane_reservations, base_back_edge_column_reservations,
            base_polylines, enhanced_horizontal_state_flow,
          )
          evaluations = evaluations + 1
          if candidate_crossings < round_best_crossings {
            round_best_crossings = candidate_crossings
            round_best_order = relocated_order
            has_round_best = true
          }
        }
      }

      if !has_round_best {
        break
      }
      optimized_order = round_best_order
      best_crossings = round_best_crossings
      insertion_round = insertion_round + 1
    }
  }

  optimized_order
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
fn back_edge_lane_conflicts(
  reservations : Array[BackEdgeLaneReservation],
  left : Int,
  right : Int,
  y : Int,
) -> Bool {
  reservations.any(item => {
    item.y == y && spans_overlap(left, right, item.left, item.right)
  })
}

///|
fn back_edge_column_conflicts(
  reservations : Array[BackEdgeColumnReservation],
  top : Int,
  bottom : Int,
  x : Int,
) -> Bool {
  reservations.any(item => {
    item.x == x && spans_overlap(top, bottom, item.top, item.bottom)
  })
}

///|
fn back_edge_side_node_congestion(
  nodes : Array[PositionedNode],
  source : PositionedNode,
  target : PositionedNode,
  left : Int,
  right : Int,
  candidate_y : Int,
) -> Int {
  let top = source.y.min(target.y)
  let bottom = source.y.max(target.y)
  let route_above = candidate_y < top
  let route_below = candidate_y > bottom

  if !route_above && !route_below {
    return 0
  }

  let mut congestion = 0
  for node in nodes {
    if node.id == source.id || node.id == target.id {
      continue
    }
    let node_left = node.x - node.width / 2
    let node_right = node.x + node.width / 2
    if !spans_overlap(left, right, node_left, node_right) {
      continue
    }
    if route_above {
      if node.y < top {
        congestion += 1
      }
    } else if node.y > bottom {
      congestion += 1
    }
  }
  congestion
}

///|
fn back_edge_column_side_node_congestion(
  nodes : Array[PositionedNode],
  source : PositionedNode,
  target : PositionedNode,
  top : Int,
  bottom : Int,
  candidate_x : Int,
) -> Int {
  let left = source.x.min(target.x)
  let right = source.x.max(target.x)
  let route_left = candidate_x < left
  let route_right = candidate_x > right

  if !route_left && !route_right {
    return 0
  }

  let mut congestion = 0
  for node in nodes {
    if node.id == source.id || node.id == target.id {
      continue
    }
    let node_top = node.y - node.height / 2
    let node_bottom = node.y + node.height / 2
    if !spans_overlap(top, bottom, node_top, node_bottom) {
      continue
    }
    if route_left {
      if node.x < left {
        congestion += 1
      }
    } else if node.x > right {
      congestion += 1
    }
  }
  congestion
}

///|
fn back_edge_lane_distance_penalty(
  source : PositionedNode,
  target : PositionedNode,
  candidate_y : Int,
) -> Int {
  let top = source.y.min(target.y)
  let bottom = source.y.max(target.y)
  if candidate_y < top {
    top - candidate_y
  } else if candidate_y > bottom {
    candidate_y - bottom
  } else {
    0
  }
}

///|
fn back_edge_column_distance_penalty(
  source : PositionedNode,
  target : PositionedNode,
  candidate_x : Int,
) -> Int {
  let left = source.x.min(target.x)
  let right = source.x.max(target.x)
  if candidate_x < left {
    left - candidate_x
  } else if candidate_x > right {
    candidate_x - right
  } else {
    0
  }
}

///|
fn back_edge_horizontal_segment_intersects_node_box(
  left : Int,
  right : Int,
  y : Int,
  node_left : Int,
  node_right : Int,
  node_top : Int,
  node_bottom : Int,
) -> Bool {
  y >= node_top &&
  y <= node_bottom &&
  spans_overlap(left, right, node_left, node_right)
}

///|
fn back_edge_vertical_segment_intersects_node_box(
  top : Int,
  bottom : Int,
  x : Int,
  node_left : Int,
  node_right : Int,
  node_top : Int,
  node_bottom : Int,
) -> Bool {
  x >= node_left &&
  x <= node_right &&
  spans_overlap(top, bottom, node_top, node_bottom)
}

///|
fn back_edge_lane_node_box_penalty(
  nodes : Array[PositionedNode],
  source : PositionedNode,
  target : PositionedNode,
  source_anchor_x : Int,
  source_y : Int,
  target_anchor_x : Int,
  target_y : Int,
  candidate_y : Int,
) -> Int {
  let box_margin = 6
  let left = source_anchor_x.min(target_anchor_x)
  let right = source_anchor_x.max(target_anchor_x)
  let source_top = source_y.min(candidate_y)
  let source_bottom = source_y.max(candidate_y)
  let target_top = target_y.min(candidate_y)
  let target_bottom = target_y.max(candidate_y)
  let mut penalty = 0
  for node in nodes {
    if node.id == source.id || node.id == target.id {
      continue
    }
    let node_left = node.x - node.width / 2 - box_margin
    let node_right = node.x + node.width / 2 + box_margin
    let node_top = node.y - node.height / 2 - box_margin
    let node_bottom = node.y + node.height / 2 + box_margin
    if back_edge_vertical_segment_intersects_node_box(
        source_top, source_bottom, source_anchor_x, node_left, node_right, node_top,
        node_bottom,
      ) ||
      back_edge_horizontal_segment_intersects_node_box(
        left, right, candidate_y, node_left, node_right, node_top, node_bottom,
      ) ||
      back_edge_vertical_segment_intersects_node_box(
        target_top, target_bottom, target_anchor_x, node_left, node_right, node_top,
        node_bottom,
      ) {
      penalty += 1
    }
  }
  penalty
}

///|
fn back_edge_column_node_box_penalty(
  nodes : Array[PositionedNode],
  source : PositionedNode,
  target : PositionedNode,
  source_x : Int,
  source_anchor_y : Int,
  target_x : Int,
  target_anchor_y : Int,
  candidate_x : Int,
) -> Int {
  let box_margin = 6
  let top = source_anchor_y.min(target_anchor_y)
  let bottom = source_anchor_y.max(target_anchor_y)
  let source_left = source_x.min(candidate_x)
  let source_right = source_x.max(candidate_x)
  let target_left = target_x.min(candidate_x)
  let target_right = target_x.max(candidate_x)
  let mut penalty = 0
  for node in nodes {
    if node.id == source.id || node.id == target.id {
      continue
    }
    let node_left = node.x - node.width / 2 - box_margin
    let node_right = node.x + node.width / 2 + box_margin
    let node_top = node.y - node.height / 2 - box_margin
    let node_bottom = node.y + node.height / 2 + box_margin
    if back_edge_horizontal_segment_intersects_node_box(
        source_left, source_right, source_anchor_y, node_left, node_right, node_top,
        node_bottom,
      ) ||
      back_edge_vertical_segment_intersects_node_box(
        top, bottom, candidate_x, node_left, node_right, node_top, node_bottom,
      ) ||
      back_edge_horizontal_segment_intersects_node_box(
        target_left, target_right, target_anchor_y, node_left, node_right, node_top,
        node_bottom,
      ) {
      penalty += 1
    }
  }
  penalty
}

///|
fn back_edge_segment_orientation(a : Point, b : Point, c : Point) -> Int {
  (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
}

///|
fn back_edge_segments_properly_intersect(
  left_start : Point,
  left_end : Point,
  right_start : Point,
  right_end : Point,
) -> Bool {
  let o1 = back_edge_segment_orientation(left_start, left_end, right_start)
  let o2 = back_edge_segment_orientation(left_start, left_end, right_end)
  let o3 = back_edge_segment_orientation(right_start, right_end, left_start)
  let o4 = back_edge_segment_orientation(right_start, right_end, left_end)
  ((o1 > 0 && o2 < 0) || (o1 < 0 && o2 > 0)) &&
  ((o3 > 0 && o4 < 0) || (o3 < 0 && o4 > 0))
}

///|
fn back_edge_lane_crossing_penalty(
  crossing_candidates : Array[RoutedEdgeSegment],
  source_anchor_x : Int,
  source_y : Int,
  target_anchor_x : Int,
  target_y : Int,
  candidate_y : Int,
) -> Int {
  let start : Point = { x: source_anchor_x, y: source_y }
  let bend_start : Point = { x: source_anchor_x, y: candidate_y }
  let bend_end : Point = { x: target_anchor_x, y: candidate_y }
  let end : Point = { x: target_anchor_x, y: target_y }
  let mut penalty = 0
  for segment in crossing_candidates {
    if back_edge_segments_properly_intersect(
        segment.start,
        segment.end,
        start,
        bend_start,
      ) ||
      back_edge_segments_properly_intersect(
        segment.start,
        segment.end,
        bend_start,
        bend_end,
      ) ||
      back_edge_segments_properly_intersect(
        segment.start,
        segment.end,
        bend_end,
        end,
      ) {
      penalty += 1
    }
  }
  penalty
}

///|
fn back_edge_column_crossing_penalty(
  crossing_candidates : Array[RoutedEdgeSegment],
  source_x : Int,
  source_anchor_y : Int,
  target_x : Int,
  target_anchor_y : Int,
  candidate_x : Int,
) -> Int {
  let start : Point = { x: source_x, y: source_anchor_y }
  let bend_start : Point = { x: candidate_x, y: source_anchor_y }
  let bend_end : Point = { x: candidate_x, y: target_anchor_y }
  let end : Point = { x: target_x, y: target_anchor_y }
  let mut penalty = 0
  for segment in crossing_candidates {
    if back_edge_segments_properly_intersect(
        segment.start,
        segment.end,
        start,
        bend_start,
      ) ||
      back_edge_segments_properly_intersect(
        segment.start,
        segment.end,
        bend_start,
        bend_end,
      ) ||
      back_edge_segments_properly_intersect(
        segment.start,
        segment.end,
        bend_end,
        end,
      ) {
      penalty += 1
    }
  }
  penalty
}

///|
fn collect_back_edge_crossing_candidates(
  routed_edge_segments : Array[RoutedEdgeSegment],
  source_id : String,
  target_id : String,
  left : Int,
  right : Int,
) -> Array[RoutedEdgeSegment] {
  let crossing_candidates : Array[RoutedEdgeSegment] = []
  for segment in routed_edge_segments {
    if segment.source_id == source_id ||
      segment.target_id == source_id ||
      segment.source_id == target_id ||
      segment.target_id == target_id {
      continue
    }
    let segment_left = segment.start.x.min(segment.end.x)
    let segment_right = segment.start.x.max(segment.end.x)
    if spans_overlap(left, right, segment_left, segment_right) {
      crossing_candidates.push(segment)
    }
  }
  crossing_candidates
}

///|
fn collect_back_edge_vertical_crossing_candidates(
  routed_edge_segments : Array[RoutedEdgeSegment],
  source_id : String,
  target_id : String,
  top : Int,
  bottom : Int,
) -> Array[RoutedEdgeSegment] {
  let crossing_candidates : Array[RoutedEdgeSegment] = []
  for segment in routed_edge_segments {
    if segment.source_id == source_id ||
      segment.target_id == source_id ||
      segment.source_id == target_id ||
      segment.target_id == target_id {
      continue
    }
    let segment_top = segment.start.y.min(segment.end.y)
    let segment_bottom = segment.start.y.max(segment.end.y)
    if spans_overlap(top, bottom, segment_top, segment_bottom) {
      crossing_candidates.push(segment)
    }
  }
  crossing_candidates
}

///|
fn back_edge_lane_score_is_better(
  node_box_hits : Int,
  crossings : Int,
  distance : Int,
  congestion : Int,
  side_priority : Int,
  best_node_box_hits : Int,
  best_crossings : Int,
  best_distance : Int,
  best_congestion : Int,
  best_side_priority : Int,
) -> Bool {
  if crossings != best_crossings {
    return crossings < best_crossings
  }
  if node_box_hits != best_node_box_hits {
    return node_box_hits < best_node_box_hits
  }
  if distance != best_distance {
    return distance < best_distance
  }
  if congestion != best_congestion {
    return congestion < best_congestion
  }
  side_priority < best_side_priority
}

///|
fn reserve_back_edge_bend_y(
  source : PositionedNode,
  target : PositionedNode,
  nodes : Array[PositionedNode],
  routed_edge_segments : Array[RoutedEdgeSegment],
  reservations : Array[BackEdgeLaneReservation],
) -> Int {
  let source_anchor_x = source.x - source.width / 2
  let target_anchor_x = target.x + target.width / 2
  let left = source_anchor_x.min(target_anchor_x)
  let right = source_anchor_x.max(target_anchor_x)
  let top = source.y.min(target.y)
  let bottom = source.y.max(target.y)
  let crossing_candidates = collect_back_edge_crossing_candidates(
    routed_edge_segments,
    source.id,
    target.id,
    left,
    right,
  )

  let horizontal_span = right - left
  let lane_step = if horizontal_span >= 520 {
    10
  } else if horizontal_span >= 360 {
    12
  } else if horizontal_span >= 220 {
    14
  } else {
    20
  }
  let lane_options_per_side = if horizontal_span >= 520 {
    12
  } else if horizontal_span >= 360 {
    10
  } else if horizontal_span >= 220 {
    8
  } else {
    6
  }
  let base_clearance = 38

  let upper_candidates : Array[Int] = []
  let mut candidate_up = top - base_clearance
  while candidate_up >= 12 && upper_candidates.length() < lane_options_per_side {
    if !back_edge_lane_conflicts(reservations, left, right, candidate_up) {
      upper_candidates.push(candidate_up)
    }
    candidate_up = candidate_up - lane_step
  }

  let lower_candidates : Array[Int] = []
  let mut candidate_down = bottom + base_clearance
  while lower_candidates.length() < lane_options_per_side {
    if !back_edge_lane_conflicts(reservations, left, right, candidate_down) {
      lower_candidates.push(candidate_down)
    }
    candidate_down = candidate_down + lane_step
  }

  let up_congestion = if upper_candidates.length() > 0 {
    back_edge_side_node_congestion(nodes, source, target, left, right, top - 1)
  } else {
    0
  }
  let down_congestion = back_edge_side_node_congestion(
    nodes,
    source,
    target,
    left,
    right,
    bottom + 1,
  )

  let mut has_choice = false
  let mut best_y = 0
  let mut best_node_box_hits = 0
  let mut best_congestion = 0
  let mut best_crossings = 0
  let mut best_distance = 0
  let mut best_side_priority = 0

  fn consider_candidate(
    candidate_y : Int,
    congestion : Int,
    side_priority : Int,
    crossing_candidates : Array[RoutedEdgeSegment],
    source_anchor_x : Int,
    source_y : Int,
    target_anchor_x : Int,
    target_y : Int,
    has_choice : Bool,
    best_y : Int,
    best_node_box_hits : Int,
    best_congestion : Int,
    best_crossings : Int,
    best_distance : Int,
    best_side_priority : Int,
  ) -> (Bool, Int, Int, Int, Int, Int, Int) {
    let node_box_hits = back_edge_lane_node_box_penalty(
      nodes, source, target, source_anchor_x, source_y, target_anchor_x, target_y,
      candidate_y,
    )
    let crossings = back_edge_lane_crossing_penalty(
      crossing_candidates, source_anchor_x, source_y, target_anchor_x, target_y,
      candidate_y,
    )
    let distance = back_edge_lane_distance_penalty(source, target, candidate_y)
    if !has_choice ||
      back_edge_lane_score_is_better(
        node_box_hits, crossings, distance, congestion, side_priority, best_node_box_hits,
        best_crossings, best_distance, best_congestion, best_side_priority,
      ) {
      (
        true, candidate_y, node_box_hits, congestion, crossings, distance, side_priority,
      )
    } else {
      (
        has_choice, best_y, best_node_box_hits, best_congestion, best_crossings,
        best_distance, best_side_priority,
      )
    }
  }

  for candidate_y in upper_candidates {
    let (
      next_has_choice,
      next_y,
      next_node_box_hits,
      next_congestion,
      next_crossings,
      next_distance,
      next_side_priority,
    ) = consider_candidate(
      candidate_y,
      up_congestion,
      0,
      crossing_candidates,
      source_anchor_x,
      source.y,
      target_anchor_x,
      target.y,
      has_choice,
      best_y,
      best_node_box_hits,
      best_congestion,
      best_crossings,
      best_distance,
      best_side_priority,
    )
    has_choice = next_has_choice
    best_y = next_y
    best_node_box_hits = next_node_box_hits
    best_congestion = next_congestion
    best_crossings = next_crossings
    best_distance = next_distance
    best_side_priority = next_side_priority
  }
  for candidate_y in lower_candidates {
    let (
      next_has_choice,
      next_y,
      next_node_box_hits,
      next_congestion,
      next_crossings,
      next_distance,
      next_side_priority,
    ) = consider_candidate(
      candidate_y,
      down_congestion,
      1,
      crossing_candidates,
      source_anchor_x,
      source.y,
      target_anchor_x,
      target.y,
      has_choice,
      best_y,
      best_node_box_hits,
      best_congestion,
      best_crossings,
      best_distance,
      best_side_priority,
    )
    has_choice = next_has_choice
    best_y = next_y
    best_node_box_hits = next_node_box_hits
    best_congestion = next_congestion
    best_crossings = next_crossings
    best_distance = next_distance
    best_side_priority = next_side_priority
  }

  let chosen_y = if has_choice { best_y } else { bottom + 42 }

  reservations.push({ left, right, y: chosen_y })
  chosen_y
}

///|
fn reserve_back_edge_bend_x(
  source : PositionedNode,
  target : PositionedNode,
  nodes : Array[PositionedNode],
  routed_edge_segments : Array[RoutedEdgeSegment],
  reservations : Array[BackEdgeColumnReservation],
) -> Int {
  let source_anchor_y = source.y - source.height / 2
  let target_anchor_y = target.y + target.height / 2
  let top = source_anchor_y.min(target_anchor_y)
  let bottom = source_anchor_y.max(target_anchor_y)
  let left = source.x.min(target.x)
  let right = source.x.max(target.x)
  let crossing_candidates = collect_back_edge_vertical_crossing_candidates(
    routed_edge_segments,
    source.id,
    target.id,
    top,
    bottom,
  )

  let vertical_span = bottom - top
  let lane_step = if vertical_span >= 520 {
    10
  } else if vertical_span >= 360 {
    12
  } else if vertical_span >= 220 {
    14
  } else {
    20
  }
  let lane_options_per_side = if vertical_span >= 520 {
    12
  } else if vertical_span >= 360 {
    10
  } else if vertical_span >= 220 {
    8
  } else {
    6
  }
  let base_clearance = 38

  let left_candidates : Array[Int] = []
  let mut candidate_left = left - base_clearance
  while candidate_left >= 12 && left_candidates.length() < lane_options_per_side {
    if !back_edge_column_conflicts(reservations, top, bottom, candidate_left) {
      left_candidates.push(candidate_left)
    }
    candidate_left = candidate_left - lane_step
  }

  let right_candidates : Array[Int] = []
  let mut candidate_right = right + base_clearance
  while right_candidates.length() < lane_options_per_side {
    if !back_edge_column_conflicts(reservations, top, bottom, candidate_right) {
      right_candidates.push(candidate_right)
    }
    candidate_right = candidate_right + lane_step
  }

  let left_congestion = if left_candidates.length() > 0 {
    back_edge_column_side_node_congestion(
      nodes,
      source,
      target,
      top,
      bottom,
      left - 1,
    )
  } else {
    0
  }
  let right_congestion = back_edge_column_side_node_congestion(
    nodes,
    source,
    target,
    top,
    bottom,
    right + 1,
  )

  let mut has_choice = false
  let mut best_x = 0
  let mut best_node_box_hits = 0
  let mut best_congestion = 0
  let mut best_crossings = 0
  let mut best_distance = 0
  let mut best_side_priority = 0

  fn consider_candidate(
    candidate_x : Int,
    congestion : Int,
    side_priority : Int,
    crossing_candidates : Array[RoutedEdgeSegment],
    source_x : Int,
    source_anchor_y : Int,
    target_x : Int,
    target_anchor_y : Int,
    has_choice : Bool,
    best_x : Int,
    best_node_box_hits : Int,
    best_congestion : Int,
    best_crossings : Int,
    best_distance : Int,
    best_side_priority : Int,
  ) -> (Bool, Int, Int, Int, Int, Int, Int) {
    let node_box_hits = back_edge_column_node_box_penalty(
      nodes, source, target, source_x, source_anchor_y, target_x, target_anchor_y,
      candidate_x,
    )
    let crossings = back_edge_column_crossing_penalty(
      crossing_candidates, source_x, source_anchor_y, target_x, target_anchor_y,
      candidate_x,
    )
    let distance = back_edge_column_distance_penalty(
      source, target, candidate_x,
    )
    if !has_choice ||
      back_edge_lane_score_is_better(
        node_box_hits, crossings, distance, congestion, side_priority, best_node_box_hits,
        best_crossings, best_distance, best_congestion, best_side_priority,
      ) {
      (
        true, candidate_x, node_box_hits, congestion, crossings, distance, side_priority,
      )
    } else {
      (
        has_choice, best_x, best_node_box_hits, best_congestion, best_crossings,
        best_distance, best_side_priority,
      )
    }
  }

  for candidate_x in left_candidates {
    let (
      next_has_choice,
      next_x,
      next_node_box_hits,
      next_congestion,
      next_crossings,
      next_distance,
      next_side_priority,
    ) = consider_candidate(
      candidate_x,
      left_congestion,
      0,
      crossing_candidates,
      source.x,
      source_anchor_y,
      target.x,
      target_anchor_y,
      has_choice,
      best_x,
      best_node_box_hits,
      best_congestion,
      best_crossings,
      best_distance,
      best_side_priority,
    )
    has_choice = next_has_choice
    best_x = next_x
    best_node_box_hits = next_node_box_hits
    best_congestion = next_congestion
    best_crossings = next_crossings
    best_distance = next_distance
    best_side_priority = next_side_priority
  }
  for candidate_x in right_candidates {
    let (
      next_has_choice,
      next_x,
      next_node_box_hits,
      next_congestion,
      next_crossings,
      next_distance,
      next_side_priority,
    ) = consider_candidate(
      candidate_x,
      right_congestion,
      1,
      crossing_candidates,
      source.x,
      source_anchor_y,
      target.x,
      target_anchor_y,
      has_choice,
      best_x,
      best_node_box_hits,
      best_congestion,
      best_crossings,
      best_distance,
      best_side_priority,
    )
    has_choice = next_has_choice
    best_x = next_x
    best_node_box_hits = next_node_box_hits
    best_congestion = next_congestion
    best_crossings = next_crossings
    best_distance = next_distance
    best_side_priority = next_side_priority
  }

  let chosen_x = if has_choice { best_x } else { right + 42 }

  reservations.push({ top, bottom, x: chosen_x })
  chosen_x
}

///|
priv struct LabelRouteScore {
  label_node_overlaps : Int
  label_edge_overlaps : Int
  label_label_overlaps : Int
  endpoint_anchor_conflicts : Int
  reciprocal_segment_intersections : Int
  reciprocal_segment_overlaps : Int
  route_crossings : Int
  route_length : Int
  offset_abs : Int
}

///|
fn edge_label_dimensions(label : String) -> (Int, Int) {
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
fn polyline_label_anchor(points : Array[Point]) -> Point {
  if points.length() == 0 {
    return { x: 0, y: 0 }
  }
  if points.length() == 1 {
    return points[0]
  }

  let mut total_length = 0
  for i in 1..<points.length() {
    let start = points[i - 1]
    let end = points[i]
    total_length = total_length +
      int_abs(end.x - start.x) +
      int_abs(end.y - start.y)
  }
  if total_length <= 0 {
    return points[0]
  }

  let half_length = total_length / 2
  let mut walked = 0
  for i in 1..<points.length() {
    let start = points[i - 1]
    let end = points[i]
    let segment_length = int_abs(end.x - start.x) + int_abs(end.y - start.y)
    if segment_length <= 0 {
      continue
    }
    let next_walked = walked + segment_length
    if next_walked >= half_length {
      let remaining = half_length - walked
      return {
        x: start.x + (end.x - start.x) * remaining / segment_length,
        y: start.y + (end.y - start.y) * remaining / segment_length,
      }
    }
    walked = next_walked
  }
  points[points.length() - 1]
}

///|
fn edge_label_box_for_context_points(
  context : EdgeLayoutContext,
  points : Array[Point],
) -> RoutedLabelBox? {
  match context.edge.label {
    Some(text) => {
      let (label_width, label_height) = edge_label_dimensions(text)
      let anchor = polyline_label_anchor(points)
      Some({
        left: anchor.x - label_width / 2,
        right: anchor.x + (label_width + 1) / 2,
        top: anchor.y - label_height / 2,
        bottom: anchor.y + (label_height + 1) / 2,
      })
    }
    None => None
  }
}

///|
fn point_inside_rect(
  point : Point,
  left : Int,
  right : Int,
  top : Int,
  bottom : Int,
) -> Bool {
  point.x >= left && point.x <= right && point.y >= top && point.y <= bottom
}

///|
fn rects_overlap(
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
fn segment_intersects_rect(
  start : Point,
  end : Point,
  left : Int,
  right : Int,
  top : Int,
  bottom : Int,
) -> Bool {
  if !rects_overlap(
      start.x.min(end.x),
      start.x.max(end.x),
      start.y.min(end.y),
      start.y.max(end.y),
      left,
      right,
      top,
      bottom,
    ) {
    return false
  }
  if point_inside_rect(start, left, right, top, bottom) ||
    point_inside_rect(end, left, right, top, bottom) {
    return true
  }
  let top_left : Point = { x: left, y: top }
  let top_right : Point = { x: right, y: top }
  let bottom_left : Point = { x: left, y: bottom }
  let bottom_right : Point = { x: right, y: bottom }
  back_edge_segments_intersect(start, end, top_left, top_right) ||
  back_edge_segments_intersect(start, end, top_right, bottom_right) ||
  back_edge_segments_intersect(start, end, bottom_right, bottom_left) ||
  back_edge_segments_intersect(start, end, bottom_left, top_left)
}

///|
fn label_box_overlaps_node(
  label_box : RoutedLabelBox,
  node : PositionedNode,
  margin : Int,
) -> Bool {
  let node_left = node.x - node.width / 2 - margin
  let node_right = node.x + node.width / 2 + margin
  let node_top = node.y - node.height / 2 - margin
  let node_bottom = node.y + node.height / 2 + margin
  rects_overlap(
    label_box.left,
    label_box.right,
    label_box.top,
    label_box.bottom,
    node_left,
    node_right,
    node_top,
    node_bottom,
  )
}

///|
fn label_box_overlaps_segment(
  label_box : RoutedLabelBox,
  segment : RoutedEdgeSegment,
  margin : Int,
) -> Bool {
  segment_intersects_rect(
    segment.start,
    segment.end,
    label_box.left - margin,
    label_box.right + margin,
    label_box.top - margin,
    label_box.bottom + margin,
  )
}

///|
fn label_boxes_overlap(
  left : RoutedLabelBox,
  right : RoutedLabelBox,
  margin : Int,
) -> Bool {
  rects_overlap(
    left.left - margin,
    left.right + margin,
    left.top - margin,
    left.bottom + margin,
    right.left,
    right.right,
    right.top,
    right.bottom,
  )
}

///|
fn route_length(points : Array[Point]) -> Int {
  let mut length = 0
  for i in 1..<points.length() {
    let start = points[i - 1]
    let end = points[i]
    length = length + int_abs(end.x - start.x) + int_abs(end.y - start.y)
  }
  length
}

///|
fn segments_equal_undirected(
  left_start : Point,
  left_end : Point,
  right_start : Point,
  right_end : Point,
) -> Bool {
  (point_equals(left_start, right_start) && point_equals(left_end, right_end)) ||
  (point_equals(left_start, right_end) && point_equals(left_end, right_start))
}

///|
fn segments_share_positive_axis_overlap(
  left_start : Point,
  left_end : Point,
  right_start : Point,
  right_end : Point,
) -> Bool {
  let left_vertical = left_start.x == left_end.x
  let left_horizontal = left_start.y == left_end.y
  let right_vertical = right_start.x == right_end.x
  let right_horizontal = right_start.y == right_end.y

  if left_vertical && right_vertical && left_start.x == right_start.x {
    let left_top = left_start.y.min(left_end.y)
    let left_bottom = left_start.y.max(left_end.y)
    let right_top = right_start.y.min(right_end.y)
    let right_bottom = right_start.y.max(right_end.y)
    let overlap_top = left_top.max(right_top)
    let overlap_bottom = left_bottom.min(right_bottom)
    return overlap_bottom > overlap_top
  }

  if left_horizontal && right_horizontal && left_start.y == right_start.y {
    let left_left = left_start.x.min(left_end.x)
    let left_right = left_start.x.max(left_end.x)
    let right_left = right_start.x.min(right_end.x)
    let right_right = right_start.x.max(right_end.x)
    let overlap_left = left_left.max(right_left)
    let overlap_right = left_right.min(right_right)
    return overlap_right > overlap_left
  }

  false
}

///|
fn route_endpoint_anchor_conflicts(
  context : EdgeLayoutContext,
  points : Array[Point],
  routed_edge_segments : Array[RoutedEdgeSegment],
) -> Int {
  if points.length() < 2 {
    return 0
  }
  let source_anchor = points[0]
  let target_anchor = points[points.length() - 1]
  let mut conflicts = 0
  for segment in routed_edge_segments {
    if segment.is_source_stub &&
      segment.source_id == context.resolved_source_id &&
      point_equals(source_anchor, segment.start) {
      conflicts += 1
    }
    if segment.is_target_stub &&
      segment.target_id == context.resolved_target_id &&
      point_equals(target_anchor, segment.end) {
      conflicts += 1
    }
  }
  conflicts
}

///|
fn route_reciprocal_segment_overlaps(
  context : EdgeLayoutContext,
  points : Array[Point],
  routed_edge_segments : Array[RoutedEdgeSegment],
) -> Int {
  let mut overlaps = 0
  for i in 1..<points.length() {
    let candidate_start = points[i - 1]
    let candidate_end = points[i]
    for segment in routed_edge_segments {
      if segment.source_id != context.resolved_target_id ||
        segment.target_id != context.resolved_source_id {
        continue
      }
      if segments_equal_undirected(
          candidate_start,
          candidate_end,
          segment.start,
          segment.end,
        ) ||
        segments_share_positive_axis_overlap(
          candidate_start,
          candidate_end,
          segment.start,
          segment.end,
        ) {
        overlaps += 1
      }
    }
  }
  overlaps
}

///|
fn route_reciprocal_segment_intersections(
  context : EdgeLayoutContext,
  points : Array[Point],
  routed_edge_segments : Array[RoutedEdgeSegment],
) -> Int {
  let mut intersections = 0
  for i in 1..<points.length() {
    let candidate_start = points[i - 1]
    let candidate_end = points[i]
    for segment in routed_edge_segments {
      if segment.source_id != context.resolved_target_id ||
        segment.target_id != context.resolved_source_id {
        continue
      }
      if point_equals(candidate_start, segment.start) ||
        point_equals(candidate_start, segment.end) ||
        point_equals(candidate_end, segment.start) ||
        point_equals(candidate_end, segment.end) {
        continue
      }
      if back_edge_segments_intersect(
          candidate_start,
          candidate_end,
          segment.start,
          segment.end,
        ) {
        intersections += 1
      }
    }
  }
  intersections
}

///|
fn route_crossings_against_routed_segments(
  points : Array[Point],
  source_id : String,
  target_id : String,
  routed_edge_segments : Array[RoutedEdgeSegment],
) -> Int {
  let mut crossings = 0
  for i in 1..<points.length() {
    let candidate_start = points[i - 1]
    let candidate_end = points[i]
    for segment in routed_edge_segments {
      if segment.source_id == source_id ||
        segment.target_id == source_id ||
        segment.source_id == target_id ||
        segment.target_id == target_id {
        continue
      }
      if back_edge_segments_properly_intersect(
          candidate_start,
          candidate_end,
          segment.start,
          segment.end,
        ) {
        crossings += 1
      }
    }
  }
  crossings
}

///|
fn route_crossings_against_all_routed_segments(
  points : Array[Point],
  source_id : String,
  target_id : String,
  routed_edge_segments : Array[RoutedEdgeSegment],
) -> Int {
  let mut crossings = 0
  for i in 1..<points.length() {
    let candidate_start = points[i - 1]
    let candidate_end = points[i]
    for segment in routed_edge_segments {
      if segment.source_id == source_id && segment.target_id == target_id {
        continue
      }
      if back_edge_segments_properly_intersect(
          candidate_start,
          candidate_end,
          segment.start,
          segment.end,
        ) {
        crossings += 1
      }
    }
  }
  crossings
}

///|
fn evaluate_labeled_route_score(
  context : EdgeLayoutContext,
  points : Array[Point],
  offset_abs : Int,
  positioned_nodes : Array[PositionedNode],
  routed_edge_segments : Array[RoutedEdgeSegment],
  routed_label_boxes : Array[RoutedLabelBox],
) -> LabelRouteScore {
  let endpoint_anchor_conflicts = if context.compact_endpoint_port_priority {
    route_endpoint_anchor_conflicts(context, points, routed_edge_segments)
  } else {
    0
  }
  let reciprocal_segment_overlaps = if context.compact_endpoint_port_priority {
    route_reciprocal_segment_overlaps(context, points, routed_edge_segments)
  } else {
    0
  }
  let reciprocal_segment_intersections = if context.compact_endpoint_port_priority {
    route_reciprocal_segment_intersections(
      context, points, routed_edge_segments,
    )
  } else {
    0
  }
  let route_crossings = route_crossings_against_routed_segments(
    points,
    context.resolved_source_id,
    context.resolved_target_id,
    routed_edge_segments,
  )
  match edge_label_box_for_context_points(context, points) {
    Some(label_box) => {
      let mut label_node_overlaps = 0
      for node in positioned_nodes {
        if label_box_overlaps_node(label_box, node, 2) {
          label_node_overlaps += 1
        }
      }

      let mut label_edge_overlaps = 0
      for segment in routed_edge_segments {
        if segment.source_id == context.resolved_source_id ||
          segment.target_id == context.resolved_source_id ||
          segment.source_id == context.resolved_target_id ||
          segment.target_id == context.resolved_target_id {
          continue
        }
        if label_box_overlaps_segment(label_box, segment, 2) {
          label_edge_overlaps += 1
        }
      }

      let mut label_label_overlaps = 0
      for existing_label_box in routed_label_boxes {
        if label_boxes_overlap(label_box, existing_label_box, 4) {
          label_label_overlaps += 1
        }
      }

      {
        label_node_overlaps,
        label_edge_overlaps,
        label_label_overlaps,
        endpoint_anchor_conflicts,
        reciprocal_segment_intersections,
        reciprocal_segment_overlaps,
        route_crossings,
        route_length: route_length(points),
        offset_abs,
      }
    }
    None =>
      {
        label_node_overlaps: 0,
        label_edge_overlaps: 0,
        label_label_overlaps: 0,
        endpoint_anchor_conflicts,
        reciprocal_segment_intersections,
        reciprocal_segment_overlaps,
        route_crossings,
        route_length: route_length(points),
        offset_abs,
      }
  }
}

///|
fn source_endpoint_turnback_compaction_candidate(
  points : Array[Point],
  edge_horizontal : Bool,
) -> Array[Point]? {
  if points.length() != 3 {
    return None
  }
  let source_anchor = points[0]
  let source_stub_end = points[1]
  let source_next = points[2]
  if edge_horizontal {
    if source_anchor.x != source_stub_end.x ||
      source_anchor.y == source_stub_end.y ||
      source_stub_end.y != source_next.y ||
      source_stub_end.x == source_next.x {
      return None
    }
    Some([source_anchor, { x: source_next.x, y: source_anchor.y }, source_next])
  } else {
    if source_anchor.y != source_stub_end.y ||
      source_anchor.x == source_stub_end.x ||
      source_stub_end.x != source_next.x ||
      source_stub_end.y == source_next.y {
      return None
    }
    Some([source_anchor, { x: source_anchor.x, y: source_next.y }, source_next])
  }
}

///|
fn maybe_compact_source_endpoint_turnback(
  context : EdgeLayoutContext,
  points : Array[Point],
  route_as_back_edge : Bool,
  positioned_nodes : Array[PositionedNode],
  routed_edge_segments : Array[RoutedEdgeSegment],
  routed_label_boxes : Array[RoutedLabelBox],
) -> Array[Point] {
  if route_as_back_edge ||
    !context.compact_endpoint_port_priority ||
    context.source_boundary_cohort_size < 2 ||
    context.source_boundary_offset_minor == 0 {
    return points
  }
  match
    source_endpoint_turnback_compaction_candidate(
      points,
      context.edge_horizontal,
    ) {
    Some(candidate_points) => {
      let current_score = evaluate_labeled_route_score(
        context, points, 0, positioned_nodes, routed_edge_segments, routed_label_boxes,
      )
      let candidate_score = evaluate_labeled_route_score(
        context, candidate_points, 0, positioned_nodes, routed_edge_segments, routed_label_boxes,
      )
      let candidate_better = label_route_score_is_better(
        candidate_score, current_score,
      )
      let current_better = label_route_score_is_better(
        current_score, candidate_score,
      )
      if candidate_better || !current_better {
        candidate_points
      } else {
        points
      }
    }
    None => points
  }
}

///|
fn reciprocal_target_dogleg_candidate(
  points : Array[Point],
  offset : Int,
) -> Array[Point]? {
  if points.length() < 3 || offset <= 0 {
    return None
  }
  let count = points.length()
  let anchor = points[count - 1]
  let approach = points[count - 2]
  let pivot = points[count - 3]
  if approach.x == anchor.x && approach.y != anchor.y {
    let direction = if pivot.x >= anchor.x { 1 } else { -1 }
    let detour_x = anchor.x + direction * offset
    let candidate : Array[Point] = []
    for i in 0..<(count - 2) {
      candidate.push(points[i])
    }
    candidate.push({ x: detour_x, y: approach.y })
    candidate.push({ x: detour_x, y: anchor.y })
    candidate.push(anchor)
    return Some(candidate)
  }
  if approach.y == anchor.y && approach.x != anchor.x {
    let direction = if pivot.y >= anchor.y { 1 } else { -1 }
    let detour_y = anchor.y + direction * offset
    let candidate : Array[Point] = []
    for i in 0..<(count - 2) {
      candidate.push(points[i])
    }
    candidate.push({ x: approach.x, y: detour_y })
    candidate.push({ x: anchor.x, y: detour_y })
    candidate.push(anchor)
    return Some(candidate)
  }
  None
}

///|
fn reciprocal_two_point_dogleg_candidate(
  points : Array[Point],
  edge_horizontal : Bool,
  offset : Int,
) -> Array[Point]? {
  if points.length() != 2 || offset == 0 {
    return None
  }
  let start = points[0]
  let end = points[1]
  if edge_horizontal {
    if start.x == end.x || start.y == end.y {
      return None
    }
    let baseline = if offset > 0 {
      start.y.max(end.y)
    } else {
      start.y.min(end.y)
    }
    let apex_y = baseline + offset
    let apex_x = (start.x + end.x) / 2
    return Some(
      @layout_engine_graph_edge_core.simplify_polyline_points([
        start,
        { x: apex_x, y: apex_y },
        end,
      ]),
    )
  }
  if start.y == end.y || start.x == end.x {
    return None
  }
  let baseline = if offset > 0 {
    start.x.max(end.x)
  } else {
    start.x.min(end.x)
  }
  let apex_x = baseline + offset
  let apex_y = (start.y + end.y) / 2
  Some(
    @layout_engine_graph_edge_core.simplify_polyline_points([
      start,
      { x: apex_x, y: apex_y },
      end,
    ]),
  )
}

///|
fn reciprocal_two_point_outer_detour_candidate(
  context : EdgeLayoutContext,
  points : Array[Point],
  toward_positive_major : Bool,
  offset : Int,
) -> Array[Point]? {
  if points.length() != 2 || offset <= 0 {
    return None
  }
  let start = points[0]
  let end = points[1]
  if context.edge_horizontal {
    let source_left = context.source.x - context.source.width / 2
    let source_right = context.source.x + context.source.width / 2
    let target_left = context.target.x - context.target.width / 2
    let target_right = context.target.x + context.target.width / 2
    let detour_x = if toward_positive_major {
      source_right.max(target_right) + offset
    } else {
      source_left.min(target_left) - offset
    }
    return Some(
      @layout_engine_graph_edge_core.simplify_polyline_points([
        start,
        { x: detour_x, y: start.y },
        { x: detour_x, y: end.y },
        end,
      ]),
    )
  }
  let source_top = context.source.y - context.source.height / 2
  let source_bottom = context.source.y + context.source.height / 2
  let target_top = context.target.y - context.target.height / 2
  let target_bottom = context.target.y + context.target.height / 2
  let detour_y = if toward_positive_major {
    source_bottom.max(target_bottom) + offset
  } else {
    source_top.min(target_top) - offset
  }
  Some(
    @layout_engine_graph_edge_core.simplify_polyline_points([
      start,
      { x: start.x, y: detour_y },
      { x: end.x, y: detour_y },
      end,
    ]),
  )
}

///|
fn reciprocal_two_point_outer_shifted_candidate(
  context : EdgeLayoutContext,
  points : Array[Point],
  toward_positive_major : Bool,
  major_offset : Int,
  minor_offset : Int,
) -> Array[Point]? {
  if points.length() != 2 || major_offset <= 0 || minor_offset == 0 {
    return None
  }
  let start = points[0]
  let end = points[1]
  if context.edge_horizontal {
    let source_left = context.source.x - context.source.width / 2
    let source_right = context.source.x + context.source.width / 2
    let target_left = context.target.x - context.target.width / 2
    let target_right = context.target.x + context.target.width / 2
    let detour_x = if toward_positive_major {
      source_right.max(target_right) + major_offset
    } else {
      source_left.min(target_left) - major_offset
    }
    let lane_y = start.y + minor_offset
    return Some(
      @layout_engine_graph_edge_core.simplify_polyline_points([
        start,
        { x: start.x, y: lane_y },
        { x: detour_x, y: lane_y },
        { x: detour_x, y: end.y },
        end,
      ]),
    )
  }
  let source_top = context.source.y - context.source.height / 2
  let source_bottom = context.source.y + context.source.height / 2
  let target_top = context.target.y - context.target.height / 2
  let target_bottom = context.target.y + context.target.height / 2
  let detour_y = if toward_positive_major {
    source_bottom.max(target_bottom) + major_offset
  } else {
    source_top.min(target_top) - major_offset
  }
  let lane_x = start.x + minor_offset
  Some(
    @layout_engine_graph_edge_core.simplify_polyline_points([
      start,
      { x: lane_x, y: start.y },
      { x: lane_x, y: detour_y },
      { x: end.x, y: detour_y },
      end,
    ]),
  )
}

///|
fn maybe_optimize_reciprocal_target_dogleg(
  context : EdgeLayoutContext,
  points : Array[Point],
  positioned_nodes : Array[PositionedNode],
  routed_edge_segments : Array[RoutedEdgeSegment],
  routed_label_boxes : Array[RoutedLabelBox],
) -> Array[Point] {
  if !context.compact_endpoint_port_priority || points.length() < 2 {
    return points
  }
  let mut has_reciprocal = false
  for segment in routed_edge_segments {
    if segment.source_id == context.resolved_target_id &&
      segment.target_id == context.resolved_source_id {
      has_reciprocal = true
      break
    }
  }
  if !has_reciprocal {
    return points
  }
  if context.source_boundary_offset_minor == 0 {
    return points
  }
  if context.source_boundary_cohort_size < 2 && context.edge.label is Some(_) {
    return points
  }

  let mut best_points : Array[Point] = []
  for point in points {
    best_points.push(point)
  }
  let seed_points : Array[Point] = []
  for point in points {
    seed_points.push(point)
  }
  let mut best_score = evaluate_labeled_route_score(
    context, best_points, 0, positioned_nodes, routed_edge_segments, routed_label_boxes,
  )
  let mut best_crossings = route_crossings_against_all_routed_segments(
    best_points,
    context.resolved_source_id,
    context.resolved_target_id,
    routed_edge_segments,
  )
  let seen_signatures : Map[String, Bool] = {}
  seen_signatures[points_signature(best_points)] = true
  if points.length() == 2 {
    let start = points[0]
    let end = points[points.length() - 1]
    let minor_delta = if context.edge_horizontal {
      int_abs(end.y - start.y)
    } else {
      int_abs(end.x - start.x)
    }
    let base_offset = minor_delta.max(12)
    let candidate_offsets = [
      -base_offset,
      base_offset,
      -(base_offset + 12),
      base_offset + 12,
      -(base_offset + 24),
      base_offset + 24,
    ]
    for offset in candidate_offsets {
      match
        reciprocal_two_point_dogleg_candidate(
          seed_points,
          context.edge_horizontal,
          offset,
        ) {
        Some(candidate) => {
          let signature = points_signature(candidate)
          if seen_signatures.contains(signature) {
            continue
          }
          seen_signatures[signature] = true
          let candidate_crossings = route_crossings_against_all_routed_segments(
            candidate,
            context.resolved_source_id,
            context.resolved_target_id,
            routed_edge_segments,
          )
          let candidate_score = evaluate_labeled_route_score(
            context,
            candidate,
            int_abs(offset),
            positioned_nodes,
            routed_edge_segments,
            routed_label_boxes,
          )
          let candidate_better = label_route_score_is_better(
            candidate_score, best_score,
          )
          let best_better = label_route_score_is_better(
            best_score, candidate_score,
          )
          if candidate_crossings < best_crossings ||
            (
              candidate_crossings == best_crossings &&
              (candidate_better || !best_better)
            ) {
            best_points = candidate
            best_score = candidate_score
            best_crossings = candidate_crossings
          }
        }
        None => ()
      }
    }
    let outer_detour_offsets = [12, 24, 36, 48, 72, 96]
    for offset in outer_detour_offsets {
      match
        reciprocal_two_point_outer_detour_candidate(
          context, seed_points, false, offset,
        ) {
        Some(candidate) => {
          let signature = points_signature(candidate)
          if !seen_signatures.contains(signature) {
            seen_signatures[signature] = true
            let candidate_crossings = route_crossings_against_all_routed_segments(
              candidate,
              context.resolved_source_id,
              context.resolved_target_id,
              routed_edge_segments,
            )
            let candidate_score = evaluate_labeled_route_score(
              context, candidate, offset, positioned_nodes, routed_edge_segments,
              routed_label_boxes,
            )
            let candidate_better = label_route_score_is_better(
              candidate_score, best_score,
            )
            let best_better = label_route_score_is_better(
              best_score, candidate_score,
            )
            if candidate_crossings < best_crossings ||
              (
                candidate_crossings == best_crossings &&
                (candidate_better || !best_better)
              ) {
              best_points = candidate
              best_score = candidate_score
              best_crossings = candidate_crossings
            }
          }
        }
        None => ()
      }
      match
        reciprocal_two_point_outer_detour_candidate(
          context, seed_points, true, offset,
        ) {
        Some(candidate) => {
          let signature = points_signature(candidate)
          if !seen_signatures.contains(signature) {
            seen_signatures[signature] = true
            let candidate_crossings = route_crossings_against_all_routed_segments(
              candidate,
              context.resolved_source_id,
              context.resolved_target_id,
              routed_edge_segments,
            )
            let candidate_score = evaluate_labeled_route_score(
              context, candidate, offset, positioned_nodes, routed_edge_segments,
              routed_label_boxes,
            )
            let candidate_better = label_route_score_is_better(
              candidate_score, best_score,
            )
            let best_better = label_route_score_is_better(
              best_score, candidate_score,
            )
            if candidate_crossings < best_crossings ||
              (
                candidate_crossings == best_crossings &&
                (candidate_better || !best_better)
              ) {
              best_points = candidate
              best_score = candidate_score
              best_crossings = candidate_crossings
            }
          }
        }
        None => ()
      }
    }
    let shifted_major_offsets = [12, 24, 36, 48, 72]
    let shifted_minor_offsets = [-24, -12, 12, 24]
    for major_offset in shifted_major_offsets {
      for minor_offset in shifted_minor_offsets {
        match
          reciprocal_two_point_outer_shifted_candidate(
            context, seed_points, false, major_offset, minor_offset,
          ) {
          Some(candidate) => {
            let signature = points_signature(candidate)
            if !seen_signatures.contains(signature) {
              seen_signatures[signature] = true
              let candidate_crossings = route_crossings_against_all_routed_segments(
                candidate,
                context.resolved_source_id,
                context.resolved_target_id,
                routed_edge_segments,
              )
              let candidate_score = evaluate_labeled_route_score(
                context,
                candidate,
                major_offset + int_abs(minor_offset),
                positioned_nodes,
                routed_edge_segments,
                routed_label_boxes,
              )
              let candidate_better = label_route_score_is_better(
                candidate_score, best_score,
              )
              let best_better = label_route_score_is_better(
                best_score, candidate_score,
              )
              if candidate_crossings < best_crossings ||
                (
                  candidate_crossings == best_crossings &&
                  (candidate_better || !best_better)
                ) {
                best_points = candidate
                best_score = candidate_score
                best_crossings = candidate_crossings
              }
            }
          }
          None => ()
        }
        match
          reciprocal_two_point_outer_shifted_candidate(
            context, seed_points, true, major_offset, minor_offset,
          ) {
          Some(candidate) => {
            let signature = points_signature(candidate)
            if !seen_signatures.contains(signature) {
              seen_signatures[signature] = true
              let candidate_crossings = route_crossings_against_all_routed_segments(
                candidate,
                context.resolved_source_id,
                context.resolved_target_id,
                routed_edge_segments,
              )
              let candidate_score = evaluate_labeled_route_score(
                context,
                candidate,
                major_offset + int_abs(minor_offset),
                positioned_nodes,
                routed_edge_segments,
                routed_label_boxes,
              )
              let candidate_better = label_route_score_is_better(
                candidate_score, best_score,
              )
              let best_better = label_route_score_is_better(
                best_score, candidate_score,
              )
              if candidate_crossings < best_crossings ||
                (
                  candidate_crossings == best_crossings &&
                  (candidate_better || !best_better)
                ) {
                best_points = candidate
                best_score = candidate_score
                best_crossings = candidate_crossings
              }
            }
          }
          None => ()
        }
      }
    }
  }
  let candidate_offsets = [12, 24, 36, 48, 72, 96, 128]
  for offset in candidate_offsets {
    match reciprocal_target_dogleg_candidate(seed_points, offset) {
      Some(raw_candidate) => {
        let candidate = @layout_engine_graph_edge_core.simplify_polyline_points(
          raw_candidate,
        )
        let signature = points_signature(candidate)
        if seen_signatures.contains(signature) {
          continue
        }
        seen_signatures[signature] = true
        let candidate_crossings = route_crossings_against_all_routed_segments(
          candidate,
          context.resolved_source_id,
          context.resolved_target_id,
          routed_edge_segments,
        )
        let candidate_score = evaluate_labeled_route_score(
          context, candidate, 0, positioned_nodes, routed_edge_segments, routed_label_boxes,
        )
        let candidate_better = label_route_score_is_better(
          candidate_score, best_score,
        )
        let best_better = label_route_score_is_better(
          best_score, candidate_score,
        )
        if candidate_crossings < best_crossings ||
          (
            candidate_crossings == best_crossings &&
            (candidate_better || !best_better)
          ) {
          best_points = candidate
          best_score = candidate_score
          best_crossings = candidate_crossings
        }
      }
      None => ()
    }
  }
  best_points
}

///|
fn label_route_score_is_better(
  candidate : LabelRouteScore,
  best : LabelRouteScore,
) -> Bool {
  if candidate.label_node_overlaps != best.label_node_overlaps {
    return candidate.label_node_overlaps < best.label_node_overlaps
  }
  if candidate.label_edge_overlaps != best.label_edge_overlaps {
    return candidate.label_edge_overlaps < best.label_edge_overlaps
  }
  if candidate.label_label_overlaps != best.label_label_overlaps {
    return candidate.label_label_overlaps < best.label_label_overlaps
  }
  if candidate.endpoint_anchor_conflicts != best.endpoint_anchor_conflicts {
    return candidate.endpoint_anchor_conflicts < best.endpoint_anchor_conflicts
  }
  if candidate.reciprocal_segment_intersections !=
    best.reciprocal_segment_intersections {
    return candidate.reciprocal_segment_intersections <
      best.reciprocal_segment_intersections
  }
  if candidate.reciprocal_segment_overlaps != best.reciprocal_segment_overlaps {
    return candidate.reciprocal_segment_overlaps <
      best.reciprocal_segment_overlaps
  }
  if candidate.route_crossings != best.route_crossings {
    return candidate.route_crossings < best.route_crossings
  }
  if candidate.route_length != best.route_length {
    return candidate.route_length < best.route_length
  }
  candidate.offset_abs < best.offset_abs
}

///|
fn points_signature(points : Array[Point]) -> String {
  if points.length() == 0 {
    return ""
  }
  let sb = StringBuilder::new()
  for i in 0..<points.length() {
    if i > 0 {
      sb.write_string("|")
    }
    let point = points[i]
    sb.write_string(point.x.to_string())
    sb.write_string(",")
    sb.write_string(point.y.to_string())
  }
  sb.to_string()
}

///|
fn optimize_labeled_route_points(
  context : EdgeLayoutContext,
  base_points : Array[Point],
  route_as_back_edge : Bool,
  use_forward_fanout_lane : Bool,
  smooth_forward_fanout : Bool,
  source_port_minor_offset : Int,
  target_port_minor_offset : Int,
  layer_spacing : Int,
  node_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  routed_edge_segments : Array[RoutedEdgeSegment],
  routed_label_boxes : Array[RoutedLabelBox],
) -> Array[Point] {
  if context.edge.label is None {
    return base_points
  }
  if route_as_back_edge || use_forward_fanout_lane {
    return base_points
  }

  let mut best_points : Array[Point] = []
  for point in base_points {
    best_points.push(point)
  }
  let mut best_score = evaluate_labeled_route_score(
    context, best_points, 0, positioned_nodes, routed_edge_segments, routed_label_boxes,
  )
  if best_score.label_node_overlaps == 0 &&
    best_score.label_edge_overlaps == 0 &&
    best_score.label_label_overlaps == 0 &&
    best_score.reciprocal_segment_intersections == 0 &&
    best_score.reciprocal_segment_overlaps == 0 &&
    best_score.route_crossings == 0 {
    return best_points
  }

  let (label_width, label_height) = match context.edge.label {
    Some(text) => edge_label_dimensions(text)
    None => (0, 0)
  }
  let source_minor_half = if context.edge_horizontal {
    context.source.height / 2
  } else {
    context.source.width / 2
  }
  let target_minor_half = if context.edge_horizontal {
    context.target.height / 2
  } else {
    context.target.width / 2
  }
  let label_minor_half = if context.edge_horizontal {
    label_height / 2
  } else {
    label_width / 2
  }
  let base_clearance = source_minor_half.max(target_minor_half) +
    label_minor_half +
    8
  let step = if context.edge_horizontal {
    (layer_spacing / 4).max(16)
  } else {
    (node_spacing / 4).max(16)
  }

  let candidate_offsets = [
    -base_clearance,
    base_clearance,
    -(base_clearance + step),
    base_clearance + step,
    -(base_clearance + step * 2),
    base_clearance + step * 2,
  ]
  let seen_signatures : Map[String, Bool] = {}
  seen_signatures[points_signature(best_points)] = true

  for candidate_offset in candidate_offsets {
    let candidate_points = @layout_engine_graph_edge_core.edge_points_with_minor_lane_offset_with_ports(
      context.source,
      context.target,
      context.edge_horizontal,
      candidate_offset,
      smooth_forward_fanout,
      source_port_minor_offset,
      target_port_minor_offset,
    )
    let signature = points_signature(candidate_points)
    if seen_signatures.contains(signature) {
      continue
    }
    seen_signatures[signature] = true
    let candidate_score = evaluate_labeled_route_score(
      context,
      candidate_points,
      int_abs(candidate_offset),
      positioned_nodes,
      routed_edge_segments,
      routed_label_boxes,
    )
    if label_route_score_is_better(candidate_score, best_score) {
      best_score = candidate_score
      best_points = candidate_points
    }
  }

  best_points
}

///|
fn append_routed_label_box_for_context(
  routed_label_boxes : Array[RoutedLabelBox],
  context : EdgeLayoutContext,
  points : Array[Point],
) -> Unit {
  match edge_label_box_for_context_points(context, points) {
    Some(label_box) => routed_label_boxes.push(label_box)
    None => ()
  }
}

///|
fn label_overlap_offset(slot : Int) -> Int {
  if slot <= 0 {
    return 0
  }
  let magnitude = (slot + 1) / 2 * 30
  if slot % 2 == 1 {
    -magnitude
  } else {
    magnitude
  }
}

///|
fn label_overlap_offset_x(slot : Int) -> Int {
  if slot <= 0 {
    return 0
  }
  let magnitude = (slot + 1) / 2 * 40
  if slot % 2 == 1 {
    -magnitude
  } else {
    magnitude
  }
}

///|
fn label_anchor_key(point : Point) -> String {
  "\{point.x}:\{point.y}"
}

///|
