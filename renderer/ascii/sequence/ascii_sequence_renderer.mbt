///|
pub fn render_ascii_sequence(
  graph : @model.MermaidGraph,
  options : @model.AsciiRenderOptions,
) -> String {
  @renderer_ascii_sequence_core.render_ascii_sequence(graph, options)
}
