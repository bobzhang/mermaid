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
fn legacy_routing_profile(
  engine : LayoutEngine,
) -> @layout_engine_graph_engine_legacy_core.LegacyRoutingProfile {
  match engine {
    Legacy => LegacyCompatible
    DagreParity => DagreParityCompatible
    Elk => DagreParityCompatible
  }
}

///|
fn dispatch_legacy_backend(
  request : GraphEngineDispatchRequest,
  engine : LayoutEngine,
) -> PositionedGraph {
  @layout_engine_graph_engine_legacy_core.layout_graph_engine_legacy({
    graph: request.graph,
    options: request.options,
    use_subgraph_redirects: request.use_subgraph_redirects,
    compact_fanin: request.compact_fanin,
    routing_profile: legacy_routing_profile(engine),
  })
}

///|
/// Runs the selected graph layout engine through the current legacy-backed dispatcher.
pub fn dispatch_graph_layout_engine(
  request : GraphEngineDispatchRequest,
) -> PositionedGraph {
  match request.engine {
    Legacy => dispatch_legacy_backend(request, Legacy)
    DagreParity => dispatch_legacy_backend(request, DagreParity)
    Elk =>
      @layout_engine_graph_engine_elk_core.layout_graph_elk({
        graph: request.graph,
        options: request.options,
        use_subgraph_redirects: request.use_subgraph_redirects,
        compact_fanin: request.compact_fanin,
      })
  }
}
