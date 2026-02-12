///|
pub fn render_ascii(
  graph : @model.MermaidGraph,
  options : @model.AsciiRenderOptions,
) -> String {
  @renderer_ascii_flow_state_engine_core.render_ascii(graph, options)
}
