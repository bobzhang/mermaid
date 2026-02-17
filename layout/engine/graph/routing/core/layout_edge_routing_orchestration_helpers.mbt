///|
fn forward_fanout_bucket(source_id : String, edge_horizontal : Bool) -> String {
  if edge_horizontal {
    "h:\{source_id}"
  } else {
    "v:\{source_id}"
  }
}

///|
fn directed_edge_key(source_id : String, target_id : String) -> String {
  "\{source_id}->\{target_id}"
}

///|
fn context_has_reciprocal_edge(
  context : EdgeLayoutContext,
  directed_edge_count_by_key : Map[String, Int],
) -> Bool {
  let reverse_key = directed_edge_key(
    context.resolved_target_id,
    context.resolved_source_id,
  )
  option_int_or(directed_edge_count_by_key.get(reverse_key), 0) > 0
}

///|
fn context_requires_long_span_back_edge_bend(
  context : EdgeLayoutContext,
  horizontal_span_threshold : Int,
  vertical_span_threshold : Int,
  directed_edge_count_by_key : Map[String, Int],
) -> Bool {
  let edge = context.edge
  if edge.label is Some(_) {
    return false
  }
  let has_reciprocal = context_has_reciprocal_edge(
    context, directed_edge_count_by_key,
  )
  let reciprocal_requires_detour = has_reciprocal &&
    context.source_boundary_offset_minor == 0 &&
    context.target_boundary_offset_minor == 0
  if context.edge_horizontal {
    context.target.x < context.source.x &&
    (
      int_abs(context.target.x - context.source.x) >= horizontal_span_threshold ||
      reciprocal_requires_detour
    )
  } else {
    context.target.y < context.source.y &&
    (
      int_abs(context.target.y - context.source.y) >= vertical_span_threshold ||
      reciprocal_requires_detour
    )
  }
}

///|
fn context_uses_forward_fanout_lane(
  context : EdgeLayoutContext,
  horizontal_span_threshold : Int,
  horizontal_minor_gap_threshold : Int,
  vertical_span_threshold : Int,
  vertical_minor_gap_threshold : Int,
) -> Bool {
  let edge = context.edge
  if edge.label is Some(_) {
    return false
  }
  if context.edge_horizontal {
    context.target.x >= context.source.x &&
    int_abs(context.target.x - context.source.x) >= horizontal_span_threshold &&
    int_abs(context.target.y - context.source.y) <=
    horizontal_minor_gap_threshold
  } else {
    context.target.y >= context.source.y &&
    int_abs(context.target.y - context.source.y) >= vertical_span_threshold &&
    int_abs(context.target.x - context.source.x) <= vertical_minor_gap_threshold
  }
}

///|
fn context_forward_fanout_minor_key(context : EdgeLayoutContext) -> Int {
  if context.edge_horizontal {
    context.target.y
  } else {
    context.target.x
  }
}

///|
fn context_forward_fanout_major_key(context : EdgeLayoutContext) -> Int {
  if context.edge_horizontal {
    context.target.x
  } else {
    context.target.y
  }
}

///|
fn copy_context_index_order(order : Array[Int]) -> Array[Int] {
  let copied : Array[Int] = []
  for context_index in order {
    copied.push(context_index)
  }
  copied
}

///|
fn sort_forward_fanout_order(
  order : Array[Int],
  edge_layout_contexts : Array[EdgeLayoutContext],
  minor_desc : Bool,
  major_desc : Bool,
  major_first : Bool,
) -> Unit {
  order.sort_by((left_index, right_index) => {
    let left_context = edge_layout_contexts[left_index]
    let right_context = edge_layout_contexts[right_index]
    let left_minor = context_forward_fanout_minor_key(left_context)
    let right_minor = context_forward_fanout_minor_key(right_context)
    let minor_cmp = if minor_desc {
      right_minor.compare(left_minor)
    } else {
      left_minor.compare(right_minor)
    }
    let left_major = context_forward_fanout_major_key(left_context)
    let right_major = context_forward_fanout_major_key(right_context)
    let major_cmp = if major_desc {
      right_major.compare(left_major)
    } else {
      left_major.compare(right_major)
    }
    if major_first {
      if major_cmp != 0 {
        return major_cmp
      }
      if minor_cmp != 0 {
        return minor_cmp
      }
    } else {
      if minor_cmp != 0 {
        return minor_cmp
      }
      if major_cmp != 0 {
        return major_cmp
      }
    }
    left_index.compare(right_index)
  })
}

