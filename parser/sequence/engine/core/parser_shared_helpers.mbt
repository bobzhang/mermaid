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
fn find_earliest_operator_indices(
  line : String,
  operator_symbols : Array[String],
) -> (Int, Int)? {
  let mut best : (Int, Int)? = None
  for i in 0..<operator_symbols.length() {
    let symbol = operator_symbols[i]
    match line.find(symbol) {
      Some(index) =>
        match best {
          None => best = Some((i, index))
          Some((best_operator_index, best_index)) =>
            if index < best_index ||
              (
                index == best_index &&
                symbol.length() > operator_symbols[best_operator_index].length()
              ) {
              best = Some((i, index))
            }
        }
      None => ()
    }
  }
  best
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
fn find_earliest_operator(
  line : String,
  operators : Array[EdgeOp],
) -> FoundEdgeOp? {
  match find_earliest_operator_indices(line, edge_operator_symbols(operators)) {
    Some((operator_index, index)) =>
      Some({ op: operators[operator_index], index })
    None => None
  }
}
