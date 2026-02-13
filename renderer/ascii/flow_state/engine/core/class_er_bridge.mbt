///|
fn render_ascii_class(
  graph : MermaidGraph,
  class_layout : @renderer_ascii_layout_plan.AsciiClassLayout,
  options : AsciiRenderOptions,
) -> String {
  @renderer_ascii_class_er.render_ascii_class(graph, class_layout, options)
}

///|
fn render_ascii_er(
  graph : MermaidGraph,
  er_layout : @renderer_ascii_layout_plan.AsciiErLayout,
  options : AsciiRenderOptions,
) -> String {
  @renderer_ascii_class_er.render_ascii_er(graph, er_layout, options)
}
