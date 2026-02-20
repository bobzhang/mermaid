///|

///|
fn resolve_edge_endpoint_id(
  node_id : String,
  use_subgraph_redirects : Bool,
  redirects : Map[String, String],
) -> String {
  if use_subgraph_redirects {
    match redirects.get(node_id) {
      Some(found) => found
      None => node_id
    }
  } else {
    node_id
  }
}

///|
fn collect_edge_layout_contexts(
  graph : MermaidGraph,
  horizontal : Bool,
  use_subgraph_redirects : Bool,
  subgraph_exit_by_id : Map[String, String],
  subgraph_entry_by_id : Map[String, String],
  positioned_by_id : Map[String, PositionedNode],
  node_horizontal_by_id : Map[String, Bool],
) -> (Array[EdgeLayoutContext], Map[String, Int]) {
  let edge_layout_contexts : Array[EdgeLayoutContext] = []
  let directed_edge_count_by_key : Map[String, Int] = {}
  for edge in graph.edges {
    let resolved_source_id = resolve_edge_endpoint_id(
      edge.source,
      use_subgraph_redirects,
      subgraph_exit_by_id,
    )
    let resolved_target_id = resolve_edge_endpoint_id(
      edge.target,
      use_subgraph_redirects,
      subgraph_entry_by_id,
    )
    match
      (
        positioned_by_id.get(resolved_source_id),
        positioned_by_id.get(resolved_target_id),
      ) {
      (Some(source), Some(target)) => {
        let edge_horizontal = match
          (
            node_horizontal_by_id.get(resolved_source_id),
            node_horizontal_by_id.get(resolved_target_id),
          ) {
          (Some(source_horizontal), Some(target_horizontal)) =>
            if source_horizontal == target_horizontal {
              source_horizontal
            } else {
              horizontal
            }
          _ => horizontal
        }
        edge_layout_contexts.push({
          edge,
          resolved_source_id,
          resolved_target_id,
          source,
          target,
          edge_horizontal,
          compact_endpoint_port_priority: graph.edges.length() <= 20,
          source_boundary_cohort_size: 0,
          source_boundary_offset_minor: 0,
          target_boundary_offset_minor: 0,
        })
        let key = directed_edge_key(resolved_source_id, resolved_target_id)
        directed_edge_count_by_key[key] = option_int_or(
            directed_edge_count_by_key.get(key),
            0,
          ) +
          1
      }
      _ => ()
    }
  }
  (edge_layout_contexts, directed_edge_count_by_key)
}

