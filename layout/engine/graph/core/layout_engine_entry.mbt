///|
/// Lays out a mermaid graph for SVG rendering.
pub fn layout_graph(
  graph : MermaidGraph,
  options : RenderOptions,
) -> PositionedGraph {
  @layout_engine_graph_execute_core.execute_layout_plan(
    @layout_engine_graph_plan_core.build_svg_layout_execution_plan(graph),
    options,
  )
}

///|
/// Lays out a mermaid graph for ASCII text rendering.
pub fn layout_graph_for_ascii(
  graph : MermaidGraph,
  options : RenderOptions,
) -> PositionedGraph {
  @layout_engine_graph_execute_core.execute_layout_plan(
    @layout_engine_graph_plan_core.build_ascii_layout_execution_plan(graph),
    options,
  )
}
