///|
/// Parses a mermaid diagram string into a `MermaidGraph`.
pub fn parse_mermaid(text : String) -> MermaidGraph raise MermaidError {
  @parser_header_core.parse_mermaid(text)
}
