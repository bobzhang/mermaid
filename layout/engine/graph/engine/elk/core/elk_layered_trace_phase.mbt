///|
/// Rank-phase trace payload for ELK layered layout.
priv struct ElkLayeredRankTrace {
  rank_input_node_ids_in_order : Array[String]
  rank_input_resolved_edges : Array[(String, String)]
  rank_feedback_oriented_edges : Array[(String, String)]
  rank_feedback_oriented_edges_model_order : Array[(String, String)]
  rank_seed_strategy : String
  rank_seed_rank_by_node_id : Map[String, Int]
  rank_seed_order_index_by_node_id : Map[String, Int]
  rank_seed_oriented_edges : Array[(String, String)]
  rank_seed_layers : Array[Array[String]]
  rank_seed_virtual_node_ids : Array[String]
  rank_seed_virtual_edges : Array[(String, String)]
  rank_seed_virtual_ports : Array[(String, Int, String)]
  rank_seed_virtual_layers : Array[Array[String]]
  rank_order_strategy : String
  rank_order_sweep_kernel : String
  rank_order_sweep_pass_count : Int
  rank_order_trial_count : Int
  rank_order_trial_continuation_policy : String
  rank_order_local_refinement_kernels : String
  rank_order_trial_model_order_inversion_influence : Double
  rank_order_selected_trial_index : Int
  rank_order_optimized_seed_selected_trial_index : Int
  rank_order_optimized_reversed_seed_selected_trial_index : Int
  rank_order_virtual_candidate_selected_trial_index : Int
  rank_order_optimized_seed_trial_summaries : Array[
    ElkLayeredCrossingTrialSummary,
  ]
  rank_order_optimized_reversed_seed_trial_summaries : Array[
    ElkLayeredCrossingTrialSummary,
  ]
  rank_order_virtual_candidate_trial_summaries : Array[
    ElkLayeredCrossingTrialSummary,
  ]
  rank_order_optimized_seed_post_sweep_layers : Array[Array[String]]
  rank_order_optimized_seed_post_sweep_crossings : Int
  rank_order_optimized_seed_layers : Array[Array[String]]
  rank_order_optimized_seed_crossings : Int
  rank_order_optimized_reversed_seed_post_sweep_layers : Array[Array[String]]
  rank_order_optimized_reversed_seed_post_sweep_crossings : Int
  rank_order_optimized_reversed_seed_layers : Array[Array[String]]
  rank_order_optimized_reversed_seed_crossings : Int
  rank_order_virtual_candidate_post_sweep_layers : Array[Array[String]]
  rank_order_virtual_candidate_post_sweep_crossings : Int
  rank_order_virtual_candidate_layers : Array[Array[String]]
  rank_order_virtual_candidate_crossings : Int
  rank_order_selected_virtual_node_ids : Array[String]
  rank_order_selected_virtual_edges : Array[(String, String)]
  rank_order_selected_virtual_ports : Array[(String, Int, String)]
  rank_order_selected_virtual_layers : Array[Array[String]]
  rank_order_selected_layers : Array[Array[String]]
  rank_order_selected_crossings : Int
  rank_order_selected_source : String
  rank_layers : Array[Array[String]]
  placement_major_strategy : String
  placement_major_coord_by_node_id : Map[String, Int]
  placement_minor_coord_by_node_id : Map[String, Int]
}

///|
/// Sweep-kernel selector used by ELK layered trace/debug collection.
pub(all) enum ElkLayeredRankTraceSweepKernel {
  Default
  NeighborMeanBidirectional
  NeighborMeanEdgeSlotBidirectional
}

///|
/// Trial continuation policy selector used by ELK layered trace/debug collection.
pub(all) enum ElkLayeredRankTraceTrialContinuationPolicy {
  DefaultTrialContinuationPolicy
  WhilePassChanges
  WhileObjectiveImproves
}

///|
/// Local-refinement profile selector used by ELK layered trace/debug collection.
pub(all) enum ElkLayeredRankTraceLocalRefinementProfile {
  DefaultLocalRefinementProfile
  NoLocalRefinement
  AdjacentSwapOnly
  RankPermutationOnly
  AdjacentSwapThenRankPermutation
}

///|
fn crossing_trial_continuation_policy_for_rank_trace(
  trace_trial_continuation_policy : ElkLayeredRankTraceTrialContinuationPolicy,
  fallback : ElkLayeredCrossingTrialContinuationPolicy,
) -> ElkLayeredCrossingTrialContinuationPolicy {
  match trace_trial_continuation_policy {
    DefaultTrialContinuationPolicy => fallback
    WhilePassChanges => ContinueWhilePassChanges
    WhileObjectiveImproves => ContinueWhileObjectiveImproves
  }
}

///|
fn crossing_local_refinement_profile_for_rank_trace(
  trace_profile : ElkLayeredRankTraceLocalRefinementProfile,
) -> ElkLayeredCrossingLocalRefinementProfile {
  match trace_profile {
    DefaultLocalRefinementProfile => DefaultLocalRefinementProfile
    NoLocalRefinement => NoLocalRefinement
    AdjacentSwapOnly => AdjacentSwapOnly
    RankPermutationOnly => RankPermutationOnly
    AdjacentSwapThenRankPermutation => AdjacentSwapThenRankPermutation
  }
}

