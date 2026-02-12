///|
pub fn parse_flowchart(
  lines : Array[String],
) -> @model.MermaidGraph raise @model.MermaidError {
  @parser_flowchart_engine_core.parse_flowchart(lines)
}
