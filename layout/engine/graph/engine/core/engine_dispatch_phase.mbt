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
) -> @layout_engine_graph_legacy_core.LegacyRoutingProfile {
  match engine {
    Legacy => LegacyCompatible
    DagreParity | Elk => DagreParityCompatible
  }
}

///|
/// Runs the selected graph layout engine through the current legacy-backed dispatcher.
pub fn dispatch_graph_layout_engine(
  request : GraphEngineDispatchRequest,
) -> PositionedGraph {
  let engine = match request.engine {
    Elk =>
      // Reserve ELK in the selector while parity work is in progress.
      @model.DagreParity
    other => other
  }
  @layout_engine_graph_legacy_core.layout_graph_legacy({
    graph: request.graph,
    options: request.options,
    use_subgraph_redirects: request.use_subgraph_redirects,
    compact_fanin: request.compact_fanin,
    routing_profile: legacy_routing_profile(engine),
  })
}
