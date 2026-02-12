///|
pub fn render_ascii_er(
  graph : @model.MermaidGraph,
  options : @model.AsciiRenderOptions,
) -> String {
  @renderer_ascii_class_er_engine_core.render_ascii_er(graph, options)
}
