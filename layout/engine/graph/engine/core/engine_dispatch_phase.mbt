///|
fn routing_flags_for_engine(engine : LayoutEngine) -> (Bool, Bool) {
  match engine {
    Legacy => (false, false)
    DagreParity => (true, true)
    Elk => (true, true)
  }
}

///|
fn dispatch_legacy_backend(
  request : GraphLayoutBackendRequest,
  engine : LayoutEngine,
) -> GraphLayoutBackendResult {
  let (enable_target_boundary_ports, preserve_assigned_endpoint_ports) = routing_flags_for_engine(
    engine,
  )
  @layout_engine_graph_legacy_pipeline_core.layout_graph_legacy_backend(
    request, enable_target_boundary_ports, preserve_assigned_endpoint_ports,
  )
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
  let request : GraphLayoutBackendRequest = {
    graph,
    options,
    use_subgraph_redirects,
    compact_fanin,
  }
  match engine {
    Legacy => dispatch_legacy_backend(request, Legacy)
    DagreParity => dispatch_legacy_backend(request, DagreParity)
    Elk =>
      @layout_engine_graph_engine_elk_core.layout_graph_elk_backend(request)
  }
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