///|
fn assign_edge_boundary_offsets_to_contexts(
  _graph : MermaidGraph,
  state_graph : Bool,
  class_or_er_graph : Bool,
  enable_target_boundary_ports : Bool,
  edge_layout_contexts : Array[EdgeLayoutContext],
) -> Unit {
  let boundary_assignments_by_bucket : Map[
    String,
    Array[BoundaryEndpointAssignment],
  ] = {}
  for context_index, context in edge_layout_contexts {
    let source_side = context_source_boundary_side(context)
    let target_side = opposite_boundary_side(source_side)
    let source_peer_major = if context.edge_horizontal {
      context.target.x
    } else {
      context.target.y
    }
    let source_peer_minor = if context.edge_horizontal {
      context.target.y
    } else {
      context.target.x
    }
    let target_peer_major = if context.edge_horizontal {
      context.source.x
    } else {
      context.source.y
    }
    let target_peer_minor = if context.edge_horizontal {
      context.source.y
    } else {
      context.source.x
    }
    let source_bucket_key = boundary_bucket_key(
      context.resolved_source_id,
      source_side,
    )
    if !boundary_assignments_by_bucket.contains(source_bucket_key) {
      boundary_assignments_by_bucket[source_bucket_key] = []
    }
    match boundary_assignments_by_bucket.get(source_bucket_key) {
      Some(assignments) =>
        assignments.push({
          context_index,
          source_endpoint: true,
          side: source_side,
          peer_major: source_peer_major,
          peer_minor: source_peer_minor,
          edge_span: edge_layout_context_span(context),
        })
      None => ()
    }
    let target_bucket_key = boundary_bucket_key(
      context.resolved_target_id,
      target_side,
    )
    if !boundary_assignments_by_bucket.contains(target_bucket_key) {
      boundary_assignments_by_bucket[target_bucket_key] = []
    }
    match boundary_assignments_by_bucket.get(target_bucket_key) {
      Some(assignments) =>
        assignments.push({
          context_index,
          source_endpoint: false,
          side: target_side,
          peer_major: target_peer_major,
          peer_minor: target_peer_minor,
          edge_span: edge_layout_context_span(context),
        })
      None => ()
    }
  }
  let source_boundary_offset_by_context_index : Map[Int, Int] = {}
  let target_boundary_offset_by_context_index : Map[Int, Int] = {}
  let source_boundary_cohort_size_by_context_index : Map[Int, Int] = {}
  for _, assignments in boundary_assignments_by_bucket {
    if assignments.length() == 0 {
      continue
    }
    let assignments_by_peer_minor : Map[Int, Array[BoundaryEndpointAssignment]] = {}
    let mut source_endpoint_count = 0
    let mut target_endpoint_count = 0
    for assignment in assignments {
      if assignment.source_endpoint {
        source_endpoint_count += 1
      } else {
        target_endpoint_count += 1
      }
      if !assignments_by_peer_minor.contains(assignment.peer_minor) {
        assignments_by_peer_minor[assignment.peer_minor] = []
      }
      match assignments_by_peer_minor.get(assignment.peer_minor) {
        Some(peer_minor_assignments) => peer_minor_assignments.push(assignment)
        None => ()
      }
    }
    let mut has_mixed_peer_minor = false
    for assignment in assignments {
      if assignment.source_endpoint {
        source_boundary_cohort_size_by_context_index[assignment.context_index] = source_endpoint_count
      }
    }

    for _, peer_minor_assignments in assignments_by_peer_minor {
      if peer_minor_assignments.length() <= 1 ||
        peer_minor_assignments.length() > 4 {
        continue
      }
      let mut peer_has_source_endpoint = false
      let mut peer_has_target_endpoint = false
      for assignment in peer_minor_assignments {
        if assignment.source_endpoint {
          peer_has_source_endpoint = true
        } else {
          peer_has_target_endpoint = true
        }
      }
      if peer_has_source_endpoint && peer_has_target_endpoint {
        has_mixed_peer_minor = true
      }
      if !peer_has_source_endpoint || !peer_has_target_endpoint {
        continue
      }
      peer_minor_assignments.sort_by((left, right) => {
        if left.peer_major != right.peer_major {
          return left.peer_major.compare(right.peer_major)
        }
        if left.source_endpoint != right.source_endpoint {
          if left.source_endpoint {
            -1
          } else {
            1
          }
        } else if left.edge_span != right.edge_span {
          right.edge_span.compare(left.edge_span)
        } else {
          left.context_index.compare(right.context_index)
        }
      })
      let first_assignment = peer_minor_assignments[0]
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
      for slot, assignment in peer_minor_assignments {
        // When a source endpoint shares a peer-minor bucket with a reciprocal
        // target endpoint, defer source offset assignment to the source cohort
        // pass so fanout ordering is decided consistently across all sources.
        let defer_source_assignment_to_cohort = assignment.source_endpoint &&
          peer_has_target_endpoint &&
          source_endpoint_count >= 2
        if defer_source_assignment_to_cohort {
          continue
        }
        let offset = distributed_boundary_port_offset(
          slot,
          peer_minor_assignments.length(),
          half_span_limit,
        )
        if assignment.source_endpoint {
          source_boundary_offset_by_context_index[assignment.context_index] = offset
        } else {
          target_boundary_offset_by_context_index[assignment.context_index] = offset
        }
      }
    }

    if assignments.length() <= 4 &&
      source_endpoint_count == assignments.length() &&
      target_endpoint_count == 0 &&
      boundary_side_is_horizontal(assignments[0].side) {
      assignments.sort_by((left, right) => {
        if left.peer_minor != right.peer_minor {
          return left.peer_minor.compare(right.peer_minor)
        }
        if left.peer_major != right.peer_major {
          return left.peer_major.compare(right.peer_major)
        }
        if left.source_endpoint != right.source_endpoint {
          if left.source_endpoint {
            -1
          } else {
            1
          }
        } else {
          left.context_index.compare(right.context_index)
        }
      })
      let first_assignment = assignments[0]
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
      for slot, assignment in assignments {
        let offset = distributed_boundary_port_offset(
          slot,
          assignments.length(),
          half_span_limit,
        )
        source_boundary_offset_by_context_index[assignment.context_index] = offset
      }
    }

    if assignments.length() <= 4 &&
      boundary_side_is_horizontal(assignments[0].side) {
      let source_cohort_assignments : Array[BoundaryEndpointAssignment] = []
      for assignment in assignments {
        if assignment.source_endpoint {
          source_cohort_assignments.push(assignment)
        }
      }
      if source_cohort_assignments.length() >= 2 {
        assign_compact_boundary_offsets_for_cohort(
          source_cohort_assignments, edge_layout_contexts, true, source_boundary_offset_by_context_index,
          false,
        )
      }
    }

    let has_source_target_offset_conflict = bucket_has_source_target_offset_conflict(
      assignments, source_boundary_offset_by_context_index, target_boundary_offset_by_context_index,
      edge_layout_contexts,
    )
    if !class_or_er_graph &&
      assignments.length() <= 6 &&
      has_mixed_peer_minor &&
      source_endpoint_count > 0 &&
      target_endpoint_count > 0 &&
      has_source_target_offset_conflict {
      rebalance_boundary_offsets_for_bucket(
        assignments, edge_layout_contexts, source_boundary_offset_by_context_index,
        target_boundary_offset_by_context_index,
      )
    }
  }
  for context_index, context in edge_layout_contexts {
    let resolved_target_offset = option_int_or(
      target_boundary_offset_by_context_index.get(context_index),
      0,
    )
    edge_layout_contexts[context_index] = {
      edge: context.edge,
      resolved_source_id: context.resolved_source_id,
      resolved_target_id: context.resolved_target_id,
      source: context.source,
      target: context.target,
      edge_horizontal: context.edge_horizontal,
      compact_endpoint_port_priority: context.compact_endpoint_port_priority,
      source_boundary_cohort_size: option_int_or(
        source_boundary_cohort_size_by_context_index.get(context_index),
        0,
      ),
      source_boundary_offset_minor: option_int_or(
        source_boundary_offset_by_context_index.get(context_index),
        0,
      ),
      target_boundary_offset_minor: if enable_target_boundary_ports ||
        (!state_graph && resolved_target_offset != 0) {
        resolved_target_offset
      } else {
        0
      },
    }
  }
}

