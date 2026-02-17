///|
/// Runs the ELK backend entrypoint.
///
/// The ELK backend currently applies ELK-specific setup tuning, then runs
/// through the shared backend pipeline with ELK routing policy.
pub fn layout_graph_elk_backend(
  request : GraphLayoutBackendRequest,
) -> GraphLayoutBackendResult {
  let elk_policy : GraphBackendRoutingPolicy = {
    enable_target_boundary_ports: true,
    preserve_assigned_endpoint_ports: false,
  }
  @layout_engine_graph_backend_core.run_graph_backend_pipeline(
    {
      graph: request.graph,
      options: derive_elk_render_options(request.graph, request.options),
      use_subgraph_redirects: request.use_subgraph_redirects,
      compact_fanin: request.compact_fanin,
    },
    elk_policy,
  )
}
