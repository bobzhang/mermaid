///|
/// Selected layout execution path for graph rendering.
pub(all) enum LayoutExecutionPlan {
  UseEngine(MermaidGraph, Bool, Bool)
  UseSequence(MermaidGraph)
  UseFlatStateAsciiGrid(MermaidGraph)
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
  UseEngine(graph, true, false)
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
  UseEngine(graph, !state_composite_ascii_mode, true)
}