///|
fn materialize_positioned_edges_from_points(
  edge_layout_contexts : Array[EdgeLayoutContext],
  points_by_context_index : Map[Int, Array[Point]],
  state_graph : Bool,
) -> Array[PositionedEdge] {
  let positioned_edges : Array[PositionedEdge] = []
  let label_slots_by_anchor : Map[String, Int] = {}
  for context_index, context in edge_layout_contexts {
    match points_by_context_index.get(context_index) {
      Some(points) => {
        let edge = context.edge
        let label_position = match edge.label {
          Some(_) => {
            let base = polyline_label_anchor(points)
            let key = label_anchor_key(base)
            let slot = option_int_or(label_slots_by_anchor.get(key), 0)
            label_slots_by_anchor[key] = slot + 1
            let label_x = if state_graph {
              base.x + label_overlap_offset_x(slot)
            } else {
              base.x
            }
            Some(Point::{ x: label_x, y: base.y + label_overlap_offset(slot) })
          }
          None => None
        }
        positioned_edges.push({
          source: edge.source,
          target: edge.target,
          label: edge.label,
          style: edge.style,
          has_arrow_start: edge.has_arrow_start,
          has_arrow_end: edge.has_arrow_end,
          relation_operator: edge.relation_operator,
          points,
          label_position,
        })
      }
      None => ()
    }
  }
  positioned_edges
}

