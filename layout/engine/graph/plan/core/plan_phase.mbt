///|
/// Graph layout input passed to engine dispatch.
pub(all) struct LayoutGraphPlan {
  graph : MermaidGraph
  use_subgraph_redirects : Bool
  compact_fanin : Bool
}

///|
/// Selected layout execution path for graph rendering.
pub(all) enum LayoutExecutionPlan {
  UseEngine(LayoutGraphPlan)
  UseSequence(MermaidGraph)
  UseFlatStateAsciiGrid(MermaidGraph)
}

///|
/// Resolves the effective layout engine from render options.
pub fn resolve_layout_engine(options : RenderOptions) -> LayoutEngine {
  match options.layout_engine {
    Some(engine) => engine
    None => Legacy
  }
}

///|
fn build_layout_graph_plan(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  compact_fanin : Bool,
) -> LayoutGraphPlan {
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
/// Builds the SVG layout execution plan for a parsed graph.
pub fn build_svg_layout_execution_plan(
  graph : MermaidGraph,
) -> LayoutExecutionPlan {
  if graph_is_sequence_layout(graph) {
    return UseSequence(graph)
  }
  UseEngine(build_layout_graph_plan(graph, true, false))
}

///|
/// Builds the ASCII layout execution plan for a parsed graph.
pub fn build_ascii_layout_execution_plan(
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
  UseEngine(build_layout_graph_plan(graph, !state_composite_ascii_mode, true))
}
