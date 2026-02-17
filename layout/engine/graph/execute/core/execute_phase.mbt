///|
fn run_layout_engine(
  plan : LayoutGraphPlan,
  options : RenderOptions,
) -> PositionedGraph {
  let engine = @layout_engine_graph_plan_core.resolve_layout_engine(options)
  @layout_engine_graph_engine_core.dispatch_graph_layout_engine(
    plan.graph,
    options,
    plan.use_subgraph_redirects,
    plan.compact_fanin,
    engine,
  )
}

///|
/// Executes a selected graph layout plan and returns positioned output.
pub fn execute_layout_plan(
  plan : LayoutExecutionPlan,
  options : RenderOptions,
) -> PositionedGraph {
  match plan {
    UseEngine(engine_plan) => run_layout_engine(engine_plan, options)
    UseSequence(graph) =>
      @layout_engine_sequence_core.layout_sequence_graph(graph, options)
    UseFlatStateAsciiGrid(graph) =>
      @layout_engine_graph_ascii_core.layout_flat_state_graph_for_ascii_grid(
        graph, options,
      )
  }
}