///|
fn routed_context_indices(
  edge_layout_contexts : Array[EdgeLayoutContext],
  points_by_context_index : Map[Int, Array[Point]],
) -> Array[Int] {
  let context_indices : Array[Int] = []
  for context_index, _ in edge_layout_contexts {
    if points_by_context_index.contains(context_index) {
      context_indices.push(context_index)
    }
  }
  context_indices
}

///|
fn reversed_context_indices(context_indices : Array[Int]) -> Array[Int] {
  let reversed : Array[Int] = []
  for i in 0..<context_indices.length() {
    reversed.push(context_indices[context_indices.length() - 1 - i])
  }
  reversed
}

///|
fn optimize_reciprocal_target_doglegs_pass(
  context_indices : Array[Int],
  edge_layout_contexts : Array[EdgeLayoutContext],
  points_by_context_index : Map[Int, Array[Point]],
  positioned_nodes : Array[PositionedNode],
) -> Bool {
  let routed_edge_segments : Array[RoutedEdgeSegment] = []
  let routed_label_boxes : Array[RoutedLabelBox] = []
  let mut changed = false
  for context_index in context_indices {
    let context = edge_layout_contexts[context_index]
    match points_by_context_index.get(context_index) {
      Some(current_points) => {
        let relaxed_context = {
          edge: context.edge,
          resolved_source_id: context.resolved_source_id,
          resolved_target_id: context.resolved_target_id,
          source: context.source,
          target: context.target,
          edge_horizontal: context.edge_horizontal,
          compact_endpoint_port_priority: context.compact_endpoint_port_priority,
          source_boundary_cohort_size: context.source_boundary_cohort_size.max(
            2,
          ),
          source_boundary_offset_minor: if context.source_boundary_offset_minor !=
            0 {
            context.source_boundary_offset_minor
          } else {
            1
          },
          target_boundary_offset_minor: context.target_boundary_offset_minor,
        }
        let optimized_points = maybe_optimize_reciprocal_target_dogleg(
          relaxed_context, current_points, positioned_nodes, routed_edge_segments,
          routed_label_boxes,
        )
        let mut points_for_state = current_points
        if points_signature(optimized_points) !=
          points_signature(current_points) {
          points_by_context_index[context_index] = optimized_points
          points_for_state = optimized_points
          changed = true
        }
        append_routed_segments_for_points(
          routed_edge_segments,
          context.resolved_source_id,
          context.resolved_target_id,
          points_for_state,
        )
        append_routed_label_box_for_context(
          routed_label_boxes, context, points_for_state,
        )
      }
      None => ()
    }
  }
  changed
}

///|
fn optimize_reciprocal_target_doglegs(
  edge_layout_contexts : Array[EdgeLayoutContext],
  points_by_context_index : Map[Int, Array[Point]],
  positioned_nodes : Array[PositionedNode],
) -> Unit {
  let context_indices = routed_context_indices(
    edge_layout_contexts, points_by_context_index,
  )
  if context_indices.length() <= 1 {
    return
  }
  let reverse_context_indices = reversed_context_indices(context_indices)

  let changed_forward = optimize_reciprocal_target_doglegs_pass(
    context_indices, edge_layout_contexts, points_by_context_index, positioned_nodes,
  )
  let changed_reverse = optimize_reciprocal_target_doglegs_pass(
    reverse_context_indices, edge_layout_contexts, points_by_context_index, positioned_nodes,
  )
  if changed_forward || changed_reverse {
    let _ = optimize_reciprocal_target_doglegs_pass(
      context_indices, edge_layout_contexts, points_by_context_index, positioned_nodes,
    )
  }
}

