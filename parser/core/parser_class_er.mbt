///|
fn parse_class_diagram(lines : Array[String]) -> MermaidGraph {
  @parser_class_er_core.parse_class_diagram(lines)
}

///|
fn parse_er_diagram(lines : Array[String]) -> MermaidGraph {
  @parser_class_er_core.parse_er_diagram(lines)
}
