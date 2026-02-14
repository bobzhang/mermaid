///|
test "Render smoke for all supported corpus cases" (it : @test.Test) {
  let svg_sections : Array[String] = []
  for case_data in ts_supported_cases() {
    let svg = @beautiful_mermaid.render_mermaid(case_data.input)
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

    let ascii = @beautiful_mermaid.render_mermaid_ascii(
      case_data.input,
      options=ascii_options,
    )
    let unicode = @beautiful_mermaid.render_mermaid_ascii(
      case_data.input,
      options=unicode_options,
    )

    if ts_normalize_whitespace(ascii) == "" {
      fail("empty ascii output for \{case_data.name}")
    }
    if ts_normalize_whitespace(unicode) == "" {
      fail("empty unicode output for \{case_data.name}")
    }
  }

  let gallery_body = svg_sections.join(
    (
      #|
      #|<hr/>
      #|
    ),
  )
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
