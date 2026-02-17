///|
/// Runs the ELK backend entrypoint.
///
/// Current implementation preserves behavior by delegating to the
/// Dagre-parity-compatible legacy profile.
pub fn layout_graph_elk(
  graph : MermaidGraph,
  options : RenderOptions,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
) -> PositionedGraph {
  @layout_engine_graph_legacy_pipeline_core.layout_graph_legacy(
    graph, options, use_subgraph_redirects, compact_fanin, true, true,
  )
}
