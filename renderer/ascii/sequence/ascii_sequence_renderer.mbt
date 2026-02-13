///|
pub fn render_ascii_sequence(
  graph : @model.MermaidGraph,
  sequence_layout : @renderer_ascii_layout_plan.AsciiSequenceLayout,
  options : @model.AsciiRenderOptions,
) -> String {
  @renderer_ascii_sequence_core.render_ascii_sequence(
    graph, sequence_layout, options,
  )
}
