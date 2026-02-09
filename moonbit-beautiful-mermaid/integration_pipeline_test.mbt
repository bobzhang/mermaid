///|
fn option_or_zero(value : Int?) -> Int {
  match value {
    Some(found) => found
    None => 0
  }
}

///|
fn integration_count_occurrences(haystack : String, needle : String) -> Int {
  let parts = haystack.split(needle).to_array()
  if parts.length() == 0 {
    return 0
  }
  parts.length() - 1
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
test "SVG simple flow keeps valid svg envelope" {
  let svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA --> B")
  assert_true(svg.has_prefix("<svg "))
  assert_true(svg.has_suffix("</svg>"))
}

///|
test "SVG dimensions expand with padding option" {
  let small_options = @beautiful_mermaid.RenderOptions::{
    bg: None,
    fg: None,
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: None,
    padding: Some(10),
    node_spacing: None,
    layer_spacing: None,
    transparent: None,
  }
  let large_options = @beautiful_mermaid.RenderOptions::{
    bg: None,
    fg: None,
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: None,
    padding: Some(80),
    node_spacing: None,
    layer_spacing: None,
    transparent: None,
  }

  let small_svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA --> B",
    options=small_options,
  )
  let large_svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA --> B",
    options=large_options,
  )

  let small_width = option_or_zero(@test_support.svg_attr_int(small_svg, "width"))
  let large_width = option_or_zero(@test_support.svg_attr_int(large_svg, "width"))
  let small_height = option_or_zero(@test_support.svg_attr_int(small_svg, "height"))
  let large_height = option_or_zero(@test_support.svg_attr_int(large_svg, "height"))

  assert_true(large_width > small_width)
  assert_true(large_height > small_height)
}

///|
test "SVG renders labeled nodes for simple flow" {
  let svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA[Start] --> B[End]")
  assert_true(svg.contains(">Start</text>"))
  assert_true(svg.contains(">End</text>"))
}

///|
test "SVG renders edge labels for simple flow" {
  let svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA -->|Yes| B")
  assert_true(svg.contains(">Yes</text>"))
}

///|
test "SVG applies custom font option" {
  let options = @beautiful_mermaid.RenderOptions::{
    bg: None,
    fg: None,
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: Some("JetBrains Mono"),
    padding: None,
    node_spacing: None,
    layer_spacing: None,
    transparent: None,
  }
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA --> B",
    options~,
  )

  assert_true(svg.contains("'JetBrains Mono'"))
}

///|
test "SVG defaults to light theme colors" {
  let svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA --> B")
  assert_true(svg.contains("--bg:#FFFFFF"))
  assert_true(svg.contains("--fg:#27272A"))
}

///|
test "SVG applies explicit dark colors" {
  let options = @beautiful_mermaid.RenderOptions::{
    bg: Some("#18181B"),
    fg: Some("#FAFAFA"),
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: None,
    padding: None,
    node_spacing: None,
    layer_spacing: None,
    transparent: None,
  }
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA --> B",
    options~,
  )
  assert_true(svg.contains("--bg:#18181B"))
  assert_true(svg.contains("--fg:#FAFAFA"))
}

///|
test "SVG renders solid dotted and thick edge styles with labels" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA -->|solid| B\nB -.->|dotted| C\nC ==>|thick| D",
  )

  assert_true(svg.contains(">solid</text>"))
  assert_true(svg.contains(">dotted</text>"))
  assert_true(svg.contains(">thick</text>"))
  assert_true(svg.contains("stroke-dasharray=\"4 4\""))
}

///|
test "SVG renders subgraph labels and nodes" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nsubgraph Backend\nA[API] --> B[DB]\nend\nC[Client] --> A",
  )

  assert_true(svg.contains(">Backend</text>"))
  assert_true(svg.contains(">API</text>"))
  assert_true(svg.contains(">DB</text>"))
  assert_true(svg.contains(">Client</text>"))
}

///|
test "SVG renders complex CI pipeline diagram" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nsubgraph ci [CI Pipeline]\nA[Push Code] --> B{Tests Pass?}\nB -->|Yes| C[Build Docker]\nB -->|No| D[Fix & Retry]\nD --> A\nend\nC --> E([Deploy to Staging])\nE --> F{QA Approved?}\nF -->|Yes| G((Production))\nF -->|No| D",
  )

  assert_true(svg.contains(">CI Pipeline</text>"))
  assert_true(svg.contains(">Push Code</text>"))
  assert_true(svg.contains(">Tests Pass?</text>"))
  assert_true(svg.contains(">Yes</text>"))
  assert_true(svg.contains(">No</text>"))
  assert_true(svg.contains(">Production</text>"))
}

