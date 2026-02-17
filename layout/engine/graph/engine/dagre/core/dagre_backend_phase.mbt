///|
/// Runs the Dagre-parity backend and returns final layout with phase snapshots.
pub fn layout_graph_dagre_parity_backend(
  request : GraphLayoutBackendRequest,
) -> GraphLayoutBackendResult {
  let routing_policy : GraphBackendRoutingPolicy = {
    enable_target_boundary_ports: true,
    preserve_assigned_endpoint_ports: true,
  }
  @layout_engine_graph_backend_core.run_graph_backend_pipeline(
    request, routing_policy,
  )
}
