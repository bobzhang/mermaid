///|
/// Computes legacy lane and rank assignments for graph layout.
pub fn compute_legacy_lane_state(
  graph : MermaidGraph,
  nodes_in_order : Array[MermaidNode],
  state_graph : Bool,
  class_or_er_graph : Bool,
  horizontal : Bool,
  compact_fanin : Bool,
  enhanced_horizontal_state_flow : Bool,
  flat_state_graph : Bool,
) -> (
  Map[String, Int],
  Map[String, Int],
  Map[String, Int],
  Map[String, Int],
  Map[Int, Int],
  Bool,
  Bool,
  Bool,
  Int,
) {
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

  (
    state_lane_by_node_id, state_label_y_offset_by_node_id, flow_rank_by_node_id,
    flow_lane_by_node_id, flow_label_y_offset_by_rank, refined_horizontal_non_state_flow,
    refined_horizontal_non_state_labeled_cycle_flow, horizontal_cycle_non_state_flow,
    flow_max_rank,
  )
}
