///|
fn trim_owned(s : String) -> String {
  s.trim().to_string()
}

///|
fn preprocess_lines(text : String) -> Array[String] {
  let normalized = text.replace_all(old=";", new="\n")
  let lines : Array[String] = []
  for raw in normalized.split("\n") {
    let line = trim_owned(raw.to_string())
    if line == "" || line.has_prefix("%%") {
      continue
    }
    lines.push(line)
  }
  lines
}

///|
/// Parse Mermaid text into the normalized in-memory graph model used by
/// both SVG and ASCII renderers.
///
/// Supported headers:
/// - `graph` / `flowchart`
/// - `stateDiagram` / `stateDiagram-v2`
/// - `sequenceDiagram`
/// - `classDiagram`
/// - `erDiagram`
pub fn parse_mermaid(text : String) -> MermaidGraph raise MermaidError {
  let lines = preprocess_lines(text)
  if lines.length() == 0 {
    raise ParseFailure("Mermaid input is empty")
  }
  let header = lines[0].replace_all(old="\t", new=" ").to_lower()
  if header.has_prefix("graph ") || header.has_prefix("flowchart ") {
    return parse_flowchart(lines)
  }
  if header == "statediagram" || header == "statediagram-v2" {
    return parse_state_diagram(lines)
  }
  if header == "sequencediagram" {
    return parse_sequence_diagram(lines)
  }
  if header == "classdiagram" {
    return parse_class_diagram(lines)
  }
  if header == "erdiagram" {
    return parse_er_diagram(lines)
  }
  raise ParseFailure("Unsupported Mermaid header: \{lines[0]}")
}