///|
fn maybe_resolve_forward_fanout_slots_for_bucket(
  bucket_key : String,
  total : Int,
  edge_layout_contexts : Array[EdgeLayoutContext],
  forward_fanout_context_indices_by_bucket : Map[String, Array[Int]],
  forward_fanout_slot_by_context_index : Map[Int, Int],
  forward_fanout_slots_resolved_by_bucket : Map[String, Bool],
  forward_fanout_disabled_by_bucket : Map[String, Bool],
  routed_polylines : Array[Array[Point]],
  enhanced_horizontal_state_flow : Bool,
) -> Unit {
  if total <= 1 || forward_fanout_slots_resolved_by_bucket.contains(bucket_key) {
    return
  }

  let bucket_context_indices = match
    forward_fanout_context_indices_by_bucket.get(bucket_key) {
    Some(context_indices) => context_indices
    None => {
      forward_fanout_slots_resolved_by_bucket[bucket_key] = true
      return
    }
  }
  if bucket_context_indices.length() <= 1 {
    forward_fanout_slots_resolved_by_bucket[bucket_key] = true
    return
  }

  fn evaluate_order_crossings(order : Array[Int]) -> Int {
    let candidate_slot_by_context_index : Map[Int, Int] = {}
    for slot, context_index in order {
      candidate_slot_by_context_index[context_index] = slot
    }
    let candidate_polylines : Array[Array[Point]] = []
    for polyline in routed_polylines {
      candidate_polylines.push(polyline)
    }
    for context_index in bucket_context_indices {
      let context = edge_layout_contexts[context_index]
      let slot = option_int_or(
        candidate_slot_by_context_index.get(context_index),
        0,
      )
      let points = @layout_engine_graph_edge_core.edge_points_for_with_ports(
        context.source,
        context.target,
        context.edge_horizontal,
        None,
        None,
        Some(forward_fanout_offset(slot, total)),
        enhanced_horizontal_state_flow,
        context.source_boundary_offset_minor,
        context.target_boundary_offset_minor,
      )
      candidate_polylines.push(points)
    }
    count_polyline_crossings(candidate_polylines)
  }

  fn evaluate_direct_crossings() -> Int {
    let candidate_polylines : Array[Array[Point]] = []
    for polyline in routed_polylines {
      candidate_polylines.push(polyline)
    }
    for context_index in bucket_context_indices {
      let context = edge_layout_contexts[context_index]
      let points = @layout_engine_graph_edge_core.edge_points_for_with_ports(
        context.source,
        context.target,
        context.edge_horizontal,
        None,
        None,
        None,
        enhanced_horizontal_state_flow,
        context.source_boundary_offset_minor,
        context.target_boundary_offset_minor,
      )
      candidate_polylines.push(points)
    }
    count_polyline_crossings(candidate_polylines)
  }

  let candidate_orders : Array[Array[Int]] = []
  candidate_orders.push(copy_context_index_order(bucket_context_indices))

  let ascending_minor = copy_context_index_order(bucket_context_indices)
  sort_forward_fanout_order(
    ascending_minor, edge_layout_contexts, false, false, false,
  )
  candidate_orders.push(ascending_minor)

  let descending_minor = copy_context_index_order(bucket_context_indices)
  sort_forward_fanout_order(
    descending_minor, edge_layout_contexts, true, false, false,
  )
  candidate_orders.push(descending_minor)

  let ascending_major = copy_context_index_order(bucket_context_indices)
  sort_forward_fanout_order(
    ascending_major, edge_layout_contexts, false, false, true,
  )
  candidate_orders.push(ascending_major)

  let descending_major = copy_context_index_order(bucket_context_indices)
  sort_forward_fanout_order(
    descending_major, edge_layout_contexts, false, true, true,
  )
  candidate_orders.push(descending_major)

  let unique_candidate_orders : Array[Array[Int]] = []
  let seen_candidate_signatures : Map[String, Bool] = {}
  for candidate_order in candidate_orders {
    let signature = candidate_order
      .iter()
      .map(context_index => context_index.to_string())
      .join(",")
    if seen_candidate_signatures.contains(signature) {
      continue
    }
    seen_candidate_signatures[signature] = true
    unique_candidate_orders.push(candidate_order)
  }

  let mut best_order = copy_context_index_order(bucket_context_indices)
  let mut best_crossings = evaluate_order_crossings(best_order)

  for candidate_order in unique_candidate_orders {
    let candidate_crossings = evaluate_order_crossings(candidate_order)
    if candidate_crossings < best_crossings {
      best_crossings = candidate_crossings
      best_order = candidate_order
      if best_crossings == 0 {
        break
      }
    }
  }

  let optimized_order = copy_context_index_order(best_order)
  if optimized_order.length() > 2 && best_crossings > 0 {
    let max_adjacent_passes = if optimized_order.length() >= 20 {
      2
    } else if optimized_order.length() >= 10 {
      4
    } else {
      6
    }
    let mut pass = 0
    while pass < max_adjacent_passes && best_crossings > 0 {
      let mut improved = false
      let mut i = 0
      while i + 1 < optimized_order.length() {
        let left = optimized_order[i]
        let right = optimized_order[i + 1]
        optimized_order[i] = right
        optimized_order[i + 1] = left
        let swapped_crossings = evaluate_order_crossings(optimized_order)
        if swapped_crossings < best_crossings {
          best_crossings = swapped_crossings
          improved = true
          if best_crossings == 0 {
            break
          }
        } else {
          optimized_order[i] = left
          optimized_order[i + 1] = right
        }
        i = i + 1
      }
      if !improved {
        break
      }
      pass += 1
    }
  }

  let direct_crossings = evaluate_direct_crossings()
  if direct_crossings <= best_crossings {
    forward_fanout_disabled_by_bucket[bucket_key] = true
    forward_fanout_slots_resolved_by_bucket[bucket_key] = true
    return
  }

  for slot, context_index in optimized_order {
    forward_fanout_slot_by_context_index[context_index] = slot
  }
  forward_fanout_slots_resolved_by_bucket[bucket_key] = true
}
