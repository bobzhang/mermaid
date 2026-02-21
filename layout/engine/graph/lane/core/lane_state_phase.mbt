///|
/// Legacy lane/rank phase output consumed by placement and routing phases.
pub(all) struct LegacyLaneState {
  state_lane_by_node_id : Map[String, Int]
  state_label_y_offset_by_node_id : Map[String, Int]
  flow_rank_by_node_id : Map[String, Int]
  flow_lane_by_node_id : Map[String, Int]
  flow_label_y_offset_by_rank : Map[Int, Int]
  refined_horizontal_non_state_flow : Bool
  refined_horizontal_non_state_labeled_cycle_flow : Bool
  flow_max_rank : Int
  dagre_parity_rank_nodes : Array[Array[String]]
}

///|
/// Public snapshot for a single dagre parity sweep step.
pub(all) struct DagreParityOrderSweepStep {
  pass_index : Int
  incoming_from_neighbor : Bool
  bias_right : Bool
  candidate_crossings : Int
  barycenters_by_rank : Map[Int, Map[String, String]]
  rank_nodes : Array[Array[String]]
}

///|
/// Public trace payload for dagre parity ordering.
pub(all) struct DagreParityOrderTrace {
  rank_nodes_trace : Array[Array[Array[String]]]
  sweep_step_trace : Array[DagreParityOrderSweepStep]
}

///|
priv struct NonStateFlowRankCandidate {
  use_greedy_feedback_arc_set : Bool
  rank_by_id : Map[String, Int]
  max_rank : Int
  lane_by_id : Map[String, Int]
  lane_crossings : Int
  lane_span : Int
  max_rank_load : Int
  total_rank_edge_span : Int
}

///|
fn collect_rank_peak_load(
  nodes_in_order : Array[MermaidNode],
  rank_by_id : Map[String, Int],
) -> Int {
  let rank_load_by_rank : Map[Int, Int] = {}
  let mut peak_load = 0
  for node in nodes_in_order {
    let rank = option_int_or(rank_by_id.get(node.id), 0)
    let next_load = option_int_or(rank_load_by_rank.get(rank), 0) + 1
    rank_load_by_rank[rank] = next_load
    if next_load > peak_load {
      peak_load = next_load
    }
  }
  peak_load
}

///|
fn collect_total_rank_edge_span(
  edges : Array[MermaidEdge],
  rank_by_id : Map[String, Int],
) -> Int {
  let mut total_rank_edge_span = 0
  for edge in edges {
    if edge.source == edge.target {
      continue
    }
    match (rank_by_id.get(edge.source), rank_by_id.get(edge.target)) {
      (Some(source_rank), Some(target_rank)) =>
        total_rank_edge_span += int_abs(target_rank - source_rank)
      _ => ()
    }
  }
  total_rank_edge_span
}

