///|
pub fn render_ascii_er(
  graph : @model.MermaidGraph,
  er_layout : @renderer_ascii_layout_plan.AsciiErLayout,
  options : @model.AsciiRenderOptions,
) -> String {
  @renderer_ascii_class_er_engine_core.render_ascii_er(
    graph, er_layout, options,
  )
}
