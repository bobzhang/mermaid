///|
test "Render smoke for all supported corpus cases" {
  for case_data in @test_support.supported_cases() {
    let svg = try! @beautiful_mermaid.render_mermaid(case_data.input)
    if !svg.has_prefix("<svg ") || !svg.has_suffix("</svg>") {
      fail("invalid svg envelope for \{case_data.name}")
    }

    let ascii_options = @beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: true,
      padding_x: case_data.padding_x,
      padding_y: case_data.padding_y,
      box_border_padding: 1,
    }
    let unicode_options = @beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: false,
      padding_x: case_data.padding_x,
      padding_y: case_data.padding_y,
      box_border_padding: 1,
    }

    let ascii = try! @beautiful_mermaid.render_mermaid_ascii(
      case_data.input,
      options=ascii_options,
    )
    let unicode = try! @beautiful_mermaid.render_mermaid_ascii(
      case_data.input,
      options=unicode_options,
    )

    if @test_support.normalize_whitespace(ascii) == "" {
      fail("empty ascii output for \{case_data.name}")
    }
    if @test_support.normalize_whitespace(unicode) == "" {
      fail("empty unicode output for \{case_data.name}")
    }
  }
}
