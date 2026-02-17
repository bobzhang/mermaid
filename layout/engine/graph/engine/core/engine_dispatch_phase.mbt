///|
fn dispatch_legacy_backend(
  request : GraphLayoutBackendRequest,
) -> GraphLayoutBackendResult {
  @layout_engine_graph_legacy_pipeline_core.layout_graph_legacy_backend(
    request, false, false,
  )
}

///|
fn dispatch_dagre_parity_backend(
  request : GraphLayoutBackendRequest,
) -> GraphLayoutBackendResult {
  @layout_engine_graph_engine_dagre_core.layout_graph_dagre_parity_backend(
    request,
  )
}

///|
fn dispatch_elk_backend(
  request : GraphLayoutBackendRequest,
) -> GraphLayoutBackendResult {
  @layout_engine_graph_engine_elk_core.layout_graph_elk_backend(request)
}

///|
fn dispatch_backend_by_engine(
  request : GraphLayoutBackendRequest,
  engine : LayoutEngine,
) -> GraphLayoutBackendResult {
  match engine {
    Legacy => dispatch_legacy_backend(request)
    DagreParity => dispatch_dagre_parity_backend(request)
    Elk => dispatch_elk_backend(request)
  }
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
