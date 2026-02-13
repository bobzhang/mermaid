///|
fn render_ascii_sequence(
  graph : MermaidGraph,
  sequence_layout : @renderer_ascii_layout_plan.AsciiSequenceLayout,
  options : AsciiRenderOptions,
) -> String {
  @renderer_ascii_sequence.render_ascii_sequence(
    graph, sequence_layout, options,
  )
}
