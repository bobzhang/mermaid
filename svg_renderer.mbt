///|
fn render_svg(
  graph : PositionedGraph,
  colors : DiagramColors,
  font : String,
  transparent : Bool,
) -> String {
  @renderer_svg.render_svg(graph, colors, font, transparent)
}