///|
fn crossing_sweep_kernel_for_rank_trace(
  trace_sweep_kernel : ElkLayeredRankTraceSweepKernel,
) -> ElkLayeredCrossingSweepKernel {
  match trace_sweep_kernel {
    Default => default_crossing_sweep_kernel()
    NeighborMeanBidirectional => NeighborMeanBidirectional
    NeighborMeanEdgeSlotBidirectional => NeighborMeanEdgeSlotBidirectional
  }
}

///|
fn crossing_execution_plan_for_rank_trace_kernel(
  trace_sweep_kernel : ElkLayeredRankTraceSweepKernel,
) -> ElkLayeredCrossingExecutionPlan {
  let default_plan = default_crossing_execution_plan(
    LayerSweepWithLocalRefinement,
  )
  if trace_sweep_kernel is Default {
    default_plan
  } else {
    {
      ..default_plan,
      sweep_kernel: crossing_sweep_kernel_for_rank_trace(trace_sweep_kernel),
    }
  }
}

///|
fn crossing_execution_plan_with_trace_overrides(
  base_plan : ElkLayeredCrossingExecutionPlan,
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
  trial_model_order_inversion_influence_override : Double?,
  trial_continuation_policy_override : ElkLayeredRankTraceTrialContinuationPolicy?,
  local_refinement_profile_override : ElkLayeredRankTraceLocalRefinementProfile?,
) -> ElkLayeredCrossingExecutionPlan {
  let config = base_plan.config
  let configured_trial_count = match trial_count_override {
    Some(value) => if value > 0 { value } else { config.trial_count }
    None => config.trial_count
  }
  let configured_sweep_pass_count = match sweep_pass_count_override {
    Some(value) => if value > 0 { value } else { config.sweep_pass_count }
    None => config.sweep_pass_count
  }
  let configured_trial_model_order_inversion_influence = match
    trial_model_order_inversion_influence_override {
    Some(value) =>
      if value >= 0.0 {
        value
      } else {
        config.trial_model_order_inversion_influence
      }
    None => config.trial_model_order_inversion_influence
  }
  let configured_trial_continuation_policy = match
    trial_continuation_policy_override {
    Some(trace_policy) =>
      crossing_trial_continuation_policy_for_rank_trace(
        trace_policy,
        config.trial_continuation_policy,
      )
    None => config.trial_continuation_policy
  }
  let configured_local_refinement_kernels = match
    local_refinement_profile_override {
    Some(trace_profile) =>
      crossing_local_refinement_kernels_for_profile(
        crossing_local_refinement_profile_for_rank_trace(trace_profile),
      )
    None => base_plan.local_refinement_kernels
  }
  {
    ..base_plan,
    local_refinement_kernels: configured_local_refinement_kernels,
    config: {
      ..config,
      trial_count: configured_trial_count,
      sweep_pass_count: configured_sweep_pass_count,
      trial_continuation_policy: configured_trial_continuation_policy,
      trial_model_order_inversion_influence: configured_trial_model_order_inversion_influence,
    },
  }
}

///|
fn crossing_execution_plan_for_rank_trace_kernel_with_overrides(
  trace_sweep_kernel : ElkLayeredRankTraceSweepKernel,
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
  trial_model_order_inversion_influence_override : Double?,
  trial_continuation_policy_override : ElkLayeredRankTraceTrialContinuationPolicy?,
  local_refinement_profile_override : ElkLayeredRankTraceLocalRefinementProfile?,
) -> ElkLayeredCrossingExecutionPlan {
  crossing_execution_plan_with_trace_overrides(
    crossing_execution_plan_for_rank_trace_kernel(trace_sweep_kernel),
    trial_count_override,
    sweep_pass_count_override,
    trial_model_order_inversion_influence_override,
    trial_continuation_policy_override,
    local_refinement_profile_override,
  )
}

///|
fn has_rank_trace_crossing_overrides(
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
  trial_model_order_inversion_influence_override : Double?,
  trial_continuation_policy_override : ElkLayeredRankTraceTrialContinuationPolicy?,
  local_refinement_profile_override : ElkLayeredRankTraceLocalRefinementProfile?,
) -> Bool {
  trial_count_override is Some(_) ||
  sweep_pass_count_override is Some(_) ||
  trial_model_order_inversion_influence_override is Some(_) ||
  trial_continuation_policy_override is Some(_) ||
  local_refinement_profile_override is Some(_)
}

///|
fn collect_elk_layered_rank_trace_for_sweep_kernel(
  request : GraphLayoutBackendRequest,
  trace_sweep_kernel : ElkLayeredRankTraceSweepKernel,
) -> ElkLayeredRankTrace? {
  collect_elk_layered_rank_trace_for_sweep_kernel_with_overrides(
    request,
    trace_sweep_kernel,
    None,
    None,
    None,
    None,
    None,
  )
}

///|
fn collect_elk_layered_rank_trace_for_sweep_kernel_with_overrides(
  request : GraphLayoutBackendRequest,
  trace_sweep_kernel : ElkLayeredRankTraceSweepKernel,
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
  trial_model_order_inversion_influence_override : Double?,
  trial_continuation_policy_override : ElkLayeredRankTraceTrialContinuationPolicy?,
  local_refinement_profile_override : ElkLayeredRankTraceLocalRefinementProfile?,
) -> ElkLayeredRankTrace? {
  let has_overrides = has_rank_trace_crossing_overrides(
    trial_count_override, sweep_pass_count_override, trial_model_order_inversion_influence_override,
    trial_continuation_policy_override, local_refinement_profile_override,
  )
  if trace_sweep_kernel is Default && !has_overrides {
    collect_elk_layered_rank_trace(request)
  } else {
    collect_elk_layered_rank_trace_with_crossing_execution_plan(
      request,
      crossing_execution_plan_for_rank_trace_kernel_with_overrides(
        trace_sweep_kernel, trial_count_override, sweep_pass_count_override, trial_model_order_inversion_influence_override,
        trial_continuation_policy_override, local_refinement_profile_override,
      ),
    )
  }
}

