///|
/// Resolves backend routing policy for the selected graph layout engine.
pub fn resolve_graph_engine_routing_policy(
  engine : LayoutEngine,
) -> GraphBackendRoutingPolicy {
  match engine {
    Legacy =>
      {
        enable_target_boundary_ports: false,
        preserve_assigned_endpoint_ports: false,
      }
    DagreParity =>
      {
        enable_target_boundary_ports: true,
        preserve_assigned_endpoint_ports: true,
      }
    Elk =>
      {
        enable_target_boundary_ports: true,
        preserve_assigned_endpoint_ports: false,
      }
  }
}

///|
/// Runs the shared backend pipeline with the selected engine profile.
pub fn run_graph_layout_engine_backend(
  request : GraphLayoutBackendRequest,
  engine : LayoutEngine,
) -> GraphLayoutBackendResult {
  @layout_engine_graph_backend_core.run_graph_backend_pipeline(
    request,
    resolve_graph_engine_routing_policy(engine),
  )
}
