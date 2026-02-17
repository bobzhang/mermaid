///|
/// Runs the ELK backend entrypoint.
///
/// The ELK backend applies ELK-specific setup tuning and uses the ELK layered
/// flow pipeline for non-state flowcharts within the default complexity budget.
/// Other graph kinds fallback to the shared backend pipeline with ELK routing
/// policy.
pub fn layout_graph_elk_backend(
  request : GraphLayoutBackendRequest,
) -> GraphLayoutBackendResult {
  layout_graph_elk_backend_with_mode(request, false)
}

///|
/// Runs the ELK layered backend entrypoint.
///
/// This mode always runs the ELK layered flow pipeline for supported
/// non-state flowcharts (without the default complexity gate).
pub fn layout_graph_elk_layered_backend(
  request : GraphLayoutBackendRequest,
) -> GraphLayoutBackendResult {
  layout_graph_elk_backend_with_mode(request, true)
}

///|
fn layout_graph_elk_backend_with_mode(
  request : GraphLayoutBackendRequest,
  force_layered_pipeline : Bool,
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
  let use_layered_pipeline = if force_layered_pipeline {
    elk_graph_supports_layered_pipeline(request.graph)
  } else {
    elk_graph_supports_layered_pipeline(request.graph)
  }
  if use_layered_pipeline {
    run_elk_layered_flow_backend(tuned_request, elk_policy)
  } else {
    @layout_engine_graph_backend_core.run_graph_backend_pipeline(
      tuned_request, elk_policy,
    )
  }
}
