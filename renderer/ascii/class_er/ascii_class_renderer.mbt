///|
pub fn render_ascii_class(
  graph : @model.MermaidGraph,
  options : @model.AsciiRenderOptions,
) -> String {
  @renderer_ascii_class_er_core.render_ascii_class(graph, options)
}
