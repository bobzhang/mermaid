///|
/// Runs the ELK backend entrypoint.
///
/// Current implementation preserves behavior by delegating to the
/// Dagre-parity-compatible legacy profile.
pub fn layout_graph_elk_backend(
  request : GraphLayoutBackendRequest,
) -> GraphLayoutBackendResult {
  @layout_engine_graph_legacy_pipeline_core.layout_graph_legacy_backend(
    request, true, true,
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
