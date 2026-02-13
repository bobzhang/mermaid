///|
/// Parses state diagram body lines into a `MermaidGraph`.
pub fn parse_state_diagram(lines : Array[String]) -> @model.MermaidGraph {
  @parser_state_engine_core.parse_state_diagram(lines)
}
