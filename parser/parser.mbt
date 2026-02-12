///|
pub fn parse_mermaid(text : String) -> MermaidGraph raise MermaidError {
  @parser_core.parse_mermaid(text)
}