///|
fn trace_rank_layer_mismatch_count(
  left_layers : Array[Array[String]],
  right_layers : Array[Array[String]],
) -> Int {
  let rank_limit = if left_layers.length() < right_layers.length() {
    left_layers.length()
  } else {
    right_layers.length()
  }
  let mut mismatch_count = 0
  for rank in 0..<rank_limit {
    if left_layers[rank] != right_layers[rank] {
      mismatch_count += 1
    }
  }
  mismatch_count +
  (left_layers.length() - rank_limit) +
  (right_layers.length() - rank_limit)
}

///|
fn rank_layers_from_rank_map(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
) -> Array[Array[String]] {
  let layers : Array[Array[String]] = []
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) => layers.push(node_ids.copy())
      None => layers.push([])
    }
  }
  layers
}

///|
fn oriented_edges_from_successors(
  successors_by_node_id : Map[String, Array[String]],
) -> Array[(String, String)] {
  let oriented_edges : Array[(String, String)] = []
  for source_id, successors in successors_by_node_id {
    for target_id in successors {
      oriented_edges.push((source_id, target_id))
    }
  }
  oriented_edges
}

///|
fn ordered_ports_from_rank_layers(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  successors_by_node_id : Map[String, Array[String]],
) -> Array[(String, Int, String)] {
  let ordered_ports : Array[(String, Int, String)] = []
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for source_id in node_ids {
          match successors_by_node_id.get(source_id) {
            Some(target_ids) =>
              for slot, target_id in target_ids {
                ordered_ports.push((source_id, slot, target_id))
              }
            None => ()
          }
        }
      None => ()
    }
  }
  ordered_ports
}

///|
fn rank_seed_strategy_tag(
  rank_seed_strategy : ElkLayeredRankSeedStrategy,
) -> String {
  match rank_seed_strategy {
    LegacyLaneSeed => "legacy-lane-seed"
    NativeFeedback => "native-feedback"
  }
}

///|
fn rank_order_strategy_tag(
  rank_order_strategy : ElkLayeredRankOrderStrategy,
) -> String {
  match rank_order_strategy {
    SeedOrderOnly => "seed-order-only"
    OptimizedSeedOrder => "optimized-seed-order"
    OptimizedSeedWithVirtualCandidate => "optimized-seed-with-virtual-candidate"
  }
}

///|
fn major_placement_strategy_tag(
  major_placement_strategy : ElkLayeredMajorPlacementStrategy,
) -> String {
  match major_placement_strategy {
    RankCentered => "rank-centered"
    RelaxedCompaction => "relaxed-compaction"
  }
}

///|
fn collect_sorted_virtual_node_ids(
  virtual_by_node_id : Map[String, Bool],
) -> Array[String] {
  let virtual_node_ids : Array[String] = []
  for node_id, is_virtual in virtual_by_node_id {
    if is_virtual {
      virtual_node_ids.push(node_id)
    }
  }
  virtual_node_ids.sort()
  virtual_node_ids
}

///|
fn placement_axis_coord_maps(
  positioned_nodes : Array[PositionedNode],
  horizontal : Bool,
) -> (Map[String, Int], Map[String, Int]) {
  let major_coord_by_node_id : Map[String, Int] = {}
  let minor_coord_by_node_id : Map[String, Int] = {}
  for node in positioned_nodes {
    if horizontal {
      major_coord_by_node_id[node.id] = node.x
      minor_coord_by_node_id[node.id] = node.y
    } else {
      major_coord_by_node_id[node.id] = node.y
      minor_coord_by_node_id[node.id] = node.x
    }
  }
  (major_coord_by_node_id, minor_coord_by_node_id)
}

///|
/// Collects ELK layered rank-phase trace for flowchart graphs.
fn collect_elk_layered_rank_trace(
  request : GraphLayoutBackendRequest,
) -> ElkLayeredRankTrace? {
  collect_elk_layered_rank_trace_with_crossing_execution_plan(
    request,
    default_crossing_execution_plan(LayerSweepWithLocalRefinement),
  )
}

