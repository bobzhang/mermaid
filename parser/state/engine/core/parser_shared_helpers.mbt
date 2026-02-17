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
fn find_first_operator_indices(
  line : String,
  operator_symbols : Array[String],
) -> (Int, Int)? {
  for i in 0..<operator_symbols.length() {
    match line.find(operator_symbols[i]) {
      Some(index) => return Some((i, index))
      None => ()
    }
  }
  None
}

///|
fn flow_edge_operator_specs() -> Array[(String, EdgeStyle, Bool, Bool)] {
  [
    ("<==>", Thick, true, true),
    ("<-.->", Dotted, true, true),
    ("<-->", Solid, true, true),
    ("==>", Thick, false, true),
    ("-.->", Dotted, false, true),
    ("-->", Solid, false, true),
    ("===", Thick, false, false),
    ("-.-", Dotted, false, false),
    ("---", Solid, false, false),
  ]
}

///|
fn edge_operators() -> Array[EdgeOp] {
  let operators : Array[EdgeOp] = []
  for spec in flow_edge_operator_specs() {
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
  match find_first_operator_indices(line, edge_operator_symbols(operators)) {
    Some((operator_index, index)) =>
      Some({ op: operators[operator_index], index })
    None => None
  }
}
