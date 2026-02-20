///|
/// Derives ELK-preferred render options for the graph.
///
/// Keep caller spacing unchanged: upstream Mermaid ELK relies on base spacing
/// and measured node geometry instead of graph-complexity spacing heuristics.
fn derive_elk_render_options(
  _graph : MermaidGraph,
  options : RenderOptions,
) -> RenderOptions {
  options
}
