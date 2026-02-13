/// Renders a sequence diagram as ASCII/Unicode text art.
pub fn render_ascii_sequence(
  graph : @model.MermaidGraph,
  sequence_layout : @renderer_ascii_layout_plan.AsciiSequenceLayout,
  options : @model.AsciiRenderOptions,
) -> String {
  @renderer_ascii_sequence_engine_core.render_ascii_sequence(
    graph, sequence_layout, options,
  )
}
