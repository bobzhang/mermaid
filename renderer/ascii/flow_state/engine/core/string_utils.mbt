///|
fn option_int_or(value : Int32?, fallback : Int32) -> Int32 {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
fn midpoint(a : Point, b : Point) -> Point {
  { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, }
}
