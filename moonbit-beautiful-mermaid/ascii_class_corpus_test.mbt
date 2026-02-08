///|
test "ASCII class corpus parity" {
  for
    case_data in @test_support.supported_ascii_cases().filter(case_data => {
      case_data.header == "classdiagram"
    }) {
    let options = @beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: true,
      padding_x: case_data.padding_x,
      padding_y: case_data.padding_y,
      box_border_padding: 1,
    }
    let actual = try! @beautiful_mermaid.render_mermaid_ascii(
      case_data.input,
      options~,
    )
    match case_data.expected_ascii {
      Some(expected) =>
        assert_eq(
          @test_support.normalize_whitespace(actual),
          @test_support.normalize_whitespace(expected),
        )
      None => fail("missing expected ascii for \{case_data.name}")
    }
  }
}

///|
test "Unicode class corpus parity" {
  for
    case_data in @test_support.supported_unicode_cases().filter(case_data => {
      case_data.header == "classdiagram"
    }) {
    let options = @beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: false,
      padding_x: case_data.padding_x,
      padding_y: case_data.padding_y,
      box_border_padding: 1,
    }
    let actual = try! @beautiful_mermaid.render_mermaid_ascii(
      case_data.input,
      options~,
    )
    match case_data.expected_unicode {
      Some(expected) =>
        assert_eq(
          @test_support.normalize_whitespace(actual),
          @test_support.normalize_whitespace(expected),
        )
      None => fail("missing expected unicode for \{case_data.name}")
    }
  }
}
