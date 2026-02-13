///|
fn supported_case_by_name(name : String) -> @test_support.CorpusCase raise {
  let mut matched : @test_support.CorpusCase? = None
  for case_data in @test_support.supported_cases() {
    if case_data.name == name {
      matched = Some(case_data)
    }
  }
  match matched {
    Some(case_data) => case_data
    None => fail("missing supported case \{name}")
  }
}

///|
fn snapshot_supported_case_svg(
  it : @test.Test,
  case_name : String,
  filename : String,
) -> Unit raise {
  let case_data = supported_case_by_name(case_name)
  let svg = @beautiful_mermaid.render_mermaid(case_data.input)
  it.write(svg)
  it.snapshot(filename~)

  assert_true(svg.has_prefix("<svg "))
  assert_true(svg.has_suffix("</svg>"))
  assert_true(@test_support.contains_all(svg, case_data.expected_svg_fragments))
}

///|
test "Supported flowchart sample emits stable SVG snapshot" (it : @test.Test) {
  snapshot_supported_case_svg(
    it, "flowchart_tb_simple", "supported_case_flowchart_tb_simple.svg",
  )
}

///|
test "Supported nested-subgraph sample emits stable SVG snapshot" (
  it : @test.Test,
) {
  snapshot_supported_case_svg(
    it, "subgraph_complex_nested", "supported_case_subgraph_complex_nested.svg",
  )
}

///|
test "Supported sequence sample emits stable SVG snapshot" (it : @test.Test) {
  snapshot_supported_case_svg(
    it, "seq_multiple_messages", "supported_case_seq_multiple_messages.svg",
  )
}

///|
test "Supported class sample emits stable SVG snapshot" (it : @test.Test) {
  snapshot_supported_case_svg(
    it, "cls_all_relationships", "supported_case_cls_all_relationships.svg",
  )
}

///|
test "Supported ER sample emits stable SVG snapshot" (it : @test.Test) {
  snapshot_supported_case_svg(
    it, "er_identifying", "supported_case_er_identifying.svg",
  )
}
