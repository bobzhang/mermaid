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
fn edge_operators() -> Array[EdgeOp] {
  let operators : Array[EdgeOp] = []
  for spec in @parser_common_engine_core.flow_edge_operator_specs() {
    let (symbol, style, has_arrow_start, has_arrow_end) = spec
    operators.push({ symbol, style, has_arrow_start, has_arrow_end })
  }
  operators
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
