///|
/// Parses a mermaid diagram string into a `MermaidGraph`.
pub fn parse_mermaid(
  text : String,
) -> @model.MermaidGraph raise @model.MermaidError {
  @parser_core.parse_mermaid(text)
}
