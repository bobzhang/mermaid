///|
/// Executes a selected graph layout plan and returns positioned output.
pub fn execute_layout_plan(
  plan : LayoutExecutionPlan,
  options : RenderOptions,
) -> PositionedGraph {
  match plan {
    UseEngine(graph, use_subgraph_redirects, compact_fanin) => {
      let engine = match options.layout_engine {
        Some(engine) => engine
        None => Legacy
      }
      let backend = @layout_engine_graph_engine_core.dispatch_graph_layout_engine_backend(
        graph, options, use_subgraph_redirects, compact_fanin, engine,
      )
      backend.positioned_graph
    }
    UseSequence(graph) =>
      @layout_engine_sequence_core.layout_sequence_graph(graph, options)
    UseFlatStateAsciiGrid(graph) =>
      @layout_engine_graph_ascii_core.layout_flat_state_graph_for_ascii_grid(
        graph, options,
      )
  }
}
