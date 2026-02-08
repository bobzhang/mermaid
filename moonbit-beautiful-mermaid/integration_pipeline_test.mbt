///|
fn option_or_zero(value : Int?) -> Int {
  match value {
    Some(found) => found
    None => 0
  }
}

///|
struct EdgeLabelRect {
  x : Int
  y : Int
  width : Int
  height : Int
}

///|
fn collect_edge_label_rects(svg : String) -> Array[EdgeLabelRect] {
  let rects : Array[EdgeLabelRect] = []
  let marker = "<rect class=\"edge-label-bg\""
  let mut offset = 0

  while offset < svg.length() {
    let remaining = (try! svg[offset:]).to_string()
    match remaining.find(marker) {
      Some(found) => {
        let start = offset + found
        let tail = (try! svg[start:]).to_string()
        match tail.find("/>") {
          Some(close_idx) => {
            let snippet = (try! tail[:close_idx + 2]).to_string()
            match
              (
                @test_support.svg_attr_int(snippet, "x"),
                @test_support.svg_attr_int(snippet, "y"),
                @test_support.svg_attr_int(snippet, "width"),
                @test_support.svg_attr_int(snippet, "height"),
              ) {
              (Some(x), Some(y), Some(width), Some(height)) =>
                rects.push(EdgeLabelRect::{ x, y, width, height })
              _ => ()
            }
            offset = start + close_idx + 2
          }
          None => break
        }
      }
      None => break
    }
  }

  rects
}

///|
fn edge_label_rects_overlap(a : EdgeLabelRect, b : EdgeLabelRect) -> Bool {
  let overlap_x = a.x < b.x + b.width && a.x + a.width > b.x
  let overlap_y = a.y < b.y + b.height && a.y + a.height > b.y
  overlap_x && overlap_y
}

///|
test "Pipeline dimensions honor direction" {
  let lr_svg = try! @beautiful_mermaid.render_mermaid("graph LR\nA --> B --> C")
  let td_svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA --> B --> C")

  let lr_width = option_or_zero(@test_support.svg_attr_int(lr_svg, "width"))
  let td_width = option_or_zero(@test_support.svg_attr_int(td_svg, "width"))
  let lr_height = option_or_zero(@test_support.svg_attr_int(lr_svg, "height"))
  let td_height = option_or_zero(@test_support.svg_attr_int(td_svg, "height"))

  assert_true(lr_width > td_width)
  assert_true(td_height > lr_height)
}

///|
test "ASCII and Unicode modes differ" {
  let ascii_options = @beautiful_mermaid.AsciiRenderOptions::{
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  }
  let unicode_options = @beautiful_mermaid.AsciiRenderOptions::{
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  }

  let input = "graph LR\nA --> B"
  let ascii_output = try! @beautiful_mermaid.render_mermaid_ascii(
    input,
    options=ascii_options,
  )
  let unicode_output = try! @beautiful_mermaid.render_mermaid_ascii(
    input,
    options=unicode_options,
  )
  assert_true(ascii_output != unicode_output)
}

///|
test "ASCII mode avoids Unicode box drawing glyphs" {
  let output = try! @beautiful_mermaid.render_mermaid_ascii(
    "graph LR\nA --> B",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: true,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )

  assert_true(!output.contains("┌"))
  assert_true(!output.contains("─"))
  assert_true(!output.contains("│"))
}

///|
test "Unicode mode emits box drawing glyphs" {
  let output = try! @beautiful_mermaid.render_mermaid_ascii(
    "graph LR\nA --> B",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: false,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )

  assert_true(
    output.contains("┌") || output.contains("─") || output.contains("│"),
  )
}

///|
test "Standalone sequence activate/deactivate lines are ignored for rendering parity" {
  let input = "sequenceDiagram\nparticipant A\nparticipant B\nactivate A\nA->>B: Work\ndeactivate A"

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options=@beautiful_mermaid.AsciiRenderOptions::{
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options=@beautiful_mermaid.AsciiRenderOptions::{
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)

  assert_true(ascii.contains("Work"))
  assert_true(unicode.contains("Work"))
  assert_true(svg.contains(">Work</text>"))

  assert_true(!ascii.contains("|||"))
  assert_true(!unicode.contains("│││"))
  assert_true(!svg.contains("class=\"sequence-activation\""))
}

///|
test "Flowchart cycle edge label pills do not overlap" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph LR\nA -->|forward| B\nB -->|back| A\nA -->|down| C",
  )

  let rects = collect_edge_label_rects(svg)
  assert_true(rects.length() >= 3)

  for i in 0..<rects.length() {
    for j in (i + 1)..<rects.length() {
      assert_true(!edge_label_rects_overlap(rects[i], rects[j]))
    }
  }
}
