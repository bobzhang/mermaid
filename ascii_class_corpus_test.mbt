///|
test "ASCII class corpus parity" {
  for
    case_data in ts_supported_ascii_cases().filter(case_data => {
      case_data.header == "classdiagram"
    }) {
    let options = @model.AsciiRenderOptions::{
      use_ascii: true,
      padding_x: case_data.padding_x,
      padding_y: case_data.padding_y,
      box_border_padding: 1,
    }
    let actual = @beautiful_mermaid.render_mermaid_ascii(
      case_data.input,
      options~,
    )
    guard case_data.expected_ascii is Some(expected) else {
      fail("missing expected ascii for \{case_data.name}")
    }
    assert_eq(
      ts_normalize_whitespace(actual),
      ts_normalize_whitespace(expected),
    )
  }
}

///|
test "Unicode class corpus parity" {
  for
    case_data in ts_supported_unicode_cases().filter(case_data => {
      case_data.header == "classdiagram"
    }) {
    let options = @model.AsciiRenderOptions::{
      use_ascii: false,
      padding_x: case_data.padding_x,
      padding_y: case_data.padding_y,
      box_border_padding: 1,
    }
    let actual = @beautiful_mermaid.render_mermaid_ascii(
      case_data.input,
      options~,
    )
    guard case_data.expected_unicode is Some(expected) else {
      fail("missing expected unicode for \{case_data.name}")
    }
    assert_eq(
      ts_normalize_whitespace(actual),
      ts_normalize_whitespace(expected),
    )
  }
}
