///|
/// Runs the legacy graph backend and returns final layout with phase snapshots.
pub fn layout_graph_legacy_backend(
  request : GraphLayoutBackendRequest,
  enable_target_boundary_ports : Bool,
  preserve_assigned_endpoint_ports : Bool,
) -> GraphLayoutBackendResult {
  let routing_policy : GraphBackendRoutingPolicy = {
    enable_target_boundary_ports,
    preserve_assigned_endpoint_ports,
  }
  @layout_engine_graph_backend_core.run_graph_backend_pipeline(
    request, routing_policy,
  )
}

///|
/// Runs the legacy graph layout pipeline with explicit routing toggles.
pub fn layout_graph_legacy(
  graph : MermaidGraph,
  options : RenderOptions,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
  enable_target_boundary_ports : Bool,
  preserve_assigned_endpoint_ports : Bool,
) -> PositionedGraph {
  layout_graph_legacy_backend(
    { graph, options, use_subgraph_redirects, compact_fanin },
    enable_target_boundary_ports,
    preserve_assigned_endpoint_ports,
  ).positioned_graph
}
