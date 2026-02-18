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
