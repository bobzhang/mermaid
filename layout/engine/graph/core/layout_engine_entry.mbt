///|
priv struct LayoutGraphIR {
  graph : MermaidGraph
  use_subgraph_redirects : Bool
  compact_fanin : Bool
}

///|
priv enum LayoutExecutionPlan {
  UseEngine(LayoutGraphIR)
  UseFlatStateAsciiGrid(MermaidGraph)
}

///|
fn resolve_layout_engine(options : RenderOptions) -> LayoutEngine {
  match options.layout_engine {
    Some(engine) => engine
    None => Legacy
  }
}

///|
fn legacy_pipeline_routing_flags(engine : LayoutEngine) -> (Bool, Bool) {
  match engine {
    Legacy => (false, false)
    DagreParity | Elk => (true, true)
  }
}

///|
fn build_layout_graph_ir(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
) -> LayoutGraphIR {
  { graph, use_subgraph_redirects, compact_fanin }
}

///|
fn run_layout_engine(
  ir : LayoutGraphIR,
  options : RenderOptions,
  engine : LayoutEngine,
) -> PositionedGraph {
  let (enable_target_boundary_ports, preserve_assigned_endpoint_ports) = match
    engine {
    Legacy => legacy_pipeline_routing_flags(Legacy)
    DagreParity => legacy_pipeline_routing_flags(DagreParity)
    Elk =>
      // Reserve the ELK slot in the public selector while preserving current
      // non-ELK behavior during the modular refactor.
      legacy_pipeline_routing_flags(DagreParity)
  }
  @layout_engine_graph_legacy_core.layout_graph_legacy_with_subgraph_redirects(
    ir.graph,
    options,
    ir.use_subgraph_redirects,
    ir.compact_fanin,
    enable_target_boundary_ports,
    preserve_assigned_endpoint_ports,
  )
}

///|
fn execute_layout_plan(
  plan : LayoutExecutionPlan,
  options : RenderOptions,
) -> PositionedGraph {
  match plan {
    UseEngine(ir) =>
      run_layout_engine(ir, options, resolve_layout_engine(options))
    UseFlatStateAsciiGrid(graph) =>
      layout_flat_state_graph_for_ascii_grid(graph, options)
  }
}

///|
fn build_svg_layout_execution_plan(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
) -> LayoutExecutionPlan {
  UseEngine(build_layout_graph_ir(graph, use_subgraph_redirects, compact_fanin))
}

///|
fn build_ascii_layout_execution_plan(
  graph : MermaidGraph,
) -> LayoutExecutionPlan {
  let state_graph = @layout_engine_graph_internal_core.is_state_graph(graph)
  let horizontal = @layout_engine_graph_internal_core.layout_direction_is_horizontal(
    graph.direction,
  )
  let reverse = @layout_engine_graph_internal_core.layout_direction_is_reverse(
    graph.direction,
  )
  let state_flat_ascii_grid_mode = state_graph && !horizontal && !reverse
  if state_flat_ascii_grid_mode {
    return UseFlatStateAsciiGrid(graph)
  }

  let state_composite_ascii_mode = state_graph && graph.subgraphs.length() > 0
  UseEngine(build_layout_graph_ir(graph, !state_composite_ascii_mode, true))
}

///|
/// Lays out a mermaid graph for SVG rendering.
pub fn layout_graph(
  graph : MermaidGraph,
  options : RenderOptions,
) -> PositionedGraph {
  execute_layout_plan(
    build_svg_layout_execution_plan(graph, true, false),
    options,
  )
}

///|
/// Lays out a mermaid graph for ASCII text rendering.
pub fn layout_graph_for_ascii(
  graph : MermaidGraph,
  options : RenderOptions,
) -> PositionedGraph {
  execute_layout_plan(build_ascii_layout_execution_plan(graph), options)
}
