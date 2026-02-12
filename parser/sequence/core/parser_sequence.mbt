///|
pub fn parse_sequence_diagram(lines : Array[String]) -> @model.MermaidGraph {
  @parser_sequence_engine_core.parse_sequence_diagram(lines)
}