///|
/// Routes all graph edges using the legacy/dagre-parity routing pipeline.
pub fn route_legacy_positioned_edges(
  graph : MermaidGraph,
  state_graph : Bool,
  class_or_er_graph : Bool,
  horizontal : Bool,
  layer_spacing : Int,
  node_spacing : Int,
  use_subgraph_redirects : Bool,
  subgraph_exit_by_id : Map[String, String],
  subgraph_entry_by_id : Map[String, String],
  positioned_nodes : Array[PositionedNode],
  positioned_by_id : Map[String, PositionedNode],
  node_horizontal_by_id : Map[String, Bool],
  enable_target_boundary_ports : Bool,
  preserve_assigned_endpoint_ports : Bool,
  enhanced_horizontal_state_flow : Bool,
) -> Array[PositionedEdge] {
  let routed_edge_segments : Array[RoutedEdgeSegment] = []
  let back_edge_lane_reservations : Array[BackEdgeLaneReservation] = []
  let back_edge_column_reservations : Array[BackEdgeColumnReservation] = []
  let forward_fanout_out_count_by_bucket : Map[String, Int] = {}
  let forward_fanout_horizontal_minor_gap_threshold = (layer_spacing / 4).max(
    22,
  )
  let forward_fanout_vertical_minor_gap_threshold = (node_spacing / 4).max(22)
  let forward_fanout_horizontal_span_threshold = (node_spacing * 2).max(140)
  let forward_fanout_vertical_span_threshold = (layer_spacing * 2).max(140)
  let back_edge_route_horizontal_span_threshold = (node_spacing * 3).max(220)
  let back_edge_route_vertical_span_threshold = (layer_spacing * 3).max(220)

  let (edge_layout_contexts, directed_edge_count_by_key) = collect_edge_layout_contexts(
    graph, horizontal, use_subgraph_redirects, subgraph_exit_by_id, subgraph_entry_by_id,
    positioned_by_id, node_horizontal_by_id,
  )

  assign_edge_boundary_offsets_to_contexts(
    graph, state_graph, class_or_er_graph, enable_target_boundary_ports, edge_layout_contexts,
  )

  let forward_fanout_context_indices_by_bucket : Map[String, Array[Int]] = {}
  for context_index, context in edge_layout_contexts {
    if !context_uses_forward_fanout_lane(
        context, forward_fanout_horizontal_span_threshold, forward_fanout_horizontal_minor_gap_threshold,
        forward_fanout_vertical_span_threshold, forward_fanout_vertical_minor_gap_threshold,
      ) {
      continue
    }
    let bucket = forward_fanout_bucket(
      context.resolved_source_id,
      context.edge_horizontal,
    )
    if !forward_fanout_context_indices_by_bucket.contains(bucket) {
      forward_fanout_context_indices_by_bucket[bucket] = []
    }
    forward_fanout_context_indices_by_bucket[bucket].push(context_index)
  }
  for bucket, context_indices in forward_fanout_context_indices_by_bucket {
    forward_fanout_out_count_by_bucket[bucket] = context_indices.length()
  }
  let forward_fanout_slot_by_context_index : Map[Int, Int] = {}
  let forward_fanout_slots_resolved_by_bucket : Map[String, Bool] = {}
  let forward_fanout_disabled_by_bucket : Map[String, Bool] = {}
  let non_deferred_route_context_indices : Array[Int] = []
  let deferred_back_edge_context_indices : Array[Int] = []
  for context_index, context in edge_layout_contexts {
    let defer_back_edge = context_requires_long_span_back_edge_bend(
      context, back_edge_route_horizontal_span_threshold, back_edge_route_vertical_span_threshold,
      directed_edge_count_by_key,
    )
    if defer_back_edge {
      deferred_back_edge_context_indices.push(context_index)
    } else {
      non_deferred_route_context_indices.push(context_index)
    }
  }

  let points_by_context_index : Map[Int, Array[Point]] = {}
  let routed_polylines : Array[Array[Point]] = []
  let routed_label_boxes : Array[RoutedLabelBox] = []

  let non_deferred_non_fanout_context_indices : Array[Int] = []
  let non_deferred_fanout_context_indices : Array[Int] = []
  for context_index in non_deferred_route_context_indices {
    let context = edge_layout_contexts[context_index]
    if context_uses_forward_fanout_lane(
        context, forward_fanout_horizontal_span_threshold, forward_fanout_horizontal_minor_gap_threshold,
        forward_fanout_vertical_span_threshold, forward_fanout_vertical_minor_gap_threshold,
      ) {
      non_deferred_fanout_context_indices.push(context_index)
    } else {
      non_deferred_non_fanout_context_indices.push(context_index)
    }
  }

  fn route_non_deferred_context(context_index : Int) -> Unit {
    let context = edge_layout_contexts[context_index]
    let source = context.source
    let target = context.target
    let edge_horizontal = context.edge_horizontal
    let route_as_back_edge = context_requires_long_span_back_edge_bend(
      context, back_edge_route_horizontal_span_threshold, back_edge_route_vertical_span_threshold,
      directed_edge_count_by_key,
    )
    let forward_fanout_bucket_key = forward_fanout_bucket(
      context.resolved_source_id,
      edge_horizontal,
    )
    let back_edge_bend_y = if route_as_back_edge && edge_horizontal {
      Some(
        reserve_back_edge_bend_y(
          source, target, positioned_nodes, routed_edge_segments, back_edge_lane_reservations,
        ),
      )
    } else {
      None
    }
    let back_edge_bend_x = if route_as_back_edge && !edge_horizontal {
      Some(
        reserve_back_edge_bend_x(
          source, target, positioned_nodes, routed_edge_segments, back_edge_column_reservations,
        ),
      )
    } else {
      None
    }
    let use_forward_fanout_lane = context_uses_forward_fanout_lane(
        context, forward_fanout_horizontal_span_threshold, forward_fanout_horizontal_minor_gap_threshold,
        forward_fanout_vertical_span_threshold, forward_fanout_vertical_minor_gap_threshold,
      ) &&
      !forward_fanout_disabled_by_bucket.contains(forward_fanout_bucket_key)
    let resolved_forward_fanout_offset = if use_forward_fanout_lane {
      let total = option_int_or(
        forward_fanout_out_count_by_bucket.get(forward_fanout_bucket_key),
        0,
      )
      if total > 1 {
        maybe_resolve_forward_fanout_slots_for_bucket(
          forward_fanout_bucket_key, total, edge_layout_contexts, forward_fanout_context_indices_by_bucket,
          forward_fanout_slot_by_context_index, forward_fanout_slots_resolved_by_bucket,
          forward_fanout_disabled_by_bucket, routed_polylines, enhanced_horizontal_state_flow,
        )
        if forward_fanout_disabled_by_bucket.contains(forward_fanout_bucket_key) {
          None
        } else {
          match forward_fanout_slot_by_context_index.get(context_index) {
            Some(slot) => Some(forward_fanout_offset(slot, total))
            None => None
          }
        }
      } else {
        None
      }
    } else {
      None
    }
    let raw_base_points_with_ports = @layout_engine_graph_edge_core.edge_points_for_with_ports(
      source,
      target,
      edge_horizontal,
      back_edge_bend_y,
      back_edge_bend_x,
      resolved_forward_fanout_offset,
      enhanced_horizontal_state_flow,
      context.source_boundary_offset_minor,
      context.target_boundary_offset_minor,
    )
    let has_reciprocal_counterpart = directed_edge_count_by_key.contains(
      directed_edge_key(context.resolved_target_id, context.resolved_source_id),
    )
    let force_reciprocal_back_edge_ports = preserve_assigned_endpoint_ports &&
      graph.edges.length() <= 20 &&
      route_as_back_edge &&
      has_reciprocal_counterpart
    let force_compact_reciprocal_ports = !state_graph &&
      graph.edges.length() <= 20 &&
      has_reciprocal_counterpart &&
      (
        context.source_boundary_offset_minor != 0 ||
        context.target_boundary_offset_minor != 0
      )
    let base_points_with_ports = if (
        force_reciprocal_back_edge_ports || force_compact_reciprocal_ports
      ) &&
      (
        context.source_boundary_offset_minor != 0 ||
        context.target_boundary_offset_minor != 0
      ) {
      apply_context_endpoint_port_stubs(raw_base_points_with_ports, context)
    } else {
      raw_base_points_with_ports
    }
    let force_compact_source_ports = graph.edges.length() <= 20 &&
      context.source_boundary_offset_minor != 0 &&
      context.target_boundary_offset_minor == 0
    let force_compact_target_ports = !state_graph &&
      graph.edges.length() <= 20 &&
      context.target_boundary_offset_minor != 0 &&
      context.source_boundary_offset_minor == 0
    let base_points = if context.source_boundary_offset_minor != 0 ||
      context.target_boundary_offset_minor != 0 {
      if force_compact_source_ports ||
        force_compact_target_ports ||
        force_compact_reciprocal_ports ||
        force_reciprocal_back_edge_ports {
        base_points_with_ports
      } else {
        let base_points_without_ports = @layout_engine_graph_edge_core.edge_points_for_with_ports(
          source, target, edge_horizontal, back_edge_bend_y, back_edge_bend_x, resolved_forward_fanout_offset,
          enhanced_horizontal_state_flow, 0, 0,
        )
        let with_ports_score = evaluate_labeled_route_score(
          context, base_points_with_ports, 0, positioned_nodes, routed_edge_segments,
          routed_label_boxes,
        )
        let without_ports_score = evaluate_labeled_route_score(
          context, base_points_without_ports, 0, positioned_nodes, routed_edge_segments,
          routed_label_boxes,
        )
        if label_route_score_is_better(without_ports_score, with_ports_score) {
          base_points_without_ports
        } else {
          base_points_with_ports
        }
      }
    } else {
      base_points_with_ports
    }
    let compacted_base_points = maybe_compact_source_endpoint_turnback(
      context, base_points, route_as_back_edge, positioned_nodes, routed_edge_segments,
      routed_label_boxes,
    )
    let reciprocal_optimized_points = maybe_optimize_reciprocal_target_dogleg(
      context, compacted_base_points, positioned_nodes, routed_edge_segments, routed_label_boxes,
    )
    let points = optimize_labeled_route_points(
      context,
      reciprocal_optimized_points,
      route_as_back_edge,
      use_forward_fanout_lane,
      enhanced_horizontal_state_flow,
      context.source_boundary_offset_minor,
      context.target_boundary_offset_minor,
      layer_spacing,
      node_spacing,
      positioned_nodes,
      routed_edge_segments,
      routed_label_boxes,
    )
    points_by_context_index[context_index] = points
    append_routed_segments_for_points(
      routed_edge_segments,
      context.resolved_source_id,
      context.resolved_target_id,
      points,
    )
    routed_polylines.push(points)
    append_routed_label_box_for_context(routed_label_boxes, context, points)
  }

  for context_index in non_deferred_non_fanout_context_indices {
    route_non_deferred_context(context_index)
  }
  for context_index in non_deferred_fanout_context_indices {
    route_non_deferred_context(context_index)
  }

  if deferred_back_edge_context_indices.length() > 0 {
    let deferred_order_candidates : Array[Array[Int]] = []
    fn append_order_family(row_key_mode : Int) -> Unit {
      // Row-first variants.
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          true, false, false,
        ),
      )
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          true, false, true,
        ),
      )
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          true, true, false,
        ),
      )
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          true, true, true,
        ),
      )
      // Span-first variants.
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          false, false, false,
        ),
      )
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          false, true, false,
        ),
      )
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          false, false, true,
        ),
      )
      deferred_order_candidates.push(
        build_deferred_back_edge_order(
          deferred_back_edge_context_indices, edge_layout_contexts, row_key_mode,
          false, true, true,
        ),
      )
    }

    // Keep source-row family first to preserve baseline ordering candidate.
    append_order_family(0)
    append_order_family(1)
    append_order_family(2)

    let base_polylines : Array[Array[Point]] = []
    for context_index in non_deferred_route_context_indices {
      match points_by_context_index.get(context_index) {
        Some(points) => base_polylines.push(points)
        None => ()
      }
    }

    let unique_deferred_order_candidates : Array[Array[Int]] = []
    let seen_candidate_signatures : Map[String, Bool] = {}
    for candidate_order in deferred_order_candidates {
      let signature = candidate_order
        .iter()
        .map(context_index => context_index.to_string())
        .join(",")
      if seen_candidate_signatures.contains(signature) {
        continue
      }
      seen_candidate_signatures[signature] = true
      unique_deferred_order_candidates.push(candidate_order)
    }

    let candidate_crossings : Array[Int] = []
    for candidate_order in unique_deferred_order_candidates {
      candidate_crossings.push(
        simulate_deferred_back_edge_order_crossings(
          candidate_order, edge_layout_contexts, positioned_nodes, routed_edge_segments,
          back_edge_lane_reservations, back_edge_column_reservations, base_polylines,
          enhanced_horizontal_state_flow,
        ),
      )
    }

    let max_seed_count = unique_deferred_order_candidates.length().min(4)
    let selected_seed_indices : Array[Int] = []
    let selected_seed_index_set : Map[Int, Bool] = {}
    for _ in 0..<max_seed_count {
      let mut has_seed = false
      let mut best_seed_index = 0
      let mut best_seed_crossings = 0
      for seed_index, seed_crossings in candidate_crossings {
        if selected_seed_index_set.contains(seed_index) {
          continue
        }
        if !has_seed || seed_crossings < best_seed_crossings {
          has_seed = true
          best_seed_index = seed_index
          best_seed_crossings = seed_crossings
        }
      }
      if !has_seed {
        break
      }
      selected_seed_index_set[best_seed_index] = true
      selected_seed_indices.push(best_seed_index)
    }

    let mut has_best_optimized_order = false
    let mut best_optimized_order : Array[Int] = []
    let mut best_optimized_crossings = 0

    for seed_index in selected_seed_indices {
      let seed_order = unique_deferred_order_candidates[seed_index]
      let optimized_order = optimize_deferred_back_edge_order_locally(
        seed_order, edge_layout_contexts, positioned_nodes, routed_edge_segments,
        back_edge_lane_reservations, back_edge_column_reservations, base_polylines,
        enhanced_horizontal_state_flow,
      )
      let optimized_crossings = simulate_deferred_back_edge_order_crossings(
        optimized_order, edge_layout_contexts, positioned_nodes, routed_edge_segments,
        back_edge_lane_reservations, back_edge_column_reservations, base_polylines,
        enhanced_horizontal_state_flow,
      )
      if !has_best_optimized_order ||
        optimized_crossings < best_optimized_crossings {
        has_best_optimized_order = true
        best_optimized_order = optimized_order
        best_optimized_crossings = optimized_crossings
      }
    }

    let optimized_deferred_order = if has_best_optimized_order {
      best_optimized_order
    } else if unique_deferred_order_candidates.length() > 0 {
      optimize_deferred_back_edge_order_locally(
        unique_deferred_order_candidates[0],
        edge_layout_contexts,
        positioned_nodes,
        routed_edge_segments,
        back_edge_lane_reservations,
        back_edge_column_reservations,
        base_polylines,
        enhanced_horizontal_state_flow,
      )
    } else {
      deferred_back_edge_context_indices
    }

    for context_index in optimized_deferred_order {
      let context = edge_layout_contexts[context_index]
      let source = context.source
      let target = context.target
      let back_edge_bend_y = if context.edge_horizontal {
        Some(
          reserve_back_edge_bend_y(
            source, target, positioned_nodes, routed_edge_segments, back_edge_lane_reservations,
          ),
        )
      } else {
        None
      }
      let back_edge_bend_x = if !context.edge_horizontal {
        Some(
          reserve_back_edge_bend_x(
            source, target, positioned_nodes, routed_edge_segments, back_edge_column_reservations,
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
      let optimized_points = maybe_optimize_reciprocal_target_dogleg(
        context, points, positioned_nodes, routed_edge_segments, routed_label_boxes,
      )
      points_by_context_index[context_index] = optimized_points
      append_routed_segments_for_points(
        routed_edge_segments,
        context.resolved_source_id,
        context.resolved_target_id,
        optimized_points,
      )
      append_routed_label_box_for_context(
        routed_label_boxes, context, optimized_points,
      )
    }
  }
  if enable_target_boundary_ports && !state_graph {
    optimize_reciprocal_target_doglegs(
      edge_layout_contexts, points_by_context_index, positioned_nodes,
    )
  }
  materialize_positioned_edges_from_points(
    edge_layout_contexts, points_by_context_index, state_graph,
  )
}