///|
fn collect_non_state_flow_rank_candidate(
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
  subgraphs : Array[MermaidSubgraph],
  _horizontal : Bool,
  rank_compact_fanin : Bool,
  cycle_aware_layout : Bool,
  promote_backward_dotted_edges : Bool,
  prefer_definition_back_edges : Bool,
  compact_cycle_ranks_toward_sinks : Bool,
  preserve_dummy_lane_channels : Bool,
  base_enable_feedback_back_edge_ordering : Bool,
  preserve_fanout_order_ties : Bool,
  use_greedy_feedback_arc_set : Bool,
  prefer_dagre_network_simplex : Bool,
  prefer_dagre_order_parity : Bool,
) -> NonStateFlowRankCandidate {
  let preserve_reversed_back_edge_constraints = use_greedy_feedback_arc_set
  let enable_feedback_back_edge_ordering = base_enable_feedback_back_edge_ordering &&
    !use_greedy_feedback_arc_set
  let fallback_rank_result = collect_non_state_flow_ranks(
    nodes_in_order, edges, rank_compact_fanin, cycle_aware_layout, promote_backward_dotted_edges,
    prefer_definition_back_edges, compact_cycle_ranks_toward_sinks, use_greedy_feedback_arc_set,
    preserve_reversed_back_edge_constraints, prefer_dagre_network_simplex,
  )
  let raw_rank_result = if prefer_dagre_network_simplex && !rank_compact_fanin {
    let acyclic_phase_state = collect_non_state_flow_acyclic_phase_state(
      nodes_in_order, edges, prefer_definition_back_edges, use_greedy_feedback_arc_set,
    )
    let dagre_rank_edge_specs = collect_dagre_rank_edge_specs(
      edges,
      acyclic_phase_state.relaxed_edge_indices,
      acyclic_phase_state.reversed_back_edge_indices,
    )
    let base_edge_specs = scale_rank_edge_spec_minlen(dagre_rank_edge_specs, 2)
    let (nested_rank_by_id, nested_max_rank, nested_ok) = collect_dagre_nesting_rank_result(
      nodes_in_order, base_edge_specs, subgraphs,
    )
    if nested_ok {
      (nested_rank_by_id, nested_max_rank)
    } else {
      fallback_rank_result
    }
  } else {
    fallback_rank_result
  }
  let (rank_by_id, max_rank) = raw_rank_result
  let lane_by_id = collect_non_state_flow_lanes(
    nodes_in_order,
    rank_by_id,
    max_rank,
    edges,
    preserve_dummy_lane_channels,
    enable_feedback_back_edge_ordering,
    preserve_fanout_order_ties,
    prefer_dagre_order_parity,
    subgraphs.length() > 0,
  )
  let lane_crossings = count_lane_space_edge_crossings(
    edges, rank_by_id, lane_by_id,
  )
  let candidate_lane_span = lane_span(nodes_in_order, lane_by_id)
  let max_rank_load = collect_rank_peak_load(nodes_in_order, rank_by_id)
  let total_rank_edge_span = collect_total_rank_edge_span(edges, rank_by_id)
  {
    use_greedy_feedback_arc_set,
    rank_by_id,
    max_rank,
    lane_by_id,
    lane_crossings,
    lane_span: candidate_lane_span,
    max_rank_load,
    total_rank_edge_span,
  }
}

///|
fn non_state_flow_rank_candidate_score(
  candidate : NonStateFlowRankCandidate,
) -> Int {
  candidate.lane_crossings * 10000 +
  candidate.max_rank_load * 2000 +
  candidate.total_rank_edge_span * 30 +
  candidate.lane_span * 20 +
  candidate.max_rank * 5
}

///|
fn select_non_state_flow_rank_candidate(
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
  subgraphs : Array[MermaidSubgraph],
  horizontal : Bool,
  rank_compact_fanin : Bool,
  cycle_aware_layout : Bool,
  promote_backward_dotted_edges : Bool,
  prefer_definition_back_edges : Bool,
  preserve_dummy_lane_channels : Bool,
  base_enable_feedback_back_edge_ordering : Bool,
  preserve_fanout_order_ties : Bool,
  default_use_greedy_feedback_arc_set : Bool,
  allow_feedback_strategy_selection : Bool,
  prefer_dagre_network_simplex : Bool,
  prefer_dagre_order_parity : Bool,
) -> NonStateFlowRankCandidate {
  let default_candidate = collect_non_state_flow_rank_candidate(
    nodes_in_order, edges, subgraphs, horizontal, rank_compact_fanin, cycle_aware_layout,
    promote_backward_dotted_edges, prefer_definition_back_edges, false, preserve_dummy_lane_channels,
    base_enable_feedback_back_edge_ordering, preserve_fanout_order_ties, default_use_greedy_feedback_arc_set,
    prefer_dagre_network_simplex, prefer_dagre_order_parity,
  )
  if !allow_feedback_strategy_selection {
    return default_candidate
  }
  let alternative_candidate = collect_non_state_flow_rank_candidate(
    nodes_in_order,
    edges,
    subgraphs,
    horizontal,
    rank_compact_fanin,
    cycle_aware_layout,
    promote_backward_dotted_edges,
    prefer_definition_back_edges,
    false,
    preserve_dummy_lane_channels,
    base_enable_feedback_back_edge_ordering,
    preserve_fanout_order_ties,
    !default_use_greedy_feedback_arc_set,
    prefer_dagre_network_simplex,
    prefer_dagre_order_parity,
  )
  let default_score = non_state_flow_rank_candidate_score(default_candidate)
  let alternative_score = non_state_flow_rank_candidate_score(
    alternative_candidate,
  )
  if alternative_score < default_score {
    alternative_candidate
  } else {
    default_candidate
  }
}

