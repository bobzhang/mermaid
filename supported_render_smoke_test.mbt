///|
test "Render smoke for all supported corpus cases" (it : @test.Test) {
  let svg_sections : Array[String] = []
  for case_data in @test_support.supported_cases() {
    let svg = try! @beautiful_mermaid.render_mermaid(case_data.input)
    if !svg.has_prefix("<svg ") || !svg.has_suffix("</svg>") {
      fail("invalid svg envelope for \{case_data.name}")
    }
    let section = (
        $|<section><h2>\{case_data.name}</h2>
        $|\{svg}
        $|</section>
        $|
      )
      .trim_end()
      .to_string()
    svg_sections.push(section)

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

  let gallery_body = svg_sections.join("\n<hr/>\n")
  let gallery = (
      $|<!doctype html><html><head><meta charset="utf-8" /><title>Supported Render Smoke SVG Gallery</title></head><body>
      $|\{gallery_body}
      $|</body></html>
      $|
    )
    .trim_end()
    .to_string()
  it.write(gallery)
  it.snapshot(filename="supported_render_smoke_gallery.html")
}
