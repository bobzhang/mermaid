///|
fn trim_owned(s : String) -> String {
  @parser_common_engine_core.trim_owned(s)
}

///|
fn ensure_node(nodes : Map[String, MermaidNode], node : MermaidNode) -> Unit {
  @parser_common_engine_core.ensure_node(nodes, node)
}

///|
fn is_plain_identifier(text : String) -> Bool {
  @parser_common_engine_core.is_plain_identifier(text)
}