///|
fn select_default_use_greedy_feedback_arc_set(
  graph : MermaidGraph,
  cycle_aware_layout : Bool,
  horizontal : Bool,
  state_graph : Bool,
  class_or_er_graph : Bool,
  prefer_dagre_network_simplex : Bool,
) -> Bool {
  // Mermaid's dagre renderer does not set acyclicer, so dagre defaults to
  // DFS FAS. Dagre-parity mode should keep that behavior.
  if prefer_dagre_network_simplex {
    false
  } else {
    legacy_should_use_greedy_feedback_arc_set(
      graph, cycle_aware_layout, horizontal, state_graph, class_or_er_graph,
    )
  }
}

///|
fn scale_rank_edge_spec_minlen(
  edge_specs : Array[DagreRankEdgeSpec],
  minlen_factor : Int,
) -> Array[DagreRankEdgeSpec] {
  if minlen_factor <= 1 {
    return edge_specs.copy()
  }
  let scaled_specs : Array[DagreRankEdgeSpec] = []
  for edge_spec in edge_specs {
    scaled_specs.push({
      source_id: edge_spec.source_id,
      target_id: edge_spec.target_id,
      minlen: edge_spec.minlen.max(0) * minlen_factor,
      weight: edge_spec.weight,
      nesting_edge: edge_spec.nesting_edge,
    })
  }
  scaled_specs
}

///|
fn should_allow_feedback_strategy_selection(
  graph : MermaidGraph,
  cycle_aware_layout : Bool,
  horizontal : Bool,
  state_graph : Bool,
  class_or_er_graph : Bool,
  prefer_dagre_network_simplex : Bool,
) -> Bool {
  !prefer_dagre_network_simplex &&
  !state_graph &&
  !class_or_er_graph &&
  cycle_aware_layout &&
  graph.edges.length() >= 40 &&
  (graph.subgraphs.length() > 0 || !horizontal)
}

///|
fn select_primary_non_state_flow_rank_candidate(
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
  subgraphs : Array[MermaidSubgraph],
  horizontal : Bool,
  rank_compact_fanin : Bool,
  cycle_aware_layout : Bool,
  promote_backward_dotted_edges : Bool,
  prefer_definition_back_edges : Bool,
  preserve_dummy_lane_channels : Bool,
  base_enable_feedback_back_edge_ordering : Bool,
  preserve_fanout_order_ties : Bool,
  default_use_greedy_feedback_arc_set : Bool,
  allow_feedback_strategy_selection : Bool,
  prefer_dagre_network_simplex : Bool,
) -> NonStateFlowRankCandidate {
  let prefer_dagre_order_parity = prefer_dagre_network_simplex
  select_non_state_flow_rank_candidate(
    nodes_in_order, edges, subgraphs, horizontal, rank_compact_fanin, cycle_aware_layout,
    promote_backward_dotted_edges, prefer_definition_back_edges, preserve_dummy_lane_channels,
    base_enable_feedback_back_edge_ordering, preserve_fanout_order_ties, default_use_greedy_feedback_arc_set,
    allow_feedback_strategy_selection, prefer_dagre_network_simplex, prefer_dagre_order_parity,
  )
}

