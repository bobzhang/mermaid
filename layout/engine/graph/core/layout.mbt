///|
fn shift_top_level_flow_subgraphs_with_gap(
  graph : MermaidGraph,
  horizontal : Bool,
  reverse : Bool,
  layer_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  positioned_groups : Array[PositionedGroup],
  positioned_index_by_id : Map[String, Int],
  positioned_by_id : Map[String, PositionedNode],
) -> Unit {
  if reverse || graph.subgraphs.length() < 2 {
    return
  }
  if !horizontal && graph.edges.length() >= 50 {
    return
  }

  let member_indexes_by_root : Array[Array[Int]] = []
  for subgraph in graph.subgraphs {
    let seen_node_ids : Map[String, Bool] = {}
    let indexes : Array[Int] = []
    collect_subgraph_node_indexes(
      subgraph, positioned_index_by_id, seen_node_ids, indexes,
    )
    member_indexes_by_root.push(indexes)
  }

  if horizontal {
    let min_gap = 8
    let mut has_previous = false
    let mut previous_right = 0
    for i, subgraph in graph.subgraphs {
      let member_indexes = member_indexes_by_root[i]
      if member_indexes.length() == 0 {
        continue
      }
      let group_index = match
        find_positioned_group_index(positioned_groups, subgraph.id) {
        Some(index) => index
        None => continue
      }
      let group = positioned_groups[group_index]
      let desired_left = if has_previous {
        previous_right + min_gap
      } else {
        group.x
      }
      let dx = desired_left - group.x
      if dx > 0 {
        shift_member_indexes(member_indexes, dx, 0, positioned_nodes)
        positioned_groups[group_index] = shift_positioned_group(group, dx, 0)
        for index in member_indexes {
          let node = positioned_nodes[index]
          positioned_by_id[node.id] = node
        }
      }
      let shifted_group = positioned_groups[group_index]
      previous_right = shifted_group.x + shifted_group.width
      has_previous = true
    }
  } else {
    let min_gap = (layer_spacing / 3).max(24)
    let mut has_previous = false
    let mut previous_bottom = 0
    for i, subgraph in graph.subgraphs {
      let member_indexes = member_indexes_by_root[i]
      if member_indexes.length() == 0 {
        continue
      }
      let group_index = match
        find_positioned_group_index(positioned_groups, subgraph.id) {
        Some(index) => index
        None => continue
      }
      let group = positioned_groups[group_index]
      let desired_top = if has_previous {
        previous_bottom + min_gap
      } else {
        group.y
      }
      let dy = desired_top - group.y
      if dy > 0 {
        shift_member_indexes(member_indexes, 0, dy, positioned_nodes)
        positioned_groups[group_index] = shift_positioned_group(group, 0, dy)
        for index in member_indexes {
          let node = positioned_nodes[index]
          positioned_by_id[node.id] = node
        }
      }
      let shifted_group = positioned_groups[group_index]
      previous_bottom = shifted_group.y + shifted_group.height
      has_previous = true
    }
  }
}

///|
fn shift_top_level_state_subgraphs_right(
  graph : MermaidGraph,
  node_spacing : Int,
  layer_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  positioned_groups : Array[PositionedGroup],
  positioned_index_by_id : Map[String, Int],
  positioned_by_id : Map[String, PositionedNode],
) -> Unit {
  if graph.subgraphs.length() == 0 {
    return
  }

  let member_indexes_by_root : Array[Array[Int]] = []
  let subgraph_node_ids : Map[String, Bool] = {}
  for subgraph in graph.subgraphs {
    let seen_node_ids : Map[String, Bool] = {}
    let indexes : Array[Int] = []
    collect_subgraph_node_indexes(
      subgraph, positioned_index_by_id, seen_node_ids, indexes,
    )
    for index in indexes {
      subgraph_node_ids[positioned_nodes[index].id] = true
    }
    member_indexes_by_root.push(indexes)
  }

  let outside_indexes : Array[Int] = []
  for i, node in positioned_nodes {
    if !subgraph_node_ids.contains(node.id) {
      outside_indexes.push(i)
    }
  }
  if outside_indexes.length() == 0 {
    return
  }

  let (has_outside, _, _, outside_right, _) = member_indexes_bounds(
    outside_indexes, positioned_nodes,
  )
  if !has_outside {
    return
  }
  let (_, _, outside_top, _, _) = member_indexes_bounds(
    outside_indexes, positioned_nodes,
  )

  let min_gap = (node_spacing / 3).max(24)
  let mut cursor_left = outside_right + min_gap
  let target_top = outside_top - (layer_spacing / 2).max(30)
  for i, subgraph in graph.subgraphs {
    let member_indexes = member_indexes_by_root[i]
    if member_indexes.length() == 0 {
      continue
    }

    let group_index = match
      find_positioned_group_index(positioned_groups, subgraph.id) {
      Some(index) => index
      None => continue
    }
    let group = positioned_groups[group_index]
    let dx = cursor_left - group.x
    let dy = target_top - group.y
    if dx > 0 || dy != 0 {
      shift_member_indexes(member_indexes, dx.max(0), dy, positioned_nodes)
      positioned_groups[group_index] = shift_positioned_group(
        group,
        dx.max(0),
        dy,
      )
      for index in member_indexes {
        let node = positioned_nodes[index]
        positioned_by_id[node.id] = node
      }
    }
    let shifted_group = positioned_groups[group_index]
    cursor_left = shifted_group.x + shifted_group.width + min_gap
  }
}

