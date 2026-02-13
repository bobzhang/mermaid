///|
pub fn render_ascii_class(
  graph : @model.MermaidGraph,
  class_layout : @renderer_ascii_layout_plan.AsciiClassLayout,
  options : @model.AsciiRenderOptions,
) -> String {
  @renderer_ascii_class_er_engine_core.render_ascii_class(
    graph, class_layout, options,
  )
}
