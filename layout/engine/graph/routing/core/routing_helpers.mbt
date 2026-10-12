///|
fn option_int_or(value : Int32?, fallback : Int32) -> Int32 {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
fn int_abs(value : Int32) -> Int32 {
  if value < 0 {
    -value
  } else {
    value
  }
}