///|
fn collect_elk_layered_rank_trace_with_crossing_execution_plan(
  request : GraphLayoutBackendRequest,
  crossing_execution_plan : ElkLayeredCrossingExecutionPlan,
) -> ElkLayeredRankTrace? {
  if !elk_graph_supports_layered_pipeline(request.graph) {
    return None
  }
  let use_legacy_seed_placement = select_elk_layered_rank_seed_strategy(
      request.graph,
    )
    is LegacyLaneSeed
  let tuned_request : GraphLayoutBackendRequest = {
    graph: request.graph,
    options: if use_legacy_seed_placement {
      request.options
    } else {
      derive_elk_render_options(request.graph, request.options)
    },
    use_subgraph_redirects: request.use_subgraph_redirects,
    compact_fanin: request.compact_fanin,
  }
  let setup_state = run_elk_layered_setup_phase(tuned_request)
  let rank_input_resolved_edges = collect_visible_resolved_edges(
    setup_state.graph,
    setup_state.use_subgraph_redirects,
    setup_state.subgraph_entry_by_id,
    setup_state.subgraph_exit_by_id,
    setup_state.node_ids_in_order,
  )
  let feedback_orientation_state = compute_feedback_order_orientation_state(
    setup_state.node_ids_in_order,
    rank_input_resolved_edges,
    setup_state.base_order_index_by_node_id,
    SeededRandom,
  )
  let model_order_feedback_orientation_state = compute_feedback_order_orientation_state(
    setup_state.node_ids_in_order,
    rank_input_resolved_edges,
    setup_state.base_order_index_by_node_id,
    ModelOrderFirst,
  )
  let rank_phase_state = run_elk_layered_rank_phase_with_crossing_execution_plan(
    setup_state, crossing_execution_plan,
  )
  let rank_seed_state = rank_phase_state.rank_seed_state
  let rank_order_debug_state = rank_phase_state.rank_order_debug_state
  let node_size_state = build_elk_layered_node_size_state(
    setup_state.nodes_in_order,
  )
  let max_rank_size = compute_max_rank_size(
    rank_phase_state.rank_node_ids_by_rank,
    rank_seed_state.max_rank,
  )
  let spacing_state = run_elk_layered_spacing_phase(
    setup_state.options,
    setup_state.horizontal,
    max_rank_size,
    node_size_state,
  )
  let placement_state = run_elk_layered_node_placement_phase(
    setup_state, rank_phase_state, node_size_state, spacing_state,
  )
  let mut has_labeled_edges = false
  for edge in setup_state.graph.edges {
    if edge.label is Some(_) {
      has_labeled_edges = true
      break
    }
  }
  let selected_major_strategy = select_elk_layered_major_placement_strategy(
    rank_phase_state.rank_seed_strategy,
  )
  let placement_major_strategy = if selected_major_strategy is RelaxedCompaction &&
    !use_relaxed_major_compaction(
      rank_seed_state.max_rank,
      rank_seed_state.rank_by_node_id,
      rank_seed_state.successors_by_node_id,
      has_labeled_edges,
    ) {
    RankCentered
  } else {
    selected_major_strategy
  }
  let (placement_major_coord_by_node_id, placement_minor_coord_by_node_id) = placement_axis_coord_maps(
    placement_state.positioned_nodes,
    setup_state.horizontal,
  )
  let selected_virtual_ordering_state = build_virtual_ordering_state(
    rank_order_debug_state.selected_rank_node_ids_by_rank,
    rank_seed_state.rank_by_node_id,
    rank_seed_state.max_rank,
    rank_seed_state.order_index_by_node_id,
    rank_seed_state.successors_by_node_id,
  )
  let rank_seed_layers_by_rank = build_rank_node_ids_by_lane(
    setup_state.nodes_in_order,
    rank_seed_state.rank_by_node_id,
    rank_seed_state.lane_by_node_id,
    setup_state.base_order_index_by_node_id,
    rank_seed_state.max_rank,
  )
  let seed_virtual_ordering_state = build_virtual_ordering_state(
    rank_seed_layers_by_rank,
    rank_seed_state.rank_by_node_id,
    rank_seed_state.max_rank,
    rank_seed_state.order_index_by_node_id,
    rank_seed_state.successors_by_node_id,
  )
  Some({
    rank_input_node_ids_in_order: setup_state.node_ids_in_order.copy(),
    rank_input_resolved_edges,
    rank_feedback_oriented_edges: feedback_orientation_state.oriented_edges.copy(),
    rank_feedback_oriented_edges_model_order: model_order_feedback_orientation_state.oriented_edges.copy(),
    rank_seed_strategy: rank_seed_strategy_tag(
      rank_phase_state.rank_seed_strategy,
    ),
    rank_seed_rank_by_node_id: rank_seed_state.rank_by_node_id,
    rank_seed_order_index_by_node_id: rank_seed_state.order_index_by_node_id,
    rank_seed_oriented_edges: oriented_edges_from_successors(
      rank_seed_state.successors_by_node_id,
    ),
    rank_seed_layers: rank_layers_from_rank_map(
      rank_seed_layers_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_seed_virtual_node_ids: collect_sorted_virtual_node_ids(
      seed_virtual_ordering_state.virtual_by_node_id,
    ),
    rank_seed_virtual_edges: oriented_edges_from_successors(
      seed_virtual_ordering_state.successors_by_node_id,
    ),
    rank_seed_virtual_ports: ordered_ports_from_rank_layers(
      seed_virtual_ordering_state.rank_node_ids_by_rank,
      rank_seed_state.max_rank,
      seed_virtual_ordering_state.successors_by_node_id,
    ),
    rank_seed_virtual_layers: rank_layers_from_rank_map(
      seed_virtual_ordering_state.rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_order_strategy: rank_order_strategy_tag(
      rank_phase_state.rank_order_strategy,
    ),
    rank_order_sweep_kernel: crossing_sweep_kernel_tag(
      rank_order_debug_state.crossing_sweep_kernel,
    ),
    rank_order_sweep_pass_count: rank_order_debug_state.crossing_sweep_pass_count,
    rank_order_trial_count: rank_order_debug_state.crossing_trial_count,
    rank_order_trial_continuation_policy: crossing_trial_continuation_policy_tag(
      rank_order_debug_state.crossing_trial_continuation_policy,
    ),
    rank_order_local_refinement_kernels: crossing_local_refinement_kernels_tag(
      rank_order_debug_state.crossing_local_refinement_kernels,
    ),
    rank_order_trial_model_order_inversion_influence: rank_order_debug_state.crossing_trial_model_order_inversion_influence,
    rank_order_selected_trial_index: rank_order_debug_state.selected_trial_index,
    rank_order_optimized_seed_selected_trial_index: rank_order_debug_state.optimized_seed_selected_trial_index,
    rank_order_optimized_reversed_seed_selected_trial_index: rank_order_debug_state.optimized_reversed_seed_selected_trial_index,
    rank_order_virtual_candidate_selected_trial_index: rank_order_debug_state.virtual_candidate_selected_trial_index,
    rank_order_optimized_seed_trial_summaries: rank_order_debug_state.optimized_seed_trial_summaries,
    rank_order_optimized_reversed_seed_trial_summaries: rank_order_debug_state.optimized_reversed_seed_trial_summaries,
    rank_order_virtual_candidate_trial_summaries: rank_order_debug_state.virtual_candidate_trial_summaries,
    rank_order_optimized_seed_post_sweep_layers: rank_layers_from_rank_map(
      rank_order_debug_state.optimized_seed_post_sweep_rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_order_optimized_seed_post_sweep_crossings: rank_order_debug_state.optimized_seed_post_sweep_crossing_score,
    rank_order_optimized_seed_layers: rank_layers_from_rank_map(
      rank_order_debug_state.optimized_seed_rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_order_optimized_seed_crossings: rank_order_debug_state.optimized_seed_crossing_score,
    rank_order_optimized_reversed_seed_post_sweep_layers: rank_layers_from_rank_map(
      rank_order_debug_state.optimized_reversed_seed_post_sweep_rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_order_optimized_reversed_seed_post_sweep_crossings: rank_order_debug_state.optimized_reversed_seed_post_sweep_crossing_score,
    rank_order_optimized_reversed_seed_layers: rank_layers_from_rank_map(
      rank_order_debug_state.optimized_reversed_seed_rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_order_optimized_reversed_seed_crossings: rank_order_debug_state.optimized_reversed_seed_crossing_score,
    rank_order_virtual_candidate_post_sweep_layers: rank_layers_from_rank_map(
      rank_order_debug_state.virtual_candidate_post_sweep_rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_order_virtual_candidate_post_sweep_crossings: rank_order_debug_state.virtual_candidate_post_sweep_crossing_score,
    rank_order_virtual_candidate_layers: rank_layers_from_rank_map(
      rank_order_debug_state.virtual_candidate_rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_order_virtual_candidate_crossings: rank_order_debug_state.virtual_candidate_crossing_score,
    rank_order_selected_virtual_node_ids: collect_sorted_virtual_node_ids(
      selected_virtual_ordering_state.virtual_by_node_id,
    ),
    rank_order_selected_virtual_edges: oriented_edges_from_successors(
      selected_virtual_ordering_state.successors_by_node_id,
    ),
    rank_order_selected_virtual_ports: ordered_ports_from_rank_layers(
      selected_virtual_ordering_state.rank_node_ids_by_rank,
      rank_seed_state.max_rank,
      selected_virtual_ordering_state.successors_by_node_id,
    ),
    rank_order_selected_virtual_layers: rank_layers_from_rank_map(
      selected_virtual_ordering_state.rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_order_selected_layers: rank_layers_from_rank_map(
      rank_order_debug_state.selected_rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    rank_order_selected_crossings: rank_order_debug_state.selected_crossing_score,
    rank_order_selected_source: rank_order_debug_state.selected_source,
    rank_layers: rank_layers_from_rank_map(
      rank_phase_state.rank_node_ids_by_rank,
      rank_seed_state.max_rank,
    ),
    placement_major_strategy: major_placement_strategy_tag(
      placement_major_strategy,
    ),
    placement_major_coord_by_node_id,
    placement_minor_coord_by_node_id,
  })
}

///|
fn sorted_string_keys(entries : Map[String, Int]) -> Array[String] {
  let keys : Array[String] = []
  for key, _ in entries {
    keys.push(key)
  }
  keys.sort()
  keys
}

///|
fn sorted_oriented_edges(
  edges : Array[(String, String)],
) -> Array[(String, String)] {
  let sorted = edges.copy()
  sorted.sort_by((left, right) => {
    let (left_source, left_target) = left
    let (right_source, right_target) = right
    let source_cmp = left_source.compare(right_source)
    if source_cmp != 0 {
      source_cmp
    } else {
      left_target.compare(right_target)
    }
  })
  sorted
}

///|
fn append_rank_layer_lines(
  lines : Array[String],
  prefix : String,
  layers : Array[Array[String]],
) -> Unit {
  for rank, node_ids in layers {
    let joined_node_ids = node_ids.join(",")
    lines.push("\{prefix}\t\{rank}\t\{joined_node_ids}")
  }
}

///|
fn append_sorted_map_lines(
  lines : Array[String],
  prefix : String,
  entries : Map[String, Int],
) -> Unit {
  for node_id in sorted_string_keys(entries) {
    match entries.get(node_id) {
      Some(value) => lines.push("\{prefix}\t\{node_id}\t\{value}")
      None => ()
    }
  }
}

///|
fn append_trial_summary_lines(
  lines : Array[String],
  source : String,
  trial_summaries : Array[ElkLayeredCrossingTrialSummary],
) -> Unit {
  for summary in trial_summaries {
    lines.push(
      "ORDER_TRIAL\t\{source}\t\{summary.trial_index}\t\{summary.seed_kind}\t\{summary.initial_sweep_direction}\t\{summary.post_sweep_objective.layered_crossings}\t\{summary.post_sweep_objective.global_crossings}\t\{summary.optimized_objective.layered_crossings}\t\{summary.optimized_objective.global_crossings}\t\{summary.model_order_inversion_score}",
    )
    for pass_summary in summary.sweep_pass_summaries {
      let changed = if pass_summary.changed { 1 } else { 0 }
      lines.push(
        "ORDER_TRIAL_PASS\t\{source}\t\{summary.trial_index}\t\{pass_summary.pass_index}\t\{pass_summary.sweep_direction}\t\{changed}\t\{pass_summary.objective.layered_crossings}\t\{pass_summary.objective.global_crossings}",
      )
      let ranks : Array[Int] = []
      for rank, _ in pass_summary.rank_node_ids_by_rank {
        ranks.push(rank)
      }
      ranks.sort()
      for rank in ranks {
        match pass_summary.rank_node_ids_by_rank.get(rank) {
          Some(node_ids) => {
            let joined_node_ids = node_ids.join(",")
            lines.push(
              "ORDER_TRIAL_LAYER\t\{source}\t\{summary.trial_index}\t\{pass_summary.pass_index}\t\{rank}\t\{joined_node_ids}",
            )
          }
          None => ()
        }
      }
    }
  }
}

///|
/// Renders a deterministic line-oriented dump for an ELK layered rank trace.
fn elk_layered_rank_trace_lines(trace : ElkLayeredRankTrace) -> Array[String] {
  let lines : Array[String] = []
  lines.push("SEED\t\{trace.rank_seed_strategy}")
  for i, node_id in trace.rank_input_node_ids_in_order {
    lines.push("INPUT_NODE\t\{i}\t\{node_id}")
  }
  for edge in trace.rank_input_resolved_edges {
    let (source_id, target_id) = edge
    lines.push("INPUT_EDGE\t\{source_id}\t\{target_id}")
  }
  for edge in trace.rank_feedback_oriented_edges {
    let (source_id, target_id) = edge
    lines.push("FEEDBACK_EDGE\t\{source_id}\t\{target_id}")
  }
  for edge in trace.rank_feedback_oriented_edges_model_order {
    let (source_id, target_id) = edge
    lines.push("FEEDBACK_EDGE_MODEL_ORDER\t\{source_id}\t\{target_id}")
  }
  lines.push("ORDER_STRATEGY\t\{trace.rank_order_strategy}")
  lines.push("ORDER_SWEEP_KERNEL\t\{trace.rank_order_sweep_kernel}")
  lines.push("ORDER_SWEEP_PASSES\t\{trace.rank_order_sweep_pass_count}")
  lines.push("ORDER_TRIAL_COUNT\t\{trace.rank_order_trial_count}")
  lines.push(
    "ORDER_TRIAL_CONTINUATION_POLICY\t\{trace.rank_order_trial_continuation_policy}",
  )
  lines.push(
    "ORDER_LOCAL_REFINEMENT_KERNELS\t\{trace.rank_order_local_refinement_kernels}",
  )
  lines.push(
    "ORDER_TRIAL_MODEL_ORDER_INVERSION_INFLUENCE\t\{trace.rank_order_trial_model_order_inversion_influence}",
  )
  lines.push(
    "ORDER_SELECTED_TRIAL_INDEX\t\{trace.rank_order_selected_trial_index}",
  )
  lines.push("ORDER_SELECTED_SOURCE\t\{trace.rank_order_selected_source}")
  lines.push(
    "ORDER_TRIAL_SELECTED\toptimized-seed\t\{trace.rank_order_optimized_seed_selected_trial_index}",
  )
  lines.push(
    "ORDER_TRIAL_SELECTED\toptimized-reversed-seed\t\{trace.rank_order_optimized_reversed_seed_selected_trial_index}",
  )
  lines.push(
    "ORDER_TRIAL_SELECTED\tvirtual-candidate\t\{trace.rank_order_virtual_candidate_selected_trial_index}",
  )
  append_trial_summary_lines(
    lines,
    "optimized-seed",
    trace.rank_order_optimized_seed_trial_summaries,
  )
  append_trial_summary_lines(
    lines,
    "optimized-reversed-seed",
    trace.rank_order_optimized_reversed_seed_trial_summaries,
  )
  append_trial_summary_lines(
    lines,
    "virtual-candidate",
    trace.rank_order_virtual_candidate_trial_summaries,
  )
  lines.push(
    "ORDER_SCORE_SWEEP\toptimized-seed\t\{trace.rank_order_optimized_seed_post_sweep_crossings}",
  )
  lines.push(
    "ORDER_SCORE\toptimized-seed\t\{trace.rank_order_optimized_seed_crossings}",
  )
  lines.push(
    "ORDER_SCORE_SWEEP\toptimized-reversed-seed\t\{trace.rank_order_optimized_reversed_seed_post_sweep_crossings}",
  )
  lines.push(
    "ORDER_SCORE\toptimized-reversed-seed\t\{trace.rank_order_optimized_reversed_seed_crossings}",
  )
  lines.push(
    "ORDER_SCORE_SWEEP\tvirtual-candidate\t\{trace.rank_order_virtual_candidate_post_sweep_crossings}",
  )
  lines.push(
    "ORDER_SCORE\tvirtual-candidate\t\{trace.rank_order_virtual_candidate_crossings}",
  )
  lines.push("ORDER_SCORE\tselected\t\{trace.rank_order_selected_crossings}")
  for node_id in trace.rank_seed_virtual_node_ids {
    lines.push("SEED_VIRTUAL_NODE\t\{node_id}")
  }
  for edge in sorted_oriented_edges(trace.rank_seed_virtual_edges) {
    let (source_id, target_id) = edge
    lines.push("SEED_VIRTUAL_EDGE\t\{source_id}\t\{target_id}")
  }
  for port in trace.rank_seed_virtual_ports {
    let (source_id, slot, target_id) = port
    lines.push("SEED_VIRTUAL_PORT\t\{source_id}\t\{slot}\t\{target_id}")
  }
  for node_id in trace.rank_order_selected_virtual_node_ids {
    lines.push("VIRTUAL_NODE\t\{node_id}")
  }
  for edge in sorted_oriented_edges(trace.rank_order_selected_virtual_edges) {
    let (source_id, target_id) = edge
    lines.push("VIRTUAL_EDGE\t\{source_id}\t\{target_id}")
  }
  for port in trace.rank_order_selected_virtual_ports {
    let (source_id, slot, target_id) = port
    lines.push("VIRTUAL_PORT\t\{source_id}\t\{slot}\t\{target_id}")
  }
  append_sorted_map_lines(lines, "SEED_RANK", trace.rank_seed_rank_by_node_id)
  append_sorted_map_lines(
    lines,
    "SEED_ORDER",
    trace.rank_seed_order_index_by_node_id,
  )
  for edge in sorted_oriented_edges(trace.rank_seed_oriented_edges) {
    let (source_id, target_id) = edge
    lines.push("SEED_EDGE\t\{source_id}\t\{target_id}")
  }
  append_rank_layer_lines(lines, "SEED_LAYER", trace.rank_seed_layers)
  append_rank_layer_lines(
    lines,
    "SEED_LAYER_VIRTUAL",
    trace.rank_seed_virtual_layers,
  )
  append_rank_layer_lines(
    lines,
    "ORDER_LAYER_OPTIMIZED_SEED_POST_SWEEP",
    trace.rank_order_optimized_seed_post_sweep_layers,
  )
  append_rank_layer_lines(
    lines,
    "ORDER_LAYER_OPTIMIZED_SEED",
    trace.rank_order_optimized_seed_layers,
  )
  append_rank_layer_lines(
    lines,
    "ORDER_LAYER_OPTIMIZED_REVERSED_SEED_POST_SWEEP",
    trace.rank_order_optimized_reversed_seed_post_sweep_layers,
  )
  append_rank_layer_lines(
    lines,
    "ORDER_LAYER_OPTIMIZED_REVERSED_SEED",
    trace.rank_order_optimized_reversed_seed_layers,
  )
  append_rank_layer_lines(
    lines,
    "ORDER_LAYER_VIRTUAL_CANDIDATE_POST_SWEEP",
    trace.rank_order_virtual_candidate_post_sweep_layers,
  )
  append_rank_layer_lines(
    lines,
    "ORDER_LAYER_VIRTUAL_CANDIDATE",
    trace.rank_order_virtual_candidate_layers,
  )
  append_rank_layer_lines(
    lines,
    "ORDER_LAYER_SELECTED_VIRTUAL",
    trace.rank_order_selected_virtual_layers,
  )
  append_rank_layer_lines(
    lines,
    "ORDER_LAYER_SELECTED",
    trace.rank_order_selected_layers,
  )
  append_rank_layer_lines(lines, "RANK_LAYER", trace.rank_layers)
  lines.push("PLACEMENT_MAJOR_STRATEGY\t\{trace.placement_major_strategy}")
  append_sorted_map_lines(
    lines,
    "PLACEMENT_MAJOR",
    trace.placement_major_coord_by_node_id,
  )
  append_sorted_map_lines(
    lines,
    "PLACEMENT_MINOR",
    trace.placement_minor_coord_by_node_id,
  )
  lines
}

///|
/// Collects and formats ELK layered rank-phase trace lines for CLI/debug usage.
pub fn collect_elk_layered_rank_trace_lines(
  request : GraphLayoutBackendRequest,
) -> Array[String]? {
  collect_elk_layered_rank_trace_lines_with_sweep_kernel(request, Default)
}

///|
/// Collects and formats ELK layered rank-phase trace lines with explicit crossing sweep kernel.
pub fn collect_elk_layered_rank_trace_lines_with_sweep_kernel(
  request : GraphLayoutBackendRequest,
  trace_sweep_kernel : ElkLayeredRankTraceSweepKernel,
) -> Array[String]? {
  match
    collect_elk_layered_rank_trace_for_sweep_kernel(request, trace_sweep_kernel) {
    Some(trace) => Some(elk_layered_rank_trace_lines(trace))
    None => None
  }
}

///|
/// Collects and formats ELK layered rank-phase trace lines with explicit crossing overrides.
pub fn collect_elk_layered_rank_trace_lines_with_crossing_overrides(
  request : GraphLayoutBackendRequest,
  trace_sweep_kernel : ElkLayeredRankTraceSweepKernel,
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
) -> Array[String]? {
  collect_elk_layered_rank_trace_lines_with_crossing_execution_overrides(
    request,
    trace_sweep_kernel,
    trial_count_override,
    sweep_pass_count_override,
    None,
    None,
    None,
  )
}

///|
/// Collects and formats ELK layered rank-phase trace lines with explicit crossing overrides.
pub fn collect_elk_layered_rank_trace_lines_with_crossing_execution_overrides(
  request : GraphLayoutBackendRequest,
  trace_sweep_kernel : ElkLayeredRankTraceSweepKernel,
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
  trial_model_order_inversion_influence_override : Double?,
  trial_continuation_policy_override : ElkLayeredRankTraceTrialContinuationPolicy?,
  local_refinement_profile_override : ElkLayeredRankTraceLocalRefinementProfile?,
) -> Array[String]? {
  match
    collect_elk_layered_rank_trace_for_sweep_kernel_with_overrides(
      request, trace_sweep_kernel, trial_count_override, sweep_pass_count_override,
      trial_model_order_inversion_influence_override, trial_continuation_policy_override,
      local_refinement_profile_override,
    ) {
    Some(trace) => Some(elk_layered_rank_trace_lines(trace))
    None => None
  }
}

///|
/// Collects a deterministic summary of intermediate rank-phase differences between two sweep kernels.
pub fn collect_elk_layered_rank_trace_kernel_comparison_lines(
  request : GraphLayoutBackendRequest,
  left_kernel : ElkLayeredRankTraceSweepKernel,
  right_kernel : ElkLayeredRankTraceSweepKernel,
) -> Array[String]? {
  collect_elk_layered_rank_trace_kernel_comparison_lines_with_crossing_overrides(
    request,
    left_kernel,
    right_kernel,
    None,
    None,
  )
}

///|
/// Collects deterministic rank-phase differences between two sweep kernels with explicit crossing overrides.
pub fn collect_elk_layered_rank_trace_kernel_comparison_lines_with_crossing_overrides(
  request : GraphLayoutBackendRequest,
  left_kernel : ElkLayeredRankTraceSweepKernel,
  right_kernel : ElkLayeredRankTraceSweepKernel,
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
) -> Array[String]? {
  collect_elk_layered_rank_trace_kernel_comparison_lines_with_crossing_execution_overrides(
    request,
    left_kernel,
    right_kernel,
    trial_count_override,
    sweep_pass_count_override,
    None,
    None,
    None,
  )
}

///|
/// Collects deterministic rank-phase differences between two sweep kernels with explicit crossing overrides.
pub fn collect_elk_layered_rank_trace_kernel_comparison_lines_with_crossing_execution_overrides(
  request : GraphLayoutBackendRequest,
  left_kernel : ElkLayeredRankTraceSweepKernel,
  right_kernel : ElkLayeredRankTraceSweepKernel,
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
  trial_model_order_inversion_influence_override : Double?,
  trial_continuation_policy_override : ElkLayeredRankTraceTrialContinuationPolicy?,
  local_refinement_profile_override : ElkLayeredRankTraceLocalRefinementProfile?,
) -> Array[String]? {
  let left_trace = collect_elk_layered_rank_trace_for_sweep_kernel_with_overrides(
    request, left_kernel, trial_count_override, sweep_pass_count_override, trial_model_order_inversion_influence_override,
    trial_continuation_policy_override, local_refinement_profile_override,
  )
  let right_trace = collect_elk_layered_rank_trace_for_sweep_kernel_with_overrides(
    request, right_kernel, trial_count_override, sweep_pass_count_override, trial_model_order_inversion_influence_override,
    trial_continuation_policy_override, local_refinement_profile_override,
  )
  match (left_trace, right_trace) {
    (Some(left), Some(right)) => {
      let lines : Array[String] = []
      lines.push("KERNEL_LEFT\t\{left.rank_order_sweep_kernel}")
      lines.push("KERNEL_RIGHT\t\{right.rank_order_sweep_kernel}")
      lines.push(
        "ORDER_SELECTED_SOURCE\t\{left.rank_order_selected_source}\t\{right.rank_order_selected_source}",
      )
      lines.push(
        "ORDER_TRIAL_CONTINUATION_POLICY\t\{left.rank_order_trial_continuation_policy}\t\{right.rank_order_trial_continuation_policy}",
      )
      lines.push(
        "ORDER_LOCAL_REFINEMENT_KERNELS\t\{left.rank_order_local_refinement_kernels}\t\{right.rank_order_local_refinement_kernels}",
      )
      lines.push(
        "ORDER_TRIAL_MODEL_ORDER_INVERSION_INFLUENCE\t\{left.rank_order_trial_model_order_inversion_influence}\t\{right.rank_order_trial_model_order_inversion_influence}",
      )
      lines.push(
        "ORDER_SELECTED_TRIAL_INDEX\t\{left.rank_order_selected_trial_index}\t\{right.rank_order_selected_trial_index}",
      )
      lines.push(
        "ORDER_SELECTED_CROSSINGS\t\{left.rank_order_selected_crossings}\t\{right.rank_order_selected_crossings}",
      )
      lines.push(
        "ORDER_SELECTED_LAYER_MISMATCH_COUNT\t\{trace_rank_layer_mismatch_count(left.rank_order_selected_layers, right.rank_order_selected_layers)}",
      )
      lines.push(
        "RANK_LAYER_MISMATCH_COUNT\t\{trace_rank_layer_mismatch_count(left.rank_layers, right.rank_layers)}",
      )
      Some(lines)
    }
    _ => None
  }
}
