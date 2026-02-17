///|
/// ELK backend request shared by engine dispatch.
pub(all) struct ElkLayoutRequest {
  graph : MermaidGraph
  options : RenderOptions
  use_subgraph_redirects : Bool
  compact_fanin : Bool
}

///|
/// Runs the ELK backend entrypoint.
///
/// Current implementation preserves behavior by delegating to the
/// Dagre-parity-compatible legacy profile.
pub fn layout_graph_elk(request : ElkLayoutRequest) -> PositionedGraph {
  @layout_engine_graph_engine_legacy_core.layout_graph_engine_legacy({
    graph: request.graph,
    options: request.options,
    use_subgraph_redirects: request.use_subgraph_redirects,
    compact_fanin: request.compact_fanin,
    routing_profile: DagreParityCompatible,
  })
}
