///|
/// Renders a positioned graph as an SVG string.
pub fn render_svg(
  graph : @model.PositionedGraph,
  colors : @model.DiagramColors,
  font_family : String,
  transparent : Bool,
) -> String {
  @renderer_svg_engine_core.render_svg(graph, colors, font_family, transparent)
}
