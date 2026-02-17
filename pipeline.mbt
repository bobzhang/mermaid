///|
fn parse_mermaid_graph(text : String) -> MermaidGraph raise MermaidError {
  @parser_header_core.parse_mermaid(text)
}

///|
fn layout_mermaid_graph(
  graph : MermaidGraph,
  options : RenderOptions,
) -> @model.PositionedGraph {
  @layout.layout_graph(graph, options)
}

///|
fn parse_and_layout_mermaid_graph(
  text : String,
  options : RenderOptions,
) -> @model.PositionedGraph raise MermaidError {
  layout_mermaid_graph(parse_mermaid_graph(text), options)
}

///|
fn parse_mermaid_graph_for_text_render(
  text : String,
) -> MermaidGraph raise MermaidError {
  @parser_header_core.parse_mermaid(text)
}
