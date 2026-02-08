///|
test "Public API smoke test" {
  let svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA --> B")
  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("</svg>"))

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(
    "graph TD\nA --> B",
    options={
      use_ascii: true,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(ascii.contains("[A]"))
  assert_true(ascii.contains("[B]"))
}
