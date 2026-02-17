///|
/// Runs the ELK backend entrypoint.
///
/// Current implementation runs through the shared backend pipeline with
/// ELK-tuned routing policy.
pub fn layout_graph_elk_backend(
  request : GraphLayoutBackendRequest,
) -> GraphLayoutBackendResult {
  let routing_policy : GraphBackendRoutingPolicy = {
    enable_target_boundary_ports: true,
    // ELK profile prefers flexible endpoint routing instead of preserving
    // pre-assigned ports from the Dagre-parity profile.
    preserve_assigned_endpoint_ports: false,
  }
  @layout_engine_graph_backend_core.run_graph_backend_pipeline(
    request, routing_policy,
  )
}

///|
/// Runs the ELK backend and returns positioned output only.
pub fn layout_graph_elk(
  graph : MermaidGraph,
  options : RenderOptions,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
) -> PositionedGraph {
  layout_graph_elk_backend({
    graph,
    options,
    use_subgraph_redirects,
    compact_fanin,
  }).positioned_graph
}
