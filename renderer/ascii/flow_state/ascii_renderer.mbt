/// Renders a mermaid graph as ASCII/Unicode text art.
pub fn render_ascii(
  graph : @model.MermaidGraph,
  options : @model.AsciiRenderOptions,
) -> String {
  @renderer_ascii_flow_state_core.render_ascii(graph, options)
}
