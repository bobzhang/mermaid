///|
priv struct LayoutGraphIR {
  graph : MermaidGraph
  use_subgraph_redirects : Bool
  compact_fanin : Bool
}

///|
priv enum LayoutExecutionPlan {
  UseEngine(LayoutGraphIR)
  UseSequence(MermaidGraph)
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
fn build_layout_graph_ir(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
) -> LayoutGraphIR {
  { graph, use_subgraph_redirects, compact_fanin }
}

///|
fn graph_is_sequence_layout(graph : MermaidGraph) -> Bool {
  let nodes = graph.nodes.values().to_array()
  if nodes.length() == 0 {
    return false
  }
  for node in nodes {
    if node.shape != SequenceParticipant {
      return false
    }
  }
  true
}

///|
fn run_layout_engine(
  ir : LayoutGraphIR,
  options : RenderOptions,
  engine : LayoutEngine,
) -> PositionedGraph {
  @layout_engine_graph_engine_core.dispatch_graph_layout_engine({
    graph: ir.graph,
    options,
    use_subgraph_redirects: ir.use_subgraph_redirects,
    compact_fanin: ir.compact_fanin,
    engine,
  })
}

///|
fn execute_layout_plan(
  plan : LayoutExecutionPlan,
  options : RenderOptions,
) -> PositionedGraph {
  match plan {
    UseEngine(ir) =>
      run_layout_engine(ir, options, resolve_layout_engine(options))
    UseSequence(graph) =>
      @layout_engine_sequence_core.layout_sequence_graph(graph, options)
    UseFlatStateAsciiGrid(graph) =>
      @layout_engine_graph_ascii_core.layout_flat_state_graph_for_ascii_grid(
        graph, options,
      )
  }
}

///|
fn build_svg_layout_execution_plan(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
) -> LayoutExecutionPlan {
  if graph_is_sequence_layout(graph) {
    return UseSequence(graph)
  }
  UseEngine(build_layout_graph_ir(graph, use_subgraph_redirects, compact_fanin))
}

///|
fn build_ascii_layout_execution_plan(
  graph : MermaidGraph,
) -> LayoutExecutionPlan {
  if graph_is_sequence_layout(graph) {
    return UseSequence(graph)
  }

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
