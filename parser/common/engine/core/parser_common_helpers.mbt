///|
pub fn trim_owned(s : String) -> String {
  s.trim().to_string()
}

///|
pub fn ensure_node(
  nodes : Map[String, @model.MermaidNode],
  node : @model.MermaidNode,
) -> Unit {
  if !nodes.contains(node.id) {
    nodes[node.id] = node
  }
}

///|
pub fn is_plain_identifier(text : String) -> Bool {
  text != "" &&
  !text.contains(" ") &&
  !text.has_prefix("+") &&
  !text.has_prefix("-")
}
