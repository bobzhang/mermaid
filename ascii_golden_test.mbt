///|
test "ASCII golden gate cases" {
  for case_data in @test_support.gate_cases() {
    let options = @beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: true,
      padding_x: case_data.padding_x,
      padding_y: case_data.padding_y,
      box_border_padding: 1,
    }
    let actual = @beautiful_mermaid.render_mermaid_ascii(
      case_data.input,
      options~,
    )
    let normalized_actual = ts_normalize_whitespace(actual)
    let normalized_expected = ts_normalize_whitespace(case_data.expected_ascii)
    assert_eq(normalized_actual, normalized_expected)
  }
}
