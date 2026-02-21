///|
/// Runs the selected graph layout engine through the current dispatcher.
pub fn dispatch_graph_layout_engine_backend(
  graph : MermaidGraph,
  options : RenderOptions,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
  engine : LayoutEngine,
) -> GraphLayoutBackendResult {
  @layout_engine_graph_engine_profile_core.run_graph_layout_engine_backend(
    { graph, options, use_subgraph_redirects, compact_fanin },
    engine,
  )
}