///|
test "SVG renders original flowchart shape set" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA[Rectangle] --> B(Rounded)\nB --> C{Diamond}\nC --> D([Stadium])\nD --> E((Circle))",
  )

  assert_true(svg.contains(">Rectangle</text>"))
  assert_true(svg.contains(">Rounded</text>"))
  assert_true(svg.contains(">Diamond</text>"))
  assert_true(svg.contains(">Stadium</text>"))
  assert_true(svg.contains(">Circle</text>"))
  assert_true(svg.contains("<polygon"))
  assert_true(svg.contains("<circle"))
}

///|
test "SVG renders subroutine shape with inner guide lines" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA[[Subroutine]] --> B",
  )
  assert_true(svg.contains(">Subroutine</text>"))
  assert_true(svg.contains("<line"))
}

///|
test "SVG renders double-circle shape with two circle elements" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA(((Important))) --> B",
  )
  assert_true(svg.contains(">Important</text>"))
  assert_true(integration_count_occurrences(svg, "<circle") >= 2)
}

///|
test "SVG renders hexagon shape as polygon" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA{{Decision}} --> B",
  )
  assert_true(svg.contains(">Decision</text>"))
  assert_true(svg.contains("<polygon"))
}

///|
test "SVG renders cylinder database shape" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA[(Database)] --> B",
  )
  assert_true(svg.contains(">Database</text>"))
  assert_true(svg.contains("<ellipse"))
}

///|
test "SVG renders asymmetric flag shape" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA>Flag Shape] --> B",
  )
  assert_true(svg.contains(">Flag Shape</text>"))
  assert_true(svg.contains("<polygon"))
}

///|
test "SVG renders trapezoid variants" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA[/Wider Bottom\\\\] --> B[\\\\Wider Top/]",
  )
  assert_true(svg.contains("Wider Bottom"))
  assert_true(svg.contains("Wider Top"))
  assert_true(svg.contains("<polygon"))
}

///|
test "SVG no-arrow edges omit marker-end" {
  let svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA --- B")
  assert_true(svg.contains("<polyline"))
  assert_true(!svg.contains("marker-end="))
}

///|
test "SVG bidirectional edges include start and end arrowheads" {
  let svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA <--> B")
  assert_true(svg.contains("marker-end=\"url(#arrowhead)\""))
  assert_true(svg.contains("marker-start=\"url(#arrowhead-start)\""))
}

///|
test "SVG parallel ampersand links emit one edge per source" {
  let svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA & B --> C")

  assert_true(svg.contains(">A</text>"))
  assert_true(svg.contains(">B</text>"))
  assert_true(svg.contains(">C</text>"))
  assert_true(integration_count_occurrences(svg, "<polyline") >= 2)
}

///|
test "SVG applies inline style overrides for nodes" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA[Red Node] --> B\nstyle A fill:#ff0000,stroke:#cc0000",
  )
  assert_true(svg.contains("fill=\"#ff0000\""))
  assert_true(svg.contains("stroke=\"#cc0000\""))
}

///|
test "SVG renders basic state diagram labels" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "stateDiagram-v2\n[*] --> Idle\nIdle --> Active : start\nActive --> Done",
  )

  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("</svg>"))
  assert_true(svg.contains(">Idle</text>"))
  assert_true(svg.contains(">Active</text>"))
  assert_true(svg.contains(">Done</text>"))
  assert_true(svg.contains(">start</text>"))
}

///|
test "SVG renders state start pseudostate as filled circle" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "stateDiagram-v2\n[*] --> Ready",
  )
  assert_true(svg.contains("stroke=\"none\""))
  assert_true(svg.contains("<circle"))
}

///|
test "SVG renders state end pseudostate as bullseye" {
  let svg = try! @beautiful_mermaid.render_mermaid("stateDiagram-v2\nDone --> [*]")
  assert_true(integration_count_occurrences(svg, "<circle") >= 2)
}

///|
test "SVG renders composite state with inner nodes" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "stateDiagram-v2\nstate Processing {\n  parse --> validate\n  validate --> execute\n}\n[*] --> Processing",
  )

  assert_true(svg.contains(">Processing</text>"))
  assert_true(svg.contains(">parse</text>"))
  assert_true(svg.contains(">validate</text>"))
  assert_true(svg.contains(">execute</text>"))
}

///|
test "SVG renders full state lifecycle with labels" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "stateDiagram-v2\n[*] --> Idle\nIdle --> Processing : submit\nstate Processing {\n  parse --> validate\n  validate --> execute\n}\nProcessing --> Complete : done\nComplete --> [*]",
  )

  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("</svg>"))
  assert_true(svg.contains(">Idle</text>"))
  assert_true(svg.contains(">Complete</text>"))
  assert_true(svg.contains(">Processing</text>"))
  assert_true(svg.contains(">submit</text>"))
  assert_true(svg.contains(">done</text>"))
}

///|
test "SVG does not duplicate composite state labels" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "stateDiagram-v2\n[*] --> Idle\nIdle --> Processing : submit\nstate Processing {\n  parse --> validate\n  validate --> execute\n}\nProcessing --> Complete : done\nComplete --> [*]",
  )
  assert_eq(integration_count_occurrences(svg, ">Processing</text>"), 1)
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