///|
fn register_group_anchors(
  group : PositionedGroup,
  positioned_by_id : Map[String, PositionedNode],
  preserve_existing : Bool,
) -> Unit {
  if !preserve_existing || !positioned_by_id.contains(group.id) {
    positioned_by_id[group.id] = {
      id: group.id,
      label: group.label,
      shape: Rectangle,
      x: group.x + group.width / 2,
      y: group.y + group.height / 2,
      width: group.width,
      height: group.height,
      inline_style: None,
    }
  }
  for child in group.children {
    register_group_anchors(child, positioned_by_id, preserve_existing)
  }
}

///|
fn layout_graph_legacy_with_subgraph_redirects(
  graph : MermaidGraph,
  options : RenderOptions,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
  layout_engine : LayoutEngine,
) -> PositionedGraph {
  if is_sequence_graph(graph) {
    return @layout_engine_sequence_core.layout_sequence_graph(graph, options)
  }

  let base_padding = resolve_padding(options)
  let base_node_spacing = resolve_node_spacing(options)
  let base_layer_spacing = resolve_layer_spacing(options)
  let enable_target_boundary_ports = layout_engine is DagreParity
  let preserve_assigned_endpoint_ports = layout_engine is DagreParity
  let horizontal = layout_direction_is_horizontal(graph.direction)
  let reverse = layout_direction_is_reverse(graph.direction)
  let state_graph = is_state_graph(graph)
  let class_or_er_graph = is_class_or_er_graph(graph)
  let flat_state_graph = state_graph &&
    !horizontal &&
    graph.subgraphs.length() == 0

  let subgraph_entry_by_id : Map[String, String] = {}
  let subgraph_exit_by_id : Map[String, String] = {}
  if use_subgraph_redirects {
    for subgraph in graph.subgraphs {
      collect_subgraph_edge_redirects(
        subgraph, subgraph_entry_by_id, subgraph_exit_by_id,
      )
    }
  }
  let hidden_subgraph_node_ids : Map[String, Bool] = {}
  if use_subgraph_redirects {
    collect_hidden_subgraph_node_ids(
      graph.subgraphs,
      subgraph_entry_by_id,
      subgraph_exit_by_id,
      hidden_subgraph_node_ids,
    )
  }

  let mut nodes_in_order : Array[MermaidNode] = []
  for entry in graph.nodes.to_array() {
    let (node_id, node) = entry
    if !hidden_subgraph_node_ids.contains(node_id) {
      nodes_in_order.push(node)
    }
  }
  nodes_in_order = reorder_nodes_for_flow_layout(nodes_in_order, graph.edges)
  let enhanced_horizontal_state_flow = state_graph &&
    horizontal &&
    !compact_fanin &&
    use_enhanced_horizontal_state_flow_lanes(nodes_in_order)
  let padding = match options.padding {
    Some(_) => base_padding
    None => if enhanced_horizontal_state_flow { 10 } else { base_padding }
  }
  let node_spacing = if state_graph && horizontal && !compact_fanin {
    resolve_horizontal_state_node_spacing(
      options, nodes_in_order, base_node_spacing,
    )
  } else {
    base_node_spacing
  }
  let layer_spacing = base_layer_spacing
  let positioned_nodes : Array[PositionedNode] = []
  let positioned_by_id : Map[String, PositionedNode] = {}
  let state_lane_by_node_id : Map[String, Int] = {}
  let state_label_y_offset_by_node_id : Map[String, Int] = {}
  let flow_rank_by_node_id : Map[String, Int] = {}
  let flow_lane_by_node_id : Map[String, Int] = {}
  let flow_label_y_offset_by_rank : Map[Int, Int] = {}
  let mut refined_horizontal_non_state_flow = false
  let mut refined_horizontal_non_state_labeled_cycle_flow = false
  let mut horizontal_cycle_non_state_flow = false
  let mut flow_max_rank = 0
  if !state_graph || horizontal {
    let cycle_aware_layout = state_graph ||
      (!class_or_er_graph && graph_has_cycle(nodes_in_order, graph.edges))
    let adaptive_compact_fanin = !state_graph &&
      !class_or_er_graph &&
      horizontal &&
      cycle_aware_layout &&
      graph.subgraphs.length() > 0 &&
      graph.edges.length() >= 50
    let rank_compact_fanin = compact_fanin || adaptive_compact_fanin
    horizontal_cycle_non_state_flow = !state_graph &&
      horizontal &&
      cycle_aware_layout
    let promote_backward_dotted_edges = horizontal &&
      !state_graph &&
      !class_or_er_graph &&
      !cycle_aware_layout &&
      graph_has_definition_backward_dotted_edge(nodes_in_order, graph.edges)
    let preserve_dummy_lane_channels = !state_graph &&
      !class_or_er_graph &&
      (graph.subgraphs.length() > 0 || graph.edges.length() >= 30)
    let enable_cycle_rank_compaction = !state_graph &&
      !class_or_er_graph &&
      horizontal &&
      !rank_compact_fanin &&
      cycle_aware_layout &&
      graph.subgraphs.length() == 0 &&
      graph.edges.length() >= 30
    let prefer_definition_back_edges = !state_graph &&
      cycle_aware_layout &&
      !horizontal &&
      graph.edges.length() < 50
    let base_enable_feedback_back_edge_ordering = !state_graph &&
      !class_or_er_graph &&
      (
        horizontal ||
        (
          !horizontal &&
          cycle_aware_layout &&
          !prefer_definition_back_edges &&
          graph.edges.length() >= 60
        )
      )
    let use_greedy_feedback_arc_set = legacy_should_use_greedy_feedback_arc_set(
      graph, cycle_aware_layout, horizontal, state_graph, class_or_er_graph,
    )
    let preserve_reversed_back_edge_constraints = use_greedy_feedback_arc_set
    let enable_feedback_back_edge_ordering = base_enable_feedback_back_edge_ordering &&
      !use_greedy_feedback_arc_set
    let precomputed_lane_by_id : Map[String, Int] = {}
    let mut has_precomputed_lane_by_id = false
    let (baseline_rank_by_id, baseline_max_rank) = collect_non_state_flow_ranks(
      nodes_in_order,
      graph.edges,
      rank_compact_fanin,
      cycle_aware_layout,
      promote_backward_dotted_edges,
      prefer_definition_back_edges,
      false,
      use_greedy_feedback_arc_set,
      preserve_reversed_back_edge_constraints,
    )
    let mut selected_rank_by_id = baseline_rank_by_id
    let mut selected_max_rank = baseline_max_rank
    if enable_cycle_rank_compaction {
      let (compacted_rank_by_id, compacted_max_rank) = collect_non_state_flow_ranks(
        nodes_in_order,
        graph.edges,
        rank_compact_fanin,
        cycle_aware_layout,
        promote_backward_dotted_edges,
        prefer_definition_back_edges,
        true,
        use_greedy_feedback_arc_set,
        preserve_reversed_back_edge_constraints,
      )
      let baseline_lane_by_id = collect_non_state_flow_lanes(
        nodes_in_order,
        baseline_rank_by_id,
        baseline_max_rank,
        graph.edges,
        preserve_dummy_lane_channels,
        enable_feedback_back_edge_ordering,
        !class_or_er_graph,
      )
      let compacted_lane_by_id = collect_non_state_flow_lanes(
        nodes_in_order,
        compacted_rank_by_id,
        compacted_max_rank,
        graph.edges,
        preserve_dummy_lane_channels,
        enable_feedback_back_edge_ordering,
        !class_or_er_graph,
      )
      let baseline_lane_crossings = count_lane_space_edge_crossings(
        graph.edges,
        baseline_rank_by_id,
        baseline_lane_by_id,
      )
      let compacted_lane_crossings = count_lane_space_edge_crossings(
        graph.edges,
        compacted_rank_by_id,
        compacted_lane_by_id,
      )
      if compacted_lane_crossings < baseline_lane_crossings ||
        (
          compacted_lane_crossings == baseline_lane_crossings &&
          compacted_max_rank < baseline_max_rank
        ) {
        selected_rank_by_id = compacted_rank_by_id
        selected_max_rank = compacted_max_rank
        for node_id, lane in compacted_lane_by_id {
          precomputed_lane_by_id[node_id] = lane
        }
      } else {
        for node_id, lane in baseline_lane_by_id {
          precomputed_lane_by_id[node_id] = lane
        }
      }
      has_precomputed_lane_by_id = true
    }
    flow_max_rank = selected_max_rank
    for node_id, rank in selected_rank_by_id {
      flow_rank_by_node_id[node_id] = rank
    }
    if compact_fanin && !state_graph && graph.subgraphs.length() > 0 {
      let top_level_group_index_by_node_id : Map[String, Int] = {}
      for i, subgraph in graph.subgraphs {
        collect_top_level_group_index_by_node_id(
          subgraph, i, top_level_group_index_by_node_id,
        )
      }

      for group_index in 0..<graph.subgraphs.length() {
        let mut has_member = false
        let mut first_member_order = 0
        let mut min_group_rank = 0
        for order, node in nodes_in_order {
          match top_level_group_index_by_node_id.get(node.id) {
            Some(index) =>
              if index == group_index {
                let rank = option_int_or(flow_rank_by_node_id.get(node.id), 0)
                if !has_member {
                  has_member = true
                  first_member_order = order
                  min_group_rank = rank
                } else {
                  first_member_order = first_member_order.min(order)
                  min_group_rank = min_group_rank.min(rank)
                }
              }
            None => ()
          }
        }
        if !has_member {
          continue
        }

        let mut has_outside_before = false
        let mut max_outside_before_rank = 0
        for order, node in nodes_in_order {
          if order >= first_member_order {
            continue
          }
          if top_level_group_index_by_node_id.contains(node.id) {
            continue
          }
          let rank = option_int_or(flow_rank_by_node_id.get(node.id), 0)
          if !has_outside_before || rank > max_outside_before_rank {
            max_outside_before_rank = rank
            has_outside_before = true
          }
        }
        if !has_outside_before {
          continue
        }
        let desired_min_rank = max_outside_before_rank + 1
        if min_group_rank >= desired_min_rank {
          continue
        }
        let rank_delta = desired_min_rank - min_group_rank
        for node_id, index in top_level_group_index_by_node_id {
          if index == group_index {
            let current_rank = option_int_or(
              flow_rank_by_node_id.get(node_id),
              0,
            )
            flow_rank_by_node_id[node_id] = current_rank + rank_delta
          }
        }
      }
      flow_max_rank = 0
      for _, rank in flow_rank_by_node_id {
        flow_max_rank = flow_max_rank.max(rank)
      }
    }
    let lane_by_id = if has_precomputed_lane_by_id {
      precomputed_lane_by_id
    } else {
      collect_non_state_flow_lanes(
        nodes_in_order,
        flow_rank_by_node_id,
        flow_max_rank,
        graph.edges,
        preserve_dummy_lane_channels,
        enable_feedback_back_edge_ordering,
        !class_or_er_graph,
      )
    }
    for node_id, lane in lane_by_id {
      flow_lane_by_node_id[node_id] = lane
    }
    let compact_non_state_refined_spacing = !state_graph &&
      horizontal &&
      !compact_fanin &&
      graph.edges.any(edge => edge.style is Dotted) &&
      (cycle_aware_layout || promote_backward_dotted_edges)
    let has_edge_labels = graph.edges.any(edge => edge.label is Some(_))
    let allow_labeled_cycle_optional_refinement = has_edge_labels &&
      cycle_aware_layout &&
      graph.edges.length() >= 5 &&
      graph.edges.length() <= 8
    let non_state_optional_lane_refinement = !state_graph &&
      horizontal &&
      !compact_fanin &&
      !preserve_dummy_lane_channels &&
      !compact_non_state_refined_spacing &&
      (!has_edge_labels || allow_labeled_cycle_optional_refinement)
    let optional_labeled_cycle_lane_refinement = non_state_optional_lane_refinement &&
      allow_labeled_cycle_optional_refinement
    let use_horizontal_lane_refinement = if state_graph {
      horizontal && !compact_fanin
    } else {
      compact_non_state_refined_spacing || non_state_optional_lane_refinement
    }
    if use_horizontal_lane_refinement {
      let baseline_lane_by_id : Map[String, Int] = {}
      let baseline_lane_crossings = if non_state_optional_lane_refinement {
        for node in nodes_in_order {
          baseline_lane_by_id[node.id] = option_int_or(
            flow_lane_by_node_id.get(node.id),
            0,
          )
        }
        count_lane_space_edge_crossings(
          graph.edges,
          flow_rank_by_node_id,
          baseline_lane_by_id,
        )
      } else {
        0
      }
      let baseline_lane_span = if non_state_optional_lane_refinement {
        lane_span(nodes_in_order, baseline_lane_by_id)
      } else {
        0
      }
      if !state_graph {
        refined_horizontal_non_state_flow = compact_non_state_refined_spacing ||
          optional_labeled_cycle_lane_refinement
        refined_horizontal_non_state_labeled_cycle_flow = optional_labeled_cycle_lane_refinement
      }
      let enhanced_horizontal_flow = if state_graph {
        enhanced_horizontal_state_flow
      } else {
        compact_non_state_refined_spacing
      }
      refine_horizontal_state_flow_lanes(
        nodes_in_order,
        graph.edges,
        flow_rank_by_node_id,
        flow_lane_by_node_id,
        enhanced_horizontal_flow,
      )
      if non_state_optional_lane_refinement {
        let refined_lane_crossings = count_lane_space_edge_crossings(
          graph.edges,
          flow_rank_by_node_id,
          flow_lane_by_node_id,
        )
        let refined_lane_span = lane_span(nodes_in_order, flow_lane_by_node_id)
        let reject_refined = if optional_labeled_cycle_lane_refinement {
          refined_lane_crossings > baseline_lane_crossings ||
          refined_lane_span < baseline_lane_span
        } else {
          refined_lane_crossings >= baseline_lane_crossings ||
          refined_lane_span < baseline_lane_span
        }
        if reject_refined {
          refined_horizontal_non_state_flow = false
          refined_horizontal_non_state_labeled_cycle_flow = false
          for node in nodes_in_order {
            flow_lane_by_node_id[node.id] = option_int_or(
              baseline_lane_by_id.get(node.id),
              option_int_or(flow_lane_by_node_id.get(node.id), 0),
            )
          }
        }
      }
    }
    if !horizontal &&
      graph.subgraphs.length() > 0 &&
      graph.edges.any(edge => edge.label is Some(_)) {
      let forward_extra_units_by_rank : Map[Int, Int] = {}
      let single_forward_adjust_by_rank : Map[Int, Int] = {}
      let forward_labeled_out_degree_by_source : Map[String, Int] = {}
      let label_row_units = 18
      for edge in graph.edges {
        match
          (
            flow_rank_by_node_id.get(edge.source),
            flow_rank_by_node_id.get(edge.target),
            edge.label,
          ) {
          (Some(source_rank), Some(target_rank), Some(_)) =>
            if target_rank > source_rank {
              let current = option_int_or(
                forward_labeled_out_degree_by_source.get(edge.source),
                0,
              )
              forward_labeled_out_degree_by_source[edge.source] = current + 1
            }
          _ => ()
        }
      }
      for edge in graph.edges {
        match
          (
            flow_rank_by_node_id.get(edge.source),
            flow_rank_by_node_id.get(edge.target),
            edge.label,
          ) {
          (Some(source_rank), Some(target_rank), Some(_)) =>
            if target_rank > source_rank {
              let forward_labeled_out_degree = option_int_or(
                forward_labeled_out_degree_by_source.get(edge.source),
                0,
              )
              if forward_labeled_out_degree > 1 {
                let current = option_int_or(
                  forward_extra_units_by_rank.get(target_rank),
                  0,
                )
                forward_extra_units_by_rank[target_rank] = current +
                  label_row_units
              } else if forward_labeled_out_degree == 1 {
                let current_adjust = option_int_or(
                  single_forward_adjust_by_rank.get(target_rank),
                  0,
                )
                let candidate_adjust = label_row_units / 2
                if candidate_adjust > current_adjust {
                  single_forward_adjust_by_rank[target_rank] = candidate_adjust
                }
              }
            }
          _ => ()
        }
      }
      let mut cumulative_offset = 0
      for rank in 0..<=flow_max_rank {
        cumulative_offset += option_int_or(
          forward_extra_units_by_rank.get(rank),
          0,
        )
        cumulative_offset -= option_int_or(
          single_forward_adjust_by_rank.get(rank),
          0,
        )
        if cumulative_offset < 0 {
          cumulative_offset = 0
        }
        flow_label_y_offset_by_rank[rank] = cumulative_offset
      }
    }
  }

  if flat_state_graph {
    let node_order_by_id : Map[String, Int] = {}
    let node_shape_by_id : Map[String, NodeShape] = {}
    let lane_assigned : Map[String, Bool] = {}
    for i, node in nodes_in_order {
      node_order_by_id[node.id] = i
      node_shape_by_id[node.id] = node.shape
      state_lane_by_node_id[node.id] = 0
    }

    for node in nodes_in_order {
      match node.shape {
        StateStart | StateEnd => ()
        _ => {
          lane_assigned[node.id] = true
          break
        }
      }
    }

    let forward_extra_rows_by_order : Map[Int, Int] = {}
    for edge in graph.edges {
      let source_order = option_int_or(node_order_by_id.get(edge.source), -1)
      let target_order = option_int_or(node_order_by_id.get(edge.target), -1)
      if source_order < 0 || target_order < 0 || target_order <= source_order {
        continue
      }
      let mut extra_rows = 0
      if edge.label is Some(_) {
        extra_rows += 1
      }
      let target_is_state_end = match node_shape_by_id.get(edge.target) {
        Some(shape) =>
          match shape {
            StateEnd => true
            _ => false
          }
        None => false
      }
      if target_is_state_end {
        extra_rows += 2
      }
      if extra_rows <= 0 {
        continue
      }
      let current = option_int_or(
        forward_extra_rows_by_order.get(target_order),
        0,
      )
      forward_extra_rows_by_order[target_order] = current + extra_rows
    }
    let label_row_units = 10
    let mut cumulative_label_offset = 0
    for i, node in nodes_in_order {
      let step_count = option_int_or(forward_extra_rows_by_order.get(i), 0)
      cumulative_label_offset += step_count * label_row_units
      state_label_y_offset_by_node_id[node.id] = cumulative_label_offset
    }

    let forward_targets_by_source : Map[String, Array[String]] = {}
    for edge in graph.edges {
      let source_order = option_int_or(node_order_by_id.get(edge.source), -1)
      let target_order = option_int_or(node_order_by_id.get(edge.target), -1)
      if source_order < 0 || target_order < 0 || target_order <= source_order {
        continue
      }

      let target_is_pseudostate = match node_shape_by_id.get(edge.target) {
        Some(shape) =>
          match shape {
            StateStart | StateEnd => true
            _ => false
          }
        None => false
      }
      if target_is_pseudostate {
        continue
      }

      if !forward_targets_by_source.contains(edge.source) {
        forward_targets_by_source[edge.source] = []
      }
      let targets = forward_targets_by_source[edge.source]
      if !targets.contains(edge.target) {
        targets.push(edge.target)
      }
    }

    for node in nodes_in_order {
      let source_lane = option_int_or(state_lane_by_node_id.get(node.id), 0)
      match forward_targets_by_source.get(node.id) {
        Some(targets) =>
          for i, target_id in targets {
            if lane_assigned.contains(target_id) {
              continue
            }
            state_lane_by_node_id[target_id] = source_lane + i * 2
            lane_assigned[target_id] = true
          }
        None => ()
      }
    }
  }

  let max_width_by_flow_rank_index : Map[Int, Int] = {}
  let node_width_by_id : Map[String, Int] = {}
  for node in nodes_in_order {
    let (width, _) = node_dimensions(node)
    node_width_by_id[node.id] = width
    let flow_rank = option_int_or(flow_rank_by_node_id.get(node.id), 0)
    let flow_rank_index = if reverse {
      flow_max_rank - flow_rank
    } else {
      flow_rank
    }
    let current_max = option_int_or(
      max_width_by_flow_rank_index.get(flow_rank_index),
      0,
    )
    if width > current_max {
      max_width_by_flow_rank_index[flow_rank_index] = width
    }
  }

  // Apply minimal rank shifts only where wide labels would collapse adjacent
  // horizontal ranks, preserving compaction on normal-width graphs.
  let horizontal_label_min_boundary_extra_by_index : Map[Int, Int] = {}
  if horizontal {
    let label_rank_constraints = collect_horizontal_label_rank_constraints(
      graph.edges,
      flow_rank_by_node_id,
      flow_max_rank,
      reverse,
      node_width_by_id,
      node_spacing,
      use_subgraph_redirects,
      subgraph_exit_by_id,
      subgraph_entry_by_id,
    )
    let min_shift_by_rank_index = solve_horizontal_label_rank_shifts(
      flow_max_rank, label_rank_constraints,
    )
    let boundary_extra_by_index = horizontal_label_boundary_extra_by_rank_index(
      flow_max_rank, min_shift_by_rank_index,
    )
    for rank_index, extra in boundary_extra_by_index {
      horizontal_label_min_boundary_extra_by_index[rank_index] = extra
    }
  }

  // Apply minimal rank shifts only where wide nodes or labeled edges would
  // collapse adjacent horizontal ranks, preserving compaction on normal-width graphs.
  let horizontal_rank_shift_by_index : Map[Int, Int] = {}
  if horizontal {
    let min_horizontal_rank_clearance = (node_spacing / 3).max(24)
    let mut running_shift = 0
    for flow_rank_index in 0..<=flow_max_rank {
      horizontal_rank_shift_by_index[flow_rank_index] = running_shift
      if flow_rank_index == flow_max_rank {
        continue
      }
      let label_boundary_extra = option_int_or(
        horizontal_label_min_boundary_extra_by_index.get(flow_rank_index),
        0,
      )
      let current_width = option_int_or(
        max_width_by_flow_rank_index.get(flow_rank_index),
        0,
      )
      let current_left = padding +
        flow_rank_index * node_spacing +
        running_shift
      let current_right = current_left + current_width
      let next_left = padding +
        (flow_rank_index + 1) * node_spacing +
        running_shift
      let required_next_left = current_right + min_horizontal_rank_clearance
      let node_boundary_extra = if next_left < required_next_left {
        required_next_left - next_left
      } else {
        0
      }
      let boundary_extra = node_boundary_extra.max(label_boundary_extra)
      if boundary_extra > 0 {
        running_shift += boundary_extra
      }
    }
  }
  let horizontal_rank_center_x_by_index : Map[Int, Int] = {}
  if horizontal && horizontal_cycle_non_state_flow {
    for flow_rank_index in 0..<=flow_max_rank {
      let rank_width = option_int_or(
        max_width_by_flow_rank_index.get(flow_rank_index),
        0,
      )
      let rank_shift = option_int_or(
        horizontal_rank_shift_by_index.get(flow_rank_index),
        0,
      )
      horizontal_rank_center_x_by_index[flow_rank_index] = padding +
        flow_rank_index * node_spacing +
        rank_shift +
        rank_width / 2
    }
  }

  let mut max_right = padding
  let mut max_bottom = padding

  let total_nodes = nodes_in_order.length()
  let state_lane_step = (node_spacing / 3).max(26)
  for i, node in nodes_in_order {
    let order_index = if reverse { total_nodes - 1 - i } else { i }
    let (width, height) = node_dimensions(node)
    let flow_rank = option_int_or(flow_rank_by_node_id.get(node.id), 0)
    let flow_lane = option_int_or(flow_lane_by_node_id.get(node.id), 0)
    let flow_rank_index = if reverse {
      flow_max_rank - flow_rank
    } else {
      flow_rank
    }
    let x = if horizontal {
      if horizontal_cycle_non_state_flow {
        option_int_or(
          horizontal_rank_center_x_by_index.get(flow_rank_index),
          padding + flow_rank_index * node_spacing + width / 2,
        )
      } else {
        let rank_shift = option_int_or(
          horizontal_rank_shift_by_index.get(flow_rank_index),
          0,
        )
        padding + flow_rank_index * node_spacing + rank_shift + width / 2
      }
    } else if flat_state_graph {
      padding +
      90 +
      option_int_or(state_lane_by_node_id.get(node.id), 0) * state_lane_step
    } else if state_graph {
      padding + 90
    } else {
      padding + 90 + flow_lane * node_spacing
    }
    let y = if horizontal {
      if enhanced_horizontal_state_flow {
        padding + 70 + flow_lane * layer_spacing / 4
      } else if state_graph && !compact_fanin {
        padding + 70 + flow_lane * layer_spacing / 2
      } else if refined_horizontal_non_state_labeled_cycle_flow {
        padding + 70 + flow_lane * layer_spacing / 2
      } else if refined_horizontal_non_state_flow {
        padding + 70 + flow_lane * layer_spacing / 3
      } else {
        padding + 70 + flow_lane * layer_spacing
      }
    } else if state_graph {
      padding +
      order_index * layer_spacing +
      height / 2 +
      option_int_or(state_label_y_offset_by_node_id.get(node.id), 0)
    } else {
      padding +
      flow_rank_index * layer_spacing +
      height / 2 +
      option_int_or(flow_label_y_offset_by_rank.get(flow_rank_index), 0)
    }
    let positioned = PositionedNode::{
      id: node.id,
      label: node.label,
      shape: node.shape,
      x,
      y,
      width,
      height,
      inline_style: resolve_inline_style(graph, node.id),
    }
    positioned_nodes.push(positioned)
    positioned_by_id[node.id] = positioned
    max_right = max_right.max(x + width / 2)
    max_bottom = max_bottom.max(y + height / 2)
  }

  let positioned_index_by_id : Map[String, Int] = {}
  for i, node in positioned_nodes {
    positioned_index_by_id[node.id] = i
  }
  let node_horizontal_by_id : Map[String, Bool] = {}
  if state_graph {
    apply_subgraph_direction_overrides(
      graph.subgraphs,
      horizontal,
      reverse,
      false,
      horizontal,
      reverse,
      node_spacing,
      layer_spacing,
      positioned_nodes,
      positioned_index_by_id,
      node_horizontal_by_id,
    )
  }

  max_right = padding
  max_bottom = padding
  for node in positioned_nodes {
    positioned_by_id[node.id] = node
    max_right = max_right.max(node.x + node.width / 2)
    max_bottom = max_bottom.max(node.y + node.height / 2)
  }

  let positioned_groups : Array[PositionedGroup] = []
  let mut empty_group_top = padding
  for subgraph in graph.subgraphs {
    match
      build_positioned_group(subgraph, positioned_by_id, horizontal, reverse) {
      Some(group) => positioned_groups.push(group)
      None => {
        let empty_group = build_empty_group_tree_at(
          subgraph, padding, empty_group_top, horizontal, reverse,
        )
        positioned_groups.push(empty_group)
        empty_group_top = empty_group_top +
          empty_group.height +
          subgraph_group_padding()
      }
    }
  }

  if state_graph {
    shift_top_level_state_subgraphs_right(
      graph, node_spacing, layer_spacing, positioned_nodes, positioned_groups, positioned_index_by_id,
      positioned_by_id,
    )
  } else {
    shift_top_level_flow_subgraphs_with_gap(
      graph, horizontal, reverse, layer_spacing, positioned_nodes, positioned_groups,
      positioned_index_by_id, positioned_by_id,
    )
  }

  for group in positioned_groups {
    register_group_anchors(group, positioned_by_id, state_graph)
  }

  let positioned_edges : Array[PositionedEdge] = []
  let routed_edge_segments : Array[RoutedEdgeSegment] = []
  let label_slots_by_anchor : Map[String, Int] = {}
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

  fn forward_fanout_bucket(
    source_id : String,
    edge_horizontal : Bool,
  ) -> String {
    if edge_horizontal {
      "h:\{source_id}"
    } else {
      "v:\{source_id}"
    }
  }

  fn directed_edge_key(source_id : String, target_id : String) -> String {
    "\{source_id}->\{target_id}"
  }

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
        int_abs(context.target.x - context.source.x) >=
        horizontal_span_threshold ||
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
      int_abs(context.target.x - context.source.x) <=
      vertical_minor_gap_threshold
    }
  }

  fn context_forward_fanout_minor_key(context : EdgeLayoutContext) -> Int {
    if context.edge_horizontal {
      context.target.y
    } else {
      context.target.x
    }
  }

  fn context_forward_fanout_major_key(context : EdgeLayoutContext) -> Int {
    if context.edge_horizontal {
      context.target.x
    } else {
      context.target.y
    }
  }

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
      if graph.edges.length() > 20 ||
        peer_minor_assignments.length() <= 1 ||
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
        let defer_source_assignment_to_cohort = graph.edges.length() <= 20 &&
          assignment.source_endpoint &&
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

    if graph.edges.length() <= 20 &&
      assignments.length() <= 3 &&
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

    if graph.edges.length() <= 20 &&
      assignments.length() <= 4 &&
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
        )
      }
    }

    let has_source_target_offset_conflict = bucket_has_source_target_offset_conflict(
      assignments, source_boundary_offset_by_context_index, target_boundary_offset_by_context_index,
      edge_layout_contexts,
    )
    if !class_or_er_graph &&
      graph.edges.length() <= 30 &&
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
        (
          !state_graph &&
          graph.edges.length() <= 20 &&
          resolved_target_offset != 0
        ) {
        resolved_target_offset
      } else {
        0
      },
    }
  }

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

  fn copy_context_index_order(order : Array[Int]) -> Array[Int] {
    let copied : Array[Int] = []
    for context_index in order {
      copied.push(context_index)
    }
    copied
  }

  fn maybe_resolve_forward_fanout_slots_for_bucket(
    bucket_key : String,
    total : Int,
    edge_layout_contexts : Array[EdgeLayoutContext],
    forward_fanout_context_indices_by_bucket : Map[String, Array[Int]],
    forward_fanout_slot_by_context_index : Map[Int, Int],
    forward_fanout_slots_resolved_by_bucket : Map[String, Bool],
    routed_polylines : Array[Array[Point]],
    enhanced_horizontal_state_flow : Bool,
  ) -> Unit {
    if total <= 1 ||
      forward_fanout_slots_resolved_by_bucket.contains(bucket_key) {
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
        let points = edge_points_for_with_ports(
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
        let points = edge_points_for_with_ports(
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

    fn sort_forward_fanout_order(
      order : Array[Int],
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

    let candidate_orders : Array[Array[Int]] = []
    candidate_orders.push(copy_context_index_order(bucket_context_indices))

    let ascending_minor = copy_context_index_order(bucket_context_indices)
    sort_forward_fanout_order(ascending_minor, false, false, false)
    candidate_orders.push(ascending_minor)

    let descending_minor = copy_context_index_order(bucket_context_indices)
    sort_forward_fanout_order(descending_minor, true, false, false)
    candidate_orders.push(descending_minor)

    let ascending_major = copy_context_index_order(bucket_context_indices)
    sort_forward_fanout_order(ascending_major, false, false, true)
    candidate_orders.push(ascending_major)

    let descending_major = copy_context_index_order(bucket_context_indices)
    sort_forward_fanout_order(descending_major, false, true, true)
    candidate_orders.push(descending_major)

    let unique_candidate_orders : Array[Array[Int]] = []
    let seen_candidate_signatures : Map[String, Bool] = {}
    for candidate_order in candidate_orders {
      let signature = deferred_order_signature(candidate_order)
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
          routed_polylines, enhanced_horizontal_state_flow,
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
    let raw_base_points_with_ports = edge_points_for_with_ports(
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
        let base_points_without_ports = edge_points_for_with_ports(
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
      let signature = deferred_order_signature(candidate_order)
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
      let points = edge_points_for_with_ports(
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

  let mut global_min_x = padding
  let mut global_min_y = padding
  let mut global_max_x = max_right
  let mut global_max_y = max_bottom

  for node in positioned_nodes {
    global_min_x = global_min_x.min(node.x - node.width / 2)
    global_min_y = global_min_y.min(node.y - node.height / 2)
    global_max_x = global_max_x.max(node.x + node.width / 2)
    global_max_y = global_max_y.max(node.y + node.height / 2)
  }
  for edge in positioned_edges {
    for point in edge.points {
      global_min_x = global_min_x.min(point.x)
      global_min_y = global_min_y.min(point.y)
      global_max_x = global_max_x.max(point.x)
      global_max_y = global_max_y.max(point.y)
    }
    match edge.label_position {
      Some(position) => {
        global_min_x = global_min_x.min(position.x)
        global_min_y = global_min_y.min(position.y)
        global_max_x = global_max_x.max(position.x)
        global_max_y = global_max_y.max(position.y)
      }
      None => ()
    }
  }
  for group in positioned_groups {
    global_min_x = global_min_x.min(positioned_group_min_x(group))
    global_min_y = global_min_y.min(positioned_group_min_y(group))
    global_max_x = global_max_x.max(positioned_group_max_x(group))
    global_max_y = global_max_y.max(positioned_group_max_y(group))
  }

  let shift_x = if global_min_x < padding { padding - global_min_x } else { 0 }
  let shift_y = if global_min_y < padding { padding - global_min_y } else { 0 }
  if shift_x > 0 || shift_y > 0 {
    for i, node in positioned_nodes {
      positioned_nodes[i] = {
        id: node.id,
        label: node.label,
        shape: node.shape,
        x: node.x + shift_x,
        y: node.y + shift_y,
        width: node.width,
        height: node.height,
        inline_style: node.inline_style,
      }
    }
    for i, edge in positioned_edges {
      let shifted_points : Array[Point] = []
      for point in edge.points {
        shifted_points.push({ x: point.x + shift_x, y: point.y + shift_y })
      }
      let shifted_label = match edge.label_position {
        Some(position) =>
          Some(Point::{ x: position.x + shift_x, y: position.y + shift_y })
        None => None
      }
      positioned_edges[i] = {
        source: edge.source,
        target: edge.target,
        label: edge.label,
        style: edge.style,
        has_arrow_start: edge.has_arrow_start,
        has_arrow_end: edge.has_arrow_end,
        relation_operator: edge.relation_operator,
        points: shifted_points,
        label_position: shifted_label,
      }
    }
    for i, group in positioned_groups {
      positioned_groups[i] = shift_positioned_group(group, shift_x, shift_y)
    }
  }

  {
    width: global_max_x + shift_x + padding,
    height: global_max_y + shift_y + padding,
    nodes: positioned_nodes,
    edges: positioned_edges,
    groups: positioned_groups,
    sequence_lifelines: [],
    sequence_activations: [],
    sequence_blocks: [],
    sequence_notes: [],
  }
}
