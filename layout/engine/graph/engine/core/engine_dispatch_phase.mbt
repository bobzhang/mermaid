///|
priv struct LegacyRoutingFlags {
  enable_target_boundary_ports : Bool
  preserve_assigned_endpoint_ports : Bool
}

///|
/// Engine dispatch request assembled by graph core orchestration.
pub(all) struct GraphEngineDispatchRequest {
  graph : MermaidGraph
  options : RenderOptions
  use_subgraph_redirects : Bool
  compact_fanin : Bool
  engine : LayoutEngine
}

///|
fn legacy_pipeline_routing_flags(engine : LayoutEngine) -> LegacyRoutingFlags {
  match engine {
    Legacy =>
      {
        enable_target_boundary_ports: false,
        preserve_assigned_endpoint_ports: false,
      }
    DagreParity | Elk =>
      {
        enable_target_boundary_ports: true,
        preserve_assigned_endpoint_ports: true,
      }
  }
}

///|
/// Runs the selected graph layout engine through the current legacy-backed dispatcher.
pub fn dispatch_graph_layout_engine(
  request : GraphEngineDispatchRequest,
) -> PositionedGraph {
  let routing_flags = match request.engine {
    Legacy => legacy_pipeline_routing_flags(Legacy)
    DagreParity => legacy_pipeline_routing_flags(DagreParity)
    Elk =>
      // Reserve ELK in the selector while parity work is in progress.
      legacy_pipeline_routing_flags(DagreParity)
  }
  @layout_engine_graph_legacy_core.layout_graph_legacy_with_subgraph_redirects({
    graph: request.graph,
    options: request.options,
    use_subgraph_redirects: request.use_subgraph_redirects,
    compact_fanin: request.compact_fanin,
    enable_target_boundary_ports: routing_flags.enable_target_boundary_ports,
    preserve_assigned_endpoint_ports: routing_flags.preserve_assigned_endpoint_ports,
  })
}
