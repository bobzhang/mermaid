///|
/// Runs the ELK backend entrypoint.
///
/// The ELK backend applies ELK-specific setup tuning and uses the ELK layered
/// flow pipeline for supported flowcharts; other graph kinds fall back to the
/// shared backend pipeline with ELK routing policy.
pub fn layout_graph_elk_backend(
  request : GraphLayoutBackendRequest,
) -> GraphLayoutBackendResult {
  run_elk_backend(request)
}

///|
/// Runs ELK backend with optional layered crossing overrides used by parity
/// analysis and stress tuning.
pub fn layout_graph_elk_backend_with_crossing_overrides(
  request : GraphLayoutBackendRequest,
  sweep_kernel : ElkLayeredRankTraceSweepKernel,
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
  trial_model_order_inversion_influence_override : Double?,
) -> GraphLayoutBackendResult {
  let has_overrides = has_rank_trace_crossing_overrides(
    trial_count_override, sweep_pass_count_override, trial_model_order_inversion_influence_override,
  )
  if sweep_kernel is Default && !has_overrides {
    run_elk_backend(request)
  } else {
    run_elk_backend_with_crossing_overrides(
      request, sweep_kernel, trial_count_override, sweep_pass_count_override, trial_model_order_inversion_influence_override,
    )
  }
}

///|
fn run_elk_backend(
  request : GraphLayoutBackendRequest,
) -> GraphLayoutBackendResult {
  let elk_policy : GraphBackendRoutingPolicy = {
    enable_target_boundary_ports: true,
    preserve_assigned_endpoint_ports: false,
  }
  let supports_layered_pipeline = elk_graph_supports_layered_pipeline(
    request.graph,
  )
  let use_legacy_seed_placement = supports_layered_pipeline &&
    select_elk_layered_rank_seed_strategy(request.graph) is LegacyLaneSeed
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
  if supports_layered_pipeline {
    run_elk_layered_flow_backend(tuned_request, elk_policy)
  } else {
    @layout_engine_graph_backend_core.run_graph_backend_pipeline(
      tuned_request, elk_policy,
    )
  }
}

///|
fn run_elk_backend_with_crossing_overrides(
  request : GraphLayoutBackendRequest,
  sweep_kernel : ElkLayeredRankTraceSweepKernel,
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
  trial_model_order_inversion_influence_override : Double?,
) -> GraphLayoutBackendResult {
  let elk_policy : GraphBackendRoutingPolicy = {
    enable_target_boundary_ports: true,
    preserve_assigned_endpoint_ports: false,
  }
  let supports_layered_pipeline = elk_graph_supports_layered_pipeline(
    request.graph,
  )
  let use_legacy_seed_placement = supports_layered_pipeline &&
    select_elk_layered_rank_seed_strategy(request.graph) is LegacyLaneSeed
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
  if !supports_layered_pipeline {
    return @layout_engine_graph_backend_core.run_graph_backend_pipeline(
      tuned_request, elk_policy,
    )
  }
  let crossing_execution_plan = crossing_execution_plan_for_rank_trace_kernel_with_overrides(
    sweep_kernel, trial_count_override, sweep_pass_count_override, trial_model_order_inversion_influence_override,
  )
  run_elk_layered_flow_backend_with_crossing_execution_plan(
    tuned_request, elk_policy, crossing_execution_plan,
  )
}