///|
/// Collect dagre parity ordering traces from an existing rank assignment.
pub fn collect_dagre_parity_order_trace(
  nodes_in_order : Array[MermaidNode],
  rank_by_id : Map[String, Int],
  max_rank : Int,
  edges : Array[MermaidEdge],
) -> DagreParityOrderTrace {
  let rank_nodes_trace : Array[Array[Array[String]]] = []
  let internal_sweep_step_trace : Array[DagreParitySweepStepTrace] = []
  let _ = collect_non_state_flow_lanes_internal(
    nodes_in_order,
    rank_by_id,
    max_rank,
    edges,
    false,
    false,
    false,
    true,
    false,
    Some(rank_nodes_trace),
    Some(internal_sweep_step_trace),
  )
  let sweep_step_trace : Array[DagreParityOrderSweepStep] = []
  for step in internal_sweep_step_trace {
    sweep_step_trace.push({
      pass_index: step.pass_index,
      incoming_from_neighbor: step.incoming_from_neighbor,
      bias_right: step.bias_right,
      candidate_crossings: step.candidate_crossings,
      barycenters_by_rank: step.barycenters_by_rank,
      rank_nodes: step.rank_nodes,
    })
  }
  { rank_nodes_trace, sweep_step_trace }
}

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
  prefer_dagre_network_simplex : Bool,
) -> LegacyLaneState {
  let state_lane_by_node_id : Map[String, Int] = {}
  let state_label_y_offset_by_node_id : Map[String, Int] = {}
  let flow_rank_by_node_id : Map[String, Int] = {}
  let flow_lane_by_node_id : Map[String, Int] = {}
  let flow_label_y_offset_by_rank : Map[Int, Int] = {}
  let mut refined_horizontal_non_state_flow = false
  let mut refined_horizontal_non_state_labeled_cycle_flow = false
  let mut flow_max_rank = 0
  let dagre_parity_rank_nodes : Array[Array[String]] = []
  if !state_graph || horizontal {
    let cycle_aware_layout = state_graph ||
      (!class_or_er_graph && graph_has_cycle(nodes_in_order, graph.edges))
    let adaptive_compact_fanin = !state_graph &&
      !class_or_er_graph &&
      !prefer_dagre_network_simplex &&
      horizontal &&
      cycle_aware_layout &&
      graph.subgraphs.length() > 0 &&
      graph.edges.length() >= 50
    let rank_compact_fanin = compact_fanin || adaptive_compact_fanin
    let promote_backward_dotted_edges = horizontal &&
      !state_graph &&
      !class_or_er_graph &&
      !cycle_aware_layout &&
      graph_has_definition_backward_dotted_edge(nodes_in_order, graph.edges)
    let preserve_dummy_lane_channels = prefer_dagre_network_simplex ||
      (
        !state_graph &&
        !class_or_er_graph &&
        (graph.subgraphs.length() > 0 || graph.edges.length() >= 30)
      )
    let enable_cycle_rank_compaction = !state_graph &&
      !class_or_er_graph &&
      horizontal &&
      !rank_compact_fanin &&
      cycle_aware_layout &&
      graph.subgraphs.length() == 0 &&
      graph.edges.length() >= 30
    let prefer_definition_back_edges = !prefer_dagre_network_simplex &&
      !state_graph &&
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
    let default_use_greedy_feedback_arc_set = select_default_use_greedy_feedback_arc_set(
      graph, cycle_aware_layout, horizontal, state_graph, class_or_er_graph, prefer_dagre_network_simplex,
    )
    let allow_feedback_strategy_selection = should_allow_feedback_strategy_selection(
      graph, cycle_aware_layout, horizontal, state_graph, class_or_er_graph, prefer_dagre_network_simplex,
    )
    let prefer_dagre_order_parity = prefer_dagre_network_simplex
    let preserve_fanout_order_ties = !class_or_er_graph
    let selected_rank_candidate = select_primary_non_state_flow_rank_candidate(
      nodes_in_order,
      graph.edges,
      graph.subgraphs,
      horizontal,
      rank_compact_fanin,
      cycle_aware_layout,
      promote_backward_dotted_edges,
      prefer_definition_back_edges,
      preserve_dummy_lane_channels,
      base_enable_feedback_back_edge_ordering,
      preserve_fanout_order_ties,
      default_use_greedy_feedback_arc_set,
      allow_feedback_strategy_selection,
      prefer_dagre_network_simplex,
    )
    let use_greedy_feedback_arc_set = selected_rank_candidate.use_greedy_feedback_arc_set
    let enable_feedback_back_edge_ordering = base_enable_feedback_back_edge_ordering &&
      !use_greedy_feedback_arc_set
    let precomputed_lane_by_id : Map[String, Int] = {}
    let mut has_precomputed_lane_by_id = false
    let mut selected_rank_by_id = selected_rank_candidate.rank_by_id
    let mut selected_max_rank = selected_rank_candidate.max_rank
    if enable_cycle_rank_compaction {
      let compacted_rank_candidate = collect_non_state_flow_rank_candidate(
        nodes_in_order,
        graph.edges,
        graph.subgraphs,
        horizontal,
        rank_compact_fanin,
        cycle_aware_layout,
        promote_backward_dotted_edges,
        prefer_definition_back_edges,
        true,
        preserve_dummy_lane_channels,
        base_enable_feedback_back_edge_ordering,
        preserve_fanout_order_ties,
        use_greedy_feedback_arc_set,
        prefer_dagre_network_simplex,
        prefer_dagre_order_parity,
      )
      if compacted_rank_candidate.lane_crossings <
        selected_rank_candidate.lane_crossings ||
        (
          compacted_rank_candidate.lane_crossings ==
          selected_rank_candidate.lane_crossings &&
          compacted_rank_candidate.max_rank < selected_rank_candidate.max_rank
        ) {
        selected_rank_by_id = compacted_rank_candidate.rank_by_id
        selected_max_rank = compacted_rank_candidate.max_rank
        for node_id, lane in compacted_rank_candidate.lane_by_id {
          precomputed_lane_by_id[node_id] = lane
        }
      } else {
        for node_id, lane in selected_rank_candidate.lane_by_id {
          precomputed_lane_by_id[node_id] = lane
        }
      }
      has_precomputed_lane_by_id = true
    }
    if !has_precomputed_lane_by_id && !compact_fanin {
      for node_id, lane in selected_rank_candidate.lane_by_id {
        precomputed_lane_by_id[node_id] = lane
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
        preserve_fanout_order_ties,
        prefer_dagre_order_parity,
        graph.subgraphs.length() > 0,
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
    let use_horizontal_lane_refinement = if prefer_dagre_network_simplex {
      false
    } else if state_graph {
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
    if prefer_dagre_network_simplex && horizontal {
      // Dagre assigns distinct order slots per rank. Keep this invariant even
      // when optional refinement perturbs lane values.
      enforce_unique_lanes_per_rank(
        nodes_in_order, flow_rank_by_node_id, flow_lane_by_node_id,
      )
      let parity_rank_nodes_trace : Array[Array[Array[String]]] = []
      let _ = collect_non_state_flow_lanes_internal(
        nodes_in_order,
        flow_rank_by_node_id,
        flow_max_rank,
        graph.edges,
        preserve_dummy_lane_channels,
        enable_feedback_back_edge_ordering,
        preserve_fanout_order_ties,
        prefer_dagre_order_parity,
        graph.subgraphs.length() > 0,
        Some(parity_rank_nodes_trace),
        None,
      )
      if parity_rank_nodes_trace.length() > 0 {
        let final_rank_nodes = parity_rank_nodes_trace[parity_rank_nodes_trace.length() -
          1]
        for rank_nodes in final_rank_nodes {
          let copied_rank_nodes : Array[String] = []
          for node_id in rank_nodes {
            copied_rank_nodes.push(node_id)
          }
          dagre_parity_rank_nodes.push(copied_rank_nodes)
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

  {
    state_lane_by_node_id,
    state_label_y_offset_by_node_id,
    flow_rank_by_node_id,
    flow_lane_by_node_id,
    flow_label_y_offset_by_rank,
    refined_horizontal_non_state_flow,
    refined_horizontal_non_state_labeled_cycle_flow,
    flow_max_rank,
    dagre_parity_rank_nodes,
  }
}
