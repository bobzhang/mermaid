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
/// Runs the ELK layered backend entrypoint.
///
/// This pre-alpha compatibility entrypoint currently matches
/// `layout_graph_elk_backend`.
pub fn layout_graph_elk_layered_backend(
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
  let tuned_request : GraphLayoutBackendRequest = {
    graph: request.graph,
    options: derive_elk_render_options(request.graph, request.options),
    use_subgraph_redirects: request.use_subgraph_redirects,
    compact_fanin: request.compact_fanin,
  }
  if elk_graph_supports_layered_pipeline(request.graph) {
    run_elk_layered_flow_backend(tuned_request, elk_policy)
  } else {
    @layout_engine_graph_backend_core.run_graph_backend_pipeline(
      tuned_request, elk_policy,
    )
  }
}
