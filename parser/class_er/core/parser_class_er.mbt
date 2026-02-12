///|
pub fn parse_class_diagram(lines : Array[String]) -> @model.MermaidGraph {
  @parser_class_er_engine_core.parse_class_diagram(lines)
}

///|
pub fn parse_er_diagram(lines : Array[String]) -> @model.MermaidGraph {
  @parser_class_er_engine_core.parse_er_diagram(lines)
}
