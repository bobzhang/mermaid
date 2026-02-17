///|
fn dispatch_backend_by_engine(
  request : GraphLayoutBackendRequest,
  engine : LayoutEngine,
) -> GraphLayoutBackendResult {
  @layout_engine_graph_engine_profile_core.run_graph_layout_engine_backend(
    request, engine,
  )
}

///|
fn make_backend_request(
  graph : MermaidGraph,
  options : RenderOptions,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
) -> GraphLayoutBackendRequest {
  { graph, options, use_subgraph_redirects, compact_fanin }
}

///|
/// Runs the selected graph layout engine backend and returns phase snapshots.
pub fn dispatch_graph_layout_engine_backend(
  graph : MermaidGraph,
  options : RenderOptions,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
  engine : LayoutEngine,
) -> GraphLayoutBackendResult {
  dispatch_backend_by_engine(
    make_backend_request(graph, options, use_subgraph_redirects, compact_fanin),
    engine,
  )
}

///|
/// Runs the selected graph layout engine through the current dispatcher.
pub fn dispatch_graph_layout_engine(
  graph : MermaidGraph,
  options : RenderOptions,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
  engine : LayoutEngine,
) -> PositionedGraph {
  dispatch_graph_layout_engine_backend(
    graph, options, use_subgraph_redirects, compact_fanin, engine,
  ).positioned_graph
}
