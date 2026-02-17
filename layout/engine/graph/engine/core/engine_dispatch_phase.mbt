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
  graph : MermaidGraph,
  options : RenderOptions,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
  engine : LayoutEngine,
) -> PositionedGraph {
  let (enable_target_boundary_ports, preserve_assigned_endpoint_ports) = routing_flags_for_engine(
    engine,
  )
  @layout_engine_graph_legacy_pipeline_core.layout_graph_legacy(
    graph, options, use_subgraph_redirects, compact_fanin, enable_target_boundary_ports,
    preserve_assigned_endpoint_ports,
  )
}

///|
/// Runs the selected graph layout engine through the current legacy-backed dispatcher.
pub fn dispatch_graph_layout_engine(
  graph : MermaidGraph,
  options : RenderOptions,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
  engine : LayoutEngine,
) -> PositionedGraph {
  match engine {
    Legacy =>
      dispatch_legacy_backend(
        graph,
        options,
        use_subgraph_redirects,
        compact_fanin,
        Legacy,
      )
    DagreParity =>
      dispatch_legacy_backend(
        graph,
        options,
        use_subgraph_redirects,
        compact_fanin,
        DagreParity,
      )
    Elk =>
      @layout_engine_graph_engine_elk_core.layout_graph_elk(
        graph, options, use_subgraph_redirects, compact_fanin,
      )
  }
}
