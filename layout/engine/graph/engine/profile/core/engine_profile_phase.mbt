///|
/// Resolves backend routing policy for the selected graph layout engine.
fn resolve_graph_engine_routing_policy(
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
    Elk | ElkLayered =>
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
  match engine {
    Elk | ElkLayered =>
      @layout_engine_graph_engine_elk_core.layout_graph_elk_backend(request)
    DagreParity => {
      let tuned_request : GraphLayoutBackendRequest = {
        ..request,
        options: { ..request.options, layout_engine: Some(DagreParity) },
      }
      @layout_engine_graph_backend_core.run_graph_backend_pipeline(
        tuned_request,
        resolve_graph_engine_routing_policy(engine),
      )
    }
    Legacy =>
      @layout_engine_graph_backend_core.run_graph_backend_pipeline(
        request,
        resolve_graph_engine_routing_policy(engine),
      )
  }
}
