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
  s.trim().to_string()
}

///|
fn find_earliest_operator(
  line : String,
  operators : Array[EdgeOp],
) -> FoundEdgeOp? {
  let mut best : FoundEdgeOp? = None
  for op in operators {
    match line.find(op.symbol) {
      Some(index) =>
        match best {
          None => best = Some({ op, index })
          Some(current_best) =>
            if index < current_best.index ||
              (
                index == current_best.index &&
                op.symbol.length() > current_best.op.symbol.length()
              ) {
              best = Some({ op, index })
            }
        }
      None => ()
    }
  }
  best
}
