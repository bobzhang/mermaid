// ---------------------------------------------------------------------------
// Regression tests for counterexamples found by the properties above.
// ---------------------------------------------------------------------------

///|
test "regression: control characters in labels keep the SVG well-formed" {
  // Found by the token-soup property: a NUL in a label was copied verbatim
  // into the SVG, which no XML parser accepts.
  let svg = @beautiful_mermaid.render_mermaid(
    "graph TD\nA[x\u{0}y\u{1}z] --> B",
  )
  assert_false(svg.contains("\u{0}"))
  assert_false(svg.contains("\u{1}"))
  assert_true(svg.contains(">x\u{FFFD}y\u{FFFD}z</text>"))
}
