///|
priv struct EdgeOp {
  symbol : String
  style : EdgeStyle
  has_arrow_start : Bool
  has_arrow_end : Bool
}

///|
priv struct FoundEdgeOp {
  op : EdgeOp
  index : Int
}

///|
fn trim_owned(s : String) -> String {
  @parser_common_engine_core.trim_owned(s)
}

///|
fn parse_direction_token_strict(token : String) -> Direction? {
  @parser_common_engine_core.parse_direction_token_strict(token)
}

///|
fn parse_node_token(raw_token : String) -> MermaidNode {
  @parser_common_engine_core.parse_node_token(raw_token)
}

///|
fn ensure_node(nodes : Map[String, MermaidNode], node : MermaidNode) -> Unit {
  @parser_common_engine_core.ensure_node(nodes, node)
}

///|
fn append_nodes_to_current_subgraph(
  subgraph_stack : Array[MermaidSubgraph],
  touched_node_ids : Array[String],
) -> Unit {
  @parser_common_engine_core.append_nodes_to_current_subgraph(
    subgraph_stack, touched_node_ids,
  )
}

///|
fn append_child_subgraph(
  subgraph_stack : Array[MermaidSubgraph],
  child : MermaidSubgraph,
) -> Unit {
  @parser_common_engine_core.append_child_subgraph(subgraph_stack, child)
}

///|
fn set_current_subgraph_direction(
  subgraph_stack : Array[MermaidSubgraph],
  direction : Direction,
) -> Unit {
  @parser_common_engine_core.set_current_subgraph_direction(
    subgraph_stack, direction,
  )
}

///|
fn is_plain_identifier(text : String) -> Bool {
  @parser_common_engine_core.is_plain_identifier(text)
}

///|
fn edge_operators() -> Array[EdgeOp] {
  [
    { symbol: "<==>", style: Thick, has_arrow_start: true, has_arrow_end: true },
    {
      symbol: "<-.->",
      style: Dotted,
      has_arrow_start: true,
      has_arrow_end: true,
    },
    { symbol: "<-->", style: Solid, has_arrow_start: true, has_arrow_end: true },
    { symbol: "==>", style: Thick, has_arrow_start: false, has_arrow_end: true },
    {
      symbol: "-.->",
      style: Dotted,
      has_arrow_start: false,
      has_arrow_end: true,
    },
    { symbol: "-->", style: Solid, has_arrow_start: false, has_arrow_end: true },
    {
      symbol: "===",
      style: Thick,
      has_arrow_start: false,
      has_arrow_end: false,
    },
    {
      symbol: "-.-",
      style: Dotted,
      has_arrow_start: false,
      has_arrow_end: false,
    },
    {
      symbol: "---",
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: false,
    },
  ]
}

///|
fn edge_operator_symbols(operators : Array[EdgeOp]) -> Array[String] {
  let symbols : Array[String] = []
  for op in operators {
    symbols.push(op.symbol)
  }
  symbols
}

///|
fn find_edge_operator(line : String) -> FoundEdgeOp? {
  let operators = edge_operators()
  match
    @parser_common_engine_core.find_first_operator_indices(
      line,
      edge_operator_symbols(operators),
    ) {
    Some((operator_index, index)) =>
      Some({ op: operators[operator_index], index })
    None => None
  }
}
