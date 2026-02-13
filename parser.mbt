///|
/// Parse Mermaid text into the normalized in-memory graph model used by
/// both SVG and ASCII renderers.
///
/// Supported headers:
/// - `graph` / `flowchart`
/// - `stateDiagram` / `stateDiagram-v2`
/// - `sequenceDiagram`
/// - `classDiagram`
/// - `erDiagram`
pub fn parse_mermaid(text : String) -> MermaidGraph raise MermaidError {
  @parser_header_core.parse_mermaid(text)
}
