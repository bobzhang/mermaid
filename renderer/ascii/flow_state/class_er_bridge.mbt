///|
fn render_ascii_class(
  graph : MermaidGraph,
  options : AsciiRenderOptions,
) -> String {
  @renderer_ascii_class_er.render_ascii_class(graph, options)
}

///|
fn render_ascii_er(
  graph : MermaidGraph,
  options : AsciiRenderOptions,
) -> String {
  @renderer_ascii_class_er.render_ascii_er(graph, options)
}
