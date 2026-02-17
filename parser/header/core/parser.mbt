///|
fn preprocess_lines(text : String) -> Array[String] {
  let normalized = text.replace_all(old=";", new="\n")
  let lines : Array[String] = []
  let mut at_start = true
  let mut in_frontmatter = false
  for raw in normalized.split("\n") {
    let line = @parser_common_engine_core.trim_owned(raw.to_string())
    if in_frontmatter {
      if line == "---" {
        in_frontmatter = false
      }
      continue
    }
    if at_start {
      if line == "" || line is [.. "%%", ..] {
        continue
      }
      if line == "---" {
        in_frontmatter = true
        at_start = false
        continue
      }
      at_start = false
    }
    if line == "" || line is [.. "%%", ..] {
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
  if header == "graph" ||
    header == "flowchart" ||
    header is [.. "graph ", ..] ||
    header is [.. "flowchart ", ..] {
    return @parser_flowchart_core.parse_flowchart(lines)
  }
  if header == "statediagram" || header == "statediagram-v2" {
    return @parser_state_core.parse_state_diagram(lines)
  }
  if header == "sequencediagram" {
    return @parser_sequence_core.parse_sequence_diagram(lines)
  }
  if header == "classdiagram" {
    return @parser_class_er_core.parse_class_diagram(lines)
  }
  if header == "erdiagram" {
    return @parser_class_er_core.parse_er_diagram(lines)
  }
  raise ParseFailure("Unsupported Mermaid header: \{lines[0]}")
}
