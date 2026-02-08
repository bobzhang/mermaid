///|
test "trim_flow_canvas_output trims outer blank lines and shared indent" {
  let raw = "\n\n   +---+\n   | A |\n   +---+\n\n"
  assert_eq(trim_flow_canvas_output(raw), "+---+\n| A |\n+---+")
}

///|
test "trim_flow_canvas_output preserves relative indentation" {
  let raw = "\n    root\n      child\n"
  assert_eq(trim_flow_canvas_output(raw), "root\n  child")
}

///|
test "trim_flow_canvas_output returns empty for blank canvas text" {
  let raw = "\n   \n\t\n"
  assert_eq(trim_flow_canvas_output(raw), "")
}
