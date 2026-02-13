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
                rects.push({ x, y, width, height })
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
fn snapshot_svg(it : @test.Test, filename : String, svg : String) -> Unit raise {
  it.write(svg)
  it.snapshot(filename~)
}

///|
fn integration_input_graph_lr_abc_chain() -> String {
  (
    #|graph LR
    #|A --> B --> C
  )
}

///|
fn integration_input_graph_td_abc_chain() -> String {
  (
    #|graph TD
    #|A --> B --> C
  )
}

///|
fn integration_input_graph_td_ab() -> String {
  (
    #|graph TD
    #|A --> B
  )
}

///|
fn integration_input_graph_td_start_end() -> String {
  (
    #|graph TD
    #|A[Start] --> B[End]
  )
}

///|
fn integration_input_graph_td_yes_label() -> String {
  (
    #|graph TD
    #|A -->|Yes| B
  )
}

///|
fn integration_input_graph_lr_ab() -> String {
  (
    #|graph LR
    #|A --> B
  )
}

///|
fn integration_input_state_start_ready() -> String {
  (
    #|stateDiagram-v2
    #|[*] --> Ready
  )
}

///|
fn integration_input_state_done_end() -> String {
  (
    #|stateDiagram-v2
    #|Done --> [*]
  )
}

///|
test "Pipeline dimensions honor direction" (it : @test.Test) {
  let lr_svg = try! @beautiful_mermaid.render_mermaid(
    integration_input_graph_lr_abc_chain(),
  )
  let td_svg = try! @beautiful_mermaid.render_mermaid(
    integration_input_graph_td_abc_chain(),
  )

  snapshot_svg(it, "integration_pipeline_direction_lr.svg", lr_svg)

  let lr_width = option_or_zero(@test_support.svg_attr_int(lr_svg, "width"))
  let td_width = option_or_zero(@test_support.svg_attr_int(td_svg, "width"))
  let lr_height = option_or_zero(@test_support.svg_attr_int(lr_svg, "height"))
  let td_height = option_or_zero(@test_support.svg_attr_int(td_svg, "height"))

  assert_true(lr_width > td_width)
  assert_true(td_height > lr_height)
}

///|
test "Flowchart BT direction renders across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|graph BT
    #|A[Start] --> B[Middle] --> C[End]

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_flowchart_bt.svg", svg)

  assert_true(ascii.contains("Start"))
  assert_true(ascii.contains("Middle"))
  assert_true(ascii.contains("End"))
  assert_true(unicode.contains("Start"))
  assert_true(unicode.contains("Middle"))
  assert_true(unicode.contains("End"))
  assert_true(svg.contains(">Start</text>"))
  assert_true(svg.contains(">Middle</text>"))
  assert_true(svg.contains(">End</text>"))
}

///|
test "Flowchart RL direction renders across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|graph RL
    #|A[Origin] --> B[Pivot] --> C[Target]

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_flowchart_rl.svg", svg)

  assert_true(ascii.contains("Origin"))
  assert_true(ascii.contains("Pivot"))
  assert_true(ascii.contains("Target"))
  assert_true(unicode.contains("Origin"))
  assert_true(unicode.contains("Pivot"))
  assert_true(unicode.contains("Target"))
  assert_true(svg.contains(">Origin</text>"))
  assert_true(svg.contains(">Pivot</text>"))
  assert_true(svg.contains(">Target</text>"))
}

///|
test "SVG simple flow keeps valid svg envelope" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    integration_input_graph_td_ab(),
  )
  snapshot_svg(it, "integration_flowchart_simple.svg", svg)
  assert_true(svg.has_prefix("<svg "))
  assert_true(svg.has_suffix("</svg>"))
}

///|
test "SVG dimensions expand with padding option" (it : @test.Test) {
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
    integration_input_graph_td_ab(),
    options=small_options,
  )
  let large_svg = try! @beautiful_mermaid.render_mermaid(
    integration_input_graph_td_ab(),
    options=large_options,
  )
  snapshot_svg(it, "integration_flowchart_padding_small.svg", small_svg)

  let small_width = option_or_zero(
    @test_support.svg_attr_int(small_svg, "width"),
  )
  let large_width = option_or_zero(
    @test_support.svg_attr_int(large_svg, "width"),
  )
  let small_height = option_or_zero(
    @test_support.svg_attr_int(small_svg, "height"),
  )
  let large_height = option_or_zero(
    @test_support.svg_attr_int(large_svg, "height"),
  )

  assert_true(large_width > small_width)
  assert_true(large_height > small_height)
}

///|
test "SVG renders labeled nodes for simple flow" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    integration_input_graph_td_start_end(),
  )
  snapshot_svg(it, "integration_flowchart_labeled_nodes.svg", svg)
  assert_true(svg.contains(">Start</text>"))
  assert_true(svg.contains(">End</text>"))
}

///|
test "SVG renders edge labels for simple flow" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    integration_input_graph_td_yes_label(),
  )
  snapshot_svg(it, "integration_flowchart_edge_label.svg", svg)
  assert_true(svg.contains(">Yes</text>"))
}

///|
test "Flowchart chained labeled edges render across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|graph LR
    #|A[One] -->|first| B[Two] -->|second| C[Three] -->|third| D[Four]

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_flowchart_chained_labels.svg", svg)

  assert_true(ascii.contains("One"))
  assert_true(ascii.contains("Four"))
  assert_true(ascii.contains("first"))
  assert_true(ascii.contains("second"))
  assert_true(ascii.contains("third"))
  assert_true(unicode.contains("One"))
  assert_true(unicode.contains("Four"))
  assert_true(unicode.contains("first"))
  assert_true(unicode.contains("second"))
  assert_true(unicode.contains("third"))
  assert_true(svg.contains(">One</text>"))
  assert_true(svg.contains(">Four</text>"))
  assert_true(svg.contains(">first</text>"))
  assert_true(svg.contains(">second</text>"))
  assert_true(svg.contains(">third</text>"))
}

///|
test "SVG applies custom font option" (it : @test.Test) {
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
    integration_input_graph_td_ab(),
    options~,
  )
  snapshot_svg(it, "integration_flowchart_custom_font.svg", svg)

  assert_true(svg.contains("'JetBrains Mono'"))
}

///|
test "SVG defaults to light theme colors" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    integration_input_graph_td_ab(),
  )
  snapshot_svg(it, "integration_flowchart_default_light.svg", svg)
  assert_true(svg.contains("--bg:#FFFFFF"))
  assert_true(svg.contains("--fg:#27272A"))
}

///|
test "SVG applies explicit dark colors" (it : @test.Test) {
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
    integration_input_graph_td_ab(),
    options~,
  )
  snapshot_svg(it, "integration_flowchart_explicit_dark.svg", svg)
  assert_true(svg.contains("--bg:#18181B"))
  assert_true(svg.contains("--fg:#FAFAFA"))
}

///|
test "SVG renders solid dotted and thick edge styles with labels" (
  it : @test.Test,
) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|A -->|solid| B
      #|B -.->|dotted| C
      #|C ==>|thick| D
    ),
  )
  snapshot_svg(it, "integration_flowchart_edge_styles.svg", svg)

  assert_true(svg.contains(">solid</text>"))
  assert_true(svg.contains(">dotted</text>"))
  assert_true(svg.contains(">thick</text>"))
  assert_true(svg.contains("stroke-dasharray=\"4 4\""))
}

///|
test "SVG renders subgraph labels and nodes" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|subgraph Backend
      #|A[API] --> B[DB]
      #|end
      #|C[Client] --> A
    ),
  )
  snapshot_svg(it, "integration_flowchart_subgraph_labels.svg", svg)

  assert_true(svg.contains(">Backend</text>"))
  assert_true(svg.contains(">API</text>"))
  assert_true(svg.contains(">DB</text>"))
  assert_true(svg.contains(">Client</text>"))
}

///|
test "Subgraph direction override renders across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|graph TD
    #|subgraph FE [Frontend]
    #|  direction LR
    #|  A[Web] --> B[API]
    #|end
    #|subgraph BE [Backend]
    #|  C[Service] --> D[(DB)]
    #|end
    #|B --> C

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_flowchart_subgraph_direction_override.svg", svg)

  assert_true(ascii.contains("Frontend"))
  assert_true(ascii.contains("Backend"))
  assert_true(ascii.contains("Web"))
  assert_true(ascii.contains("Service"))
  assert_true(unicode.contains("Frontend"))
  assert_true(unicode.contains("Backend"))
  assert_true(unicode.contains("Web"))
  assert_true(unicode.contains("Service"))
  assert_true(svg.contains(">Frontend</text>"))
  assert_true(svg.contains(">Backend</text>"))
  assert_true(svg.contains(">Web</text>"))
  assert_true(svg.contains(">API</text>"))
  assert_true(svg.contains(">Service</text>"))
  assert_true(svg.contains(">DB</text>"))
}

///|
test "SVG renders complex CI pipeline diagram" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|subgraph ci [CI Pipeline]
      #|A[Push Code] --> B{Tests Pass?}
      #|B -->|Yes| C[Build Docker]
      #|B -->|No| D[Fix & Retry]
      #|D --> A
      #|end
      #|C --> E([Deploy to Staging])
      #|E --> F{QA Approved?}
      #|F -->|Yes| G((Production))
      #|F -->|No| D
    ),
  )
  snapshot_svg(it, "integration_flowchart_ci_pipeline.svg", svg)

  assert_true(svg.contains(">CI Pipeline</text>"))
  assert_true(svg.contains(">Push Code</text>"))
  assert_true(svg.contains(">Tests Pass?</text>"))
  assert_true(svg.contains(">Yes</text>"))
  assert_true(svg.contains(">No</text>"))
  assert_true(svg.contains(">Production</text>"))
}

///|
test "SVG renders original flowchart shape set" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|A[Rectangle] --> B(Rounded)
      #|B --> C{Diamond}
      #|C --> D([Stadium])
      #|D --> E((Circle))
    ),
  )
  snapshot_svg(it, "integration_flowchart_original_shapes.svg", svg)

  assert_true(svg.contains(">Rectangle</text>"))
  assert_true(svg.contains(">Rounded</text>"))
  assert_true(svg.contains(">Diamond</text>"))
  assert_true(svg.contains(">Stadium</text>"))
  assert_true(svg.contains(">Circle</text>"))
  assert_true(svg.contains("<polygon"))
  assert_true(svg.contains("<circle"))
}

///|
test "SVG renders subroutine shape with inner guide lines" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|A[[Subroutine]] --> B
    ),
  )
  snapshot_svg(it, "integration_flowchart_subroutine.svg", svg)
  assert_true(svg.contains(">Subroutine</text>"))
  assert_true(svg.contains("<line"))
}

///|
test "SVG renders double-circle shape with two circle elements" (
  it : @test.Test,
) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|A(((Important))) --> B
    ),
  )
  snapshot_svg(it, "integration_flowchart_double_circle.svg", svg)
  assert_true(svg.contains(">Important</text>"))
  assert_true(integration_count_occurrences(svg, "<circle") >= 2)
}

///|
test "SVG renders hexagon shape as polygon" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|A{{Decision}} --> B
    ),
  )
  snapshot_svg(it, "integration_flowchart_hexagon.svg", svg)
  assert_true(svg.contains(">Decision</text>"))
  assert_true(svg.contains("<polygon"))
}

///|
test "SVG renders cylinder database shape" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|A[(Database)] --> B
    ),
  )
  snapshot_svg(it, "integration_flowchart_cylinder.svg", svg)
  assert_true(svg.contains(">Database</text>"))
  assert_true(svg.contains("<ellipse"))
}

///|
test "SVG renders asymmetric flag shape" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|A>Flag Shape] --> B
    ),
  )
  snapshot_svg(it, "integration_flowchart_asymmetric.svg", svg)
  assert_true(svg.contains(">Flag Shape</text>"))
  assert_true(svg.contains("<polygon"))
}

///|
test "SVG renders trapezoid variants" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA[/Wider Bottom\\\\] --> B[\\\\Wider Top/]",
  )
  snapshot_svg(it, "integration_flowchart_trapezoid_variants.svg", svg)
  assert_true(svg.contains("Wider Bottom"))
  assert_true(svg.contains("Wider Top"))
  assert_true(svg.contains("<polygon"))
}

///|
test "SVG no-arrow edges omit marker-end" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|A --- B
    ),
  )
  snapshot_svg(it, "integration_flowchart_no_arrow_svg.svg", svg)
  assert_true(svg.contains("<polyline"))
  assert_true(!svg.contains("marker-end="))
}

///|
test "Flowchart no-arrow edges render across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|graph TD
    #|A[Client] --- B[Cache] --- C[Backend]

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_flowchart_no_arrow_cross_mode.svg", svg)

  assert_true(ascii.contains("Client"))
  assert_true(ascii.contains("Cache"))
  assert_true(ascii.contains("Backend"))
  assert_true(unicode.contains("Client"))
  assert_true(unicode.contains("Cache"))
  assert_true(unicode.contains("Backend"))
  assert_true(svg.contains(">Client</text>"))
  assert_true(svg.contains(">Cache</text>"))
  assert_true(svg.contains(">Backend</text>"))
  assert_true(!svg.contains("marker-end=\"url(#arrowhead)\""))
}

///|
test "SVG bidirectional edges include start and end arrowheads" (
  it : @test.Test,
) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|A <--> B
    ),
  )
  snapshot_svg(it, "integration_flowchart_bidirectional_svg.svg", svg)
  assert_true(svg.contains("marker-end=\"url(#arrowhead)\""))
  assert_true(svg.contains("marker-start=\"url(#arrowhead-start)\""))
}

///|
test "Flowchart bidirectional edges render across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|graph TD
    #|A[North] <--> B[South]

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_flowchart_bidirectional_cross_mode.svg", svg)

  assert_true(ascii.contains("North"))
  assert_true(ascii.contains("South"))
  assert_true(unicode.contains("North"))
  assert_true(unicode.contains("South"))
  assert_true(svg.contains(">North</text>"))
  assert_true(svg.contains(">South</text>"))
  assert_true(svg.contains("marker-end=\"url(#arrowhead)\""))
  assert_true(svg.contains("marker-start=\"url(#arrowhead-start)\""))
}

///|
test "SVG parallel ampersand links emit one edge per source" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|A & B --> C
    ),
  )
  snapshot_svg(it, "integration_flowchart_parallel_amp.svg", svg)

  assert_true(svg.contains(">A</text>"))
  assert_true(svg.contains(">B</text>"))
  assert_true(svg.contains(">C</text>"))
  assert_true(integration_count_occurrences(svg, "<polyline") >= 2)
}

///|
test "Flowchart ampersand fan-in renders across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|graph LR
    #|A[Web] & B[Mobile] --> C[API]
    #|C --> D[(Database)]

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_flowchart_amp_fan_in.svg", svg)

  assert_true(ascii.contains("Web"))
  assert_true(ascii.contains("Mobile"))
  assert_true(ascii.contains("API"))
  assert_true(ascii.contains("Database"))
  assert_true(unicode.contains("Web"))
  assert_true(unicode.contains("Mobile"))
  assert_true(unicode.contains("API"))
  assert_true(unicode.contains("Database"))
  assert_true(svg.contains(">Web</text>"))
  assert_true(svg.contains(">Mobile</text>"))
  assert_true(svg.contains(">API</text>"))
  assert_true(svg.contains(">Database</text>"))
  assert_true(integration_count_occurrences(svg, "<polyline") >= 3)
}

///|
test "Flowchart nested subgraphs render across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|graph TD
    #|subgraph Outer
    #|  subgraph Inner
    #|    A[API] --> B[DB]
    #|  end
    #|end
    #|B --> C[Client]

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_flowchart_nested_subgraphs.svg", svg)

  assert_true(ascii.contains("Outer"))
  assert_true(ascii.contains("Inner"))
  assert_true(ascii.contains("API"))
  assert_true(ascii.contains("DB"))
  assert_true(ascii.contains("Client"))
  assert_true(unicode.contains("Outer"))
  assert_true(unicode.contains("Inner"))
  assert_true(unicode.contains("API"))
  assert_true(unicode.contains("DB"))
  assert_true(unicode.contains("Client"))
  assert_true(svg.contains(">Outer</text>"))
  assert_true(svg.contains(">Inner</text>"))
  assert_true(svg.contains(">API</text>"))
  assert_true(svg.contains(">DB</text>"))
  assert_true(svg.contains(">Client</text>"))
}

///|
test "SVG applies inline style overrides for nodes" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|A[Red Node] --> B
      #|style A fill:#ff0000,stroke:#cc0000
    ),
  )
  snapshot_svg(it, "integration_flowchart_inline_style_svg.svg", svg)
  assert_true(svg.contains("fill=\"#ff0000\""))
  assert_true(svg.contains("stroke=\"#cc0000\""))
}

///|
test "Flowchart inline style overrides keep text parity and affect SVG" (
  it : @test.Test,
) {
  let input =
    #|graph TD
    #|A[Red Node] --> B[Blue Node]
    #|style A fill:#ff0000,stroke:#cc0000
    #|style B fill:#0000ff,stroke:#0000cc

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_flowchart_inline_style_cross_mode.svg", svg)

  assert_true(ascii.contains("Red Node"))
  assert_true(ascii.contains("Blue Node"))
  assert_true(unicode.contains("Red Node"))
  assert_true(unicode.contains("Blue Node"))
  assert_true(svg.contains(">Red Node</text>"))
  assert_true(svg.contains(">Blue Node</text>"))
  assert_true(svg.contains("fill=\"#ff0000\""))
  assert_true(svg.contains("stroke=\"#cc0000\""))
  assert_true(svg.contains("fill=\"#0000ff\""))
  assert_true(svg.contains("stroke=\"#0000cc\""))
}

///|
test "Flowchart classDef shorthand renders across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|graph TD
    #|A[Start]:::entry --> B[End]
    #|classDef entry fill:#f9f,stroke:#333,color:#111

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_flowchart_classdef_shorthand.svg", svg)

  assert_true(ascii.contains("Start"))
  assert_true(ascii.contains("End"))
  assert_true(unicode.contains("Start"))
  assert_true(unicode.contains("End"))
  assert_true(svg.contains(">Start</text>"))
  assert_true(svg.contains(">End</text>"))
  assert_true(svg.contains("fill=\"#f9f\""))
  assert_true(svg.contains("stroke=\"#333\""))
}

///|
test "SVG renders basic state diagram labels" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|stateDiagram-v2
      #|[*] --> Idle
      #|Idle --> Active : start
      #|Active --> Done
    ),
  )
  snapshot_svg(it, "integration_state_basic.svg", svg)

  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("</svg>"))
  assert_true(svg.contains(">Idle</text>"))
  assert_true(svg.contains(">Active</text>"))
  assert_true(svg.contains(">Done</text>"))
  assert_true(svg.contains(">start</text>"))
}

///|
test "SVG renders state start pseudostate as filled circle" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    integration_input_state_start_ready(),
  )
  snapshot_svg(it, "integration_state_start_pseudostate.svg", svg)
  assert_true(svg.contains("stroke=\"none\""))
  assert_true(svg.contains("<circle"))
}

///|
test "SVG renders state end pseudostate as bullseye" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    integration_input_state_done_end(),
  )
  snapshot_svg(it, "integration_state_end_pseudostate.svg", svg)
  assert_true(integration_count_occurrences(svg, "<circle") >= 2)
}

///|
test "State multiple pseudostates render across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|stateDiagram-v2
    #|[*] --> A
    #|[*] --> B
    #|A --> [*]
    #|B --> [*]

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_state_multiple_pseudostates.svg", svg)

  assert_true(ascii.contains("A"))
  assert_true(ascii.contains("B"))
  assert_true(unicode.contains("A"))
  assert_true(unicode.contains("B"))
  assert_true(svg.contains(">A</text>"))
  assert_true(svg.contains(">B</text>"))
  assert_true(integration_count_occurrences(svg, "<circle") >= 4)
}

///|
test "SVG renders composite state with inner nodes" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|stateDiagram-v2
      #|state Processing {
      #|  parse --> validate
      #|  validate --> execute
      #|}
      #|[*] --> Processing
    ),
  )
  snapshot_svg(it, "integration_state_composite.svg", svg)

  assert_true(svg.contains(">Processing</text>"))
  assert_true(svg.contains(">parse</text>"))
  assert_true(svg.contains(">validate</text>"))
  assert_true(svg.contains(">execute</text>"))
}

///|
test "SVG renders full state lifecycle with labels" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|stateDiagram-v2
      #|[*] --> Idle
      #|Idle --> Processing : submit
      #|state Processing {
      #|  parse --> validate
      #|  validate --> execute
      #|}
      #|Processing --> Complete : done
      #|Complete --> [*]
    ),
  )
  snapshot_svg(it, "integration_state_full_lifecycle.svg", svg)

  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("</svg>"))
  assert_true(svg.contains(">Idle</text>"))
  assert_true(svg.contains(">Complete</text>"))
  assert_true(svg.contains(">Processing</text>"))
  assert_true(svg.contains(">submit</text>"))
  assert_true(svg.contains(">done</text>"))
}

///|
test "State description lines render across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|stateDiagram-v2
    #|s1 : Idle State
    #|s1 --> s2 : proceed

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_state_description_lines.svg", svg)

  assert_true(ascii.contains("Idle State"))
  assert_true(ascii.contains("proceed"))
  assert_true(unicode.contains("Idle State"))
  assert_true(unicode.contains("proceed"))
  assert_true(svg.contains(">Idle State</text>"))
  assert_true(svg.contains(">proceed</text>"))
}

///|
test "State direction LR renders across text and SVG modes" (it : @test.Test) {
  let input =
    #|stateDiagram-v2
    #|direction LR
    #|Idle --> Active
    #|Active --> Done

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_state_direction_lr.svg", svg)

  assert_true(ascii.contains("Idle"))
  assert_true(ascii.contains("Active"))
  assert_true(ascii.contains("Done"))
  assert_true(unicode.contains("Idle"))
  assert_true(unicode.contains("Active"))
  assert_true(unicode.contains("Done"))
  assert_true(svg.contains(">Idle</text>"))
  assert_true(svg.contains(">Active</text>"))
  assert_true(svg.contains(">Done</text>"))
}

///|
test "State transition labels render across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|stateDiagram-v2
    #|Idle --> Active : start
    #|Active --> Busy : process
    #|Busy --> Done : finish

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_state_transition_labels.svg", svg)

  assert_true(ascii.contains("Idle"))
  assert_true(ascii.contains("Busy"))
  assert_true(ascii.contains("Done"))
  assert_true(ascii.contains("start"))
  assert_true(ascii.contains("process"))
  assert_true(ascii.contains("finish"))
  assert_true(unicode.contains("Idle"))
  assert_true(unicode.contains("Busy"))
  assert_true(unicode.contains("Done"))
  assert_true(unicode.contains("start"))
  assert_true(unicode.contains("process"))
  assert_true(unicode.contains("finish"))
  assert_true(svg.contains(">Idle</text>"))
  assert_true(svg.contains(">Busy</text>"))
  assert_true(svg.contains(">Done</text>"))
  assert_true(svg.contains(">start</text>"))
  assert_true(svg.contains(">process</text>"))
  assert_true(svg.contains(">finish</text>"))
}

///|
test "State composite direction override renders across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|stateDiagram-v2
    #|[*] --> Processing
    #|state Processing {
    #|  direction LR
    #|  parse --> validate
    #|  validate --> execute
    #|}
    #|Processing --> Done

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_state_composite_direction.svg", svg)

  assert_true(ascii.contains("Processing"))
  assert_true(ascii.contains("parse"))
  assert_true(ascii.contains("validate"))
  assert_true(ascii.contains("execute"))
  assert_true(ascii.contains("Done"))
  assert_true(unicode.contains("Processing"))
  assert_true(unicode.contains("parse"))
  assert_true(unicode.contains("validate"))
  assert_true(unicode.contains("execute"))
  assert_true(unicode.contains("Done"))
  assert_true(svg.contains(">Processing</text>"))
  assert_true(svg.contains(">parse</text>"))
  assert_true(svg.contains(">validate</text>"))
  assert_true(svg.contains(">execute</text>"))
  assert_true(svg.contains(">Done</text>"))
}

///|
test "State alias declarations render across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|stateDiagram-v2
    #|state "Waiting for input" as waiting
    #|waiting --> active : trigger

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_state_alias.svg", svg)

  assert_true(ascii.contains("Waiting for input"))
  assert_true(ascii.contains("active"))
  assert_true(ascii.contains("trigger"))
  assert_true(unicode.contains("Waiting for input"))
  assert_true(unicode.contains("active"))
  assert_true(unicode.contains("trigger"))
  assert_true(svg.contains(">Waiting for input</text>"))
  assert_true(svg.contains(">active</text>"))
  assert_true(svg.contains(">trigger</text>"))
}

///|
test "State composite alias blocks render across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|stateDiagram-v2
    #|state "Active Processing" as AP {
    #|  parse --> validate
    #|}
    #|AP --> Done : finish

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_state_composite_alias.svg", svg)

  assert_true(ascii.contains("Active Process"))
  assert_true(ascii.contains("parse"))
  assert_true(ascii.contains("validate"))
  assert_true(ascii.contains("Done"))
  assert_true(unicode.contains("Active Process"))
  assert_true(unicode.contains("parse"))
  assert_true(unicode.contains("validate"))
  assert_true(unicode.contains("Done"))
  assert_true(svg.contains(">Active Processing</text>"))
  assert_true(svg.contains(">parse</text>"))
  assert_true(svg.contains(">validate</text>"))
  assert_true(svg.contains(">Done</text>"))
  assert_true(svg.contains(">finish</text>"))
}

///|
test "SVG does not duplicate composite state labels" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|stateDiagram-v2
      #|[*] --> Idle
      #|Idle --> Processing : submit
      #|state Processing {
      #|  parse --> validate
      #|  validate --> execute
      #|}
      #|Processing --> Complete : done
      #|Complete --> [*]
    ),
  )
  snapshot_svg(it, "integration_state_composite_dedup.svg", svg)
  assert_eq(integration_count_occurrences(svg, ">Processing</text>"), 1)
}

///|
test "SVG renders subgraph-first TD diagrams without ordering regressions" (
  it : @test.Test,
) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|subgraph ci [CI Pipeline]
      #|A[Push Code] --> B{Tests Pass?}
      #|B -->|Yes| C[Build Image]
      #|end
      #|C --> D([Deploy])
      #|D --> E{QA?}
      #|E -->|Yes| F((Production))
    ),
  )
  snapshot_svg(it, "integration_flowchart_subgraph_first_order.svg", svg)

  assert_true(svg.contains(">CI Pipeline</text>"))
  assert_true(svg.contains(">Push Code</text>"))
  assert_true(svg.contains(">Deploy</text>"))
  assert_true(svg.contains(">Production</text>"))
}

///|
test "SVG renders flowchart self-loop edges" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|A[Node] --> A
    ),
  )
  snapshot_svg(it, "integration_flowchart_self_loop.svg", svg)
  assert_true(svg.contains("<svg"))
  assert_true(svg.contains(">Node</text>"))
  assert_true(svg.contains("<polyline"))
}

///|
test "SVG renders self-loop labels" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    (
      #|graph TD
      #|A[Retry] -->|again| A
    ),
  )
  snapshot_svg(it, "integration_flowchart_self_loop_label.svg", svg)
  assert_true(svg.contains(">Retry</text>"))
  assert_true(svg.contains(">again</text>"))
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

  let input = integration_input_graph_lr_ab()
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
    integration_input_graph_lr_ab(),
    options={
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
    integration_input_graph_lr_ab(),
    options={
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
test "Standalone sequence activate/deactivate lines are ignored for rendering parity" (
  it : @test.Test,
) {
  let input =
    #|sequenceDiagram
    #|participant A
    #|participant B
    #|activate A
    #|A->>B: Work
    #|deactivate A

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_sequence_standalone_activation.svg", svg)

  assert_true(ascii.contains("Work"))
  assert_true(unicode.contains("Work"))
  assert_true(svg.contains(">Work</text>"))

  assert_true(!ascii.contains("|||"))
  assert_true(!unicode.contains("│││"))
  assert_true(!svg.contains("class=\"sequence-activation\""))
}

///|
test "SVG renders sequence self-message labels with participant aliases" (
  it : @test.Test,
) {
  let input =
    #|sequenceDiagram
    #|participant A as App
    #|A->>A: Retry

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_sequence_self_message_alias.svg", svg)

  assert_true(ascii.contains("App"))
  assert_true(ascii.contains("Retry"))
  assert_true(unicode.contains("App"))
  assert_true(unicode.contains("Retry"))
  assert_true(svg.contains(">App</text>"))
  assert_true(svg.contains(">Retry</text>"))
}

///|
test "Sequence alt/else block renders across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|sequenceDiagram
    #|participant C as Client
    #|participant S as Server
    #|C->>S: Request
    #|alt OK
    #|S-->>C: 200
    #|else Fail
    #|S-->>C: 500
    #|end

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_sequence_alt_else.svg", svg)

  assert_true(ascii.contains("Client"))
  assert_true(ascii.contains("Server"))
  assert_true(ascii.contains("Request"))
  assert_true(ascii.contains("200"))
  assert_true(ascii.contains("500"))
  assert_true(unicode.contains("Client"))
  assert_true(unicode.contains("Server"))
  assert_true(unicode.contains("Request"))
  assert_true(unicode.contains("200"))
  assert_true(unicode.contains("500"))
  assert_true(svg.contains(">Client</text>"))
  assert_true(svg.contains(">Server</text>"))
  assert_true(svg.contains(">Request</text>"))
  assert_true(svg.contains(">200</text>"))
  assert_true(svg.contains(">500</text>"))
}

///|
test "Sequence loop block renders across text and SVG modes" (it : @test.Test) {
  let input =
    #|sequenceDiagram
    #|participant W as Worker
    #|participant Q as Queue
    #|loop Retry every 5s
    #|W->>Q: Poll
    #|Q-->>W: Empty
    #|end

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_sequence_loop.svg", svg)

  assert_true(ascii.contains("Worker"))
  assert_true(ascii.contains("Queue"))
  assert_true(ascii.contains("Poll"))
  assert_true(ascii.contains("Empty"))
  assert_true(unicode.contains("Worker"))
  assert_true(unicode.contains("Queue"))
  assert_true(unicode.contains("Poll"))
  assert_true(unicode.contains("Empty"))
  assert_true(svg.contains(">Worker</text>"))
  assert_true(svg.contains(">Queue</text>"))
  assert_true(svg.contains(">Poll</text>"))
  assert_true(svg.contains(">Empty</text>"))
  assert_true(svg.contains("class=\"sequence-block\""))
}

///|
test "Sequence self-message loop renders across text and SVG modes" (
  it : @test.Test,
) {
  let input =
    #|sequenceDiagram
    #|participant W as Worker
    #|loop Retry
    #|W->>W: Check cache
    #|end

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_sequence_self_message_loop.svg", svg)

  assert_true(ascii.contains("Worker"))
  assert_true(ascii.contains("Check cache"))
  assert_true(unicode.contains("Worker"))
  assert_true(unicode.contains("Check cache"))
  assert_true(svg.contains(">Worker</text>"))
  assert_true(svg.contains(">Check cache</text>"))
  assert_true(svg.contains("class=\"sequence-block\""))
}

///|
test "Sequence opt block renders across text and SVG modes" (it : @test.Test) {
  let input =
    #|sequenceDiagram
    #|participant C as Client
    #|participant API
    #|C->>API: Fetch profile
    #|opt Cache hit
    #|API-->>C: 304 Not Modified
    #|end

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_sequence_opt.svg", svg)

  assert_true(ascii.contains("Client"))
  assert_true(ascii.contains("API"))
  assert_true(ascii.contains("Fetch profile"))
  assert_true(ascii.contains("304 Not Modified"))
  assert_true(unicode.contains("Client"))
  assert_true(unicode.contains("API"))
  assert_true(unicode.contains("Fetch profile"))
  assert_true(unicode.contains("304 Not Modified"))
  assert_true(svg.contains(">Client</text>"))
  assert_true(svg.contains(">API</text>"))
  assert_true(svg.contains(">Fetch profile</text>"))
  assert_true(svg.contains(">304 Not Modified</text>"))
  assert_true(svg.contains("class=\"sequence-block\""))
}

///|
test "Sequence note-over renders across text and SVG modes" (it : @test.Test) {
  let input =
    #|sequenceDiagram
    #|participant A as API
    #|participant B as DB
    #|A->>B: Query
    #|Note over A,B: cache miss
    #|B-->>A: Result

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_sequence_note_over.svg", svg)

  assert_true(ascii.contains("API"))
  assert_true(ascii.contains("DB"))
  assert_true(ascii.contains("cache miss"))
  assert_true(unicode.contains("API"))
  assert_true(unicode.contains("DB"))
  assert_true(unicode.contains("cache miss"))
  assert_true(svg.contains(">API</text>"))
  assert_true(svg.contains(">DB</text>"))
  assert_true(svg.contains(">cache miss</text>"))
  assert_true(svg.contains(">Query</text>"))
  assert_true(svg.contains(">Result</text>"))
}

///|
test "Sequence note-left-right renders across text and SVG modes" (
  it : @test.Test,
) {
  let input = (
      #|sequenceDiagram
      #|participant A as App
      #|participant B as Backend
      #|A->>B: Request
      #|Note left of A: queued
      #|Note right of B: processing
      #|B-->>A: Done
      #|
    )
    .trim_end()
    .to_string()

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_sequence_note_left_right.svg", svg)

  assert_true(ascii.contains("App"))
  assert_true(ascii.contains("Backend"))
  assert_true(ascii.contains("queued"))
  assert_true(ascii.contains("processing"))
  assert_true(ascii.contains("Done"))
  assert_true(unicode.contains("App"))
  assert_true(unicode.contains("Backend"))
  assert_true(unicode.contains("queued"))
  assert_true(unicode.contains("processing"))
  assert_true(unicode.contains("Done"))
  assert_true(svg.contains(">App</text>"))
  assert_true(svg.contains(">Backend</text>"))
  assert_true(svg.contains(">queued</text>"))
  assert_true(svg.contains(">processing</text>"))
  assert_true(svg.contains(">Done</text>"))
  assert_true(svg.contains("class=\"sequence-note\""))
}

///|
test "Sequence critical/option block renders across text and SVG modes" (
  it : @test.Test,
) {
  let input = (
      #|sequenceDiagram
      #|participant S as Service
      #|participant DB as Database
      #|S->>DB: Begin
      #|critical Commit transaction
      #|S->>DB: write row
      #|option Timeout
      #|DB-->>S: timeout
      #|option Success
      #|DB-->>S: ok
      #|end
      #|
    )
    .trim_end()
    .to_string()

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_sequence_critical_option.svg", svg)

  assert_true(ascii.contains("Service"))
  assert_true(ascii.contains("Database"))
  assert_true(ascii.contains("Begin"))
  assert_true(ascii.contains("write row"))
  assert_true(ascii.contains("timeout"))
  assert_true(ascii.contains("ok"))
  assert_true(unicode.contains("Service"))
  assert_true(unicode.contains("Database"))
  assert_true(unicode.contains("Begin"))
  assert_true(unicode.contains("write row"))
  assert_true(unicode.contains("timeout"))
  assert_true(unicode.contains("ok"))
  assert_true(svg.contains(">Service</text>"))
  assert_true(svg.contains(">Database</text>"))
  assert_true(svg.contains(">Begin</text>"))
  assert_true(svg.contains(">write row</text>"))
  assert_true(svg.contains(">timeout</text>"))
  assert_true(svg.contains(">ok</text>"))
}

///|
test "Sequence par/and block renders across text and SVG modes" (
  it : @test.Test,
) {
  let input = (
      #|sequenceDiagram
      #|participant C as Client
      #|participant API
      #|participant DB
      #|par Request API
      #|C->>API: /items
      #|and Write audit
      #|API->>DB: INSERT audit
      #|end
      #|API-->>C: 200
      #|
    )
    .trim_end()
    .to_string()

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_sequence_par_and.svg", svg)

  assert_true(ascii.contains("Client"))
  assert_true(ascii.contains("API"))
  assert_true(ascii.contains("DB"))
  assert_true(ascii.contains("/items"))
  assert_true(ascii.contains("INSERT audit"))
  assert_true(ascii.contains("200"))
  assert_true(unicode.contains("Client"))
  assert_true(unicode.contains("API"))
  assert_true(unicode.contains("DB"))
  assert_true(unicode.contains("/items"))
  assert_true(unicode.contains("INSERT audit"))
  assert_true(unicode.contains("200"))
  assert_true(svg.contains(">Client</text>"))
  assert_true(svg.contains(">API</text>"))
  assert_true(svg.contains(">DB</text>"))
  assert_true(svg.contains(">/items</text>"))
  assert_true(svg.contains(">INSERT audit</text>"))
  assert_true(svg.contains(">200</text>"))
}

///|
test "Sequence activation markers render across text and SVG modes" (
  it : @test.Test,
) {
  let input = (
      #|sequenceDiagram
      #|participant U as User
      #|participant S as Server
      #|U->>+S: Request
      #|S-->>-U: Response
      #|
    )
    .trim_end()
    .to_string()

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_sequence_activation_markers.svg", svg)

  assert_true(ascii.contains("User"))
  assert_true(ascii.contains("Server"))
  assert_true(ascii.contains("Request"))
  assert_true(ascii.contains("Response"))
  assert_true(unicode.contains("User"))
  assert_true(unicode.contains("Server"))
  assert_true(unicode.contains("Request"))
  assert_true(unicode.contains("Response"))
  assert_true(svg.contains(">User</text>"))
  assert_true(svg.contains(">Server</text>"))
  assert_true(svg.contains(">Request</text>"))
  assert_true(svg.contains(">Response</text>"))
  assert_true(svg.contains("class=\"sequence-activation\""))
}

///|
test "Sequence actor declarations render across text and SVG modes" (
  it : @test.Test,
) {
  let input = (
      #|sequenceDiagram
      #|actor U as User
      #|actor S as Service
      #|U->>S: Login
      #|S-->>U: Token
      #|
    )
    .trim_end()
    .to_string()

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_sequence_actor_declarations.svg", svg)

  assert_true(ascii.contains("User"))
  assert_true(ascii.contains("Service"))
  assert_true(ascii.contains("Login"))
  assert_true(ascii.contains("Token"))
  assert_true(unicode.contains("User"))
  assert_true(unicode.contains("Service"))
  assert_true(unicode.contains("Login"))
  assert_true(unicode.contains("Token"))
  assert_true(svg.contains(">User</text>"))
  assert_true(svg.contains(">Service</text>"))
  assert_true(svg.contains(">Login</text>"))
  assert_true(svg.contains(">Token</text>"))
  assert_true(svg.contains("class=\"sequence-actor\""))
}

///|
test "Sequence mixed arrow operators render across text and SVG modes" (
  it : @test.Test,
) {
  let input = (
      #|sequenceDiagram
      #|participant A
      #|participant B
      #|A->B: Open
      #|B--)A: Dotted Open
      #|A-->>B: Filled
      #|
    )
    .trim_end()
    .to_string()

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_sequence_mixed_arrows.svg", svg)

  assert_true(ascii.contains("Open"))
  assert_true(ascii.contains("Dotted Open"))
  assert_true(ascii.contains("Filled"))
  assert_true(unicode.contains("Open"))
  assert_true(unicode.contains("Dotted Open"))
  assert_true(unicode.contains("Filled"))
  assert_true(svg.contains(">Open</text>"))
  assert_true(svg.contains(">Dotted Open</text>"))
  assert_true(svg.contains(">Filled</text>"))
  assert_true(svg.contains("marker-end=\"url(#seq-arrow-open)\""))
  assert_true(svg.contains("marker-end=\"url(#seq-arrow)\""))
}

///|
test "Class inheritance labels render across text and SVG modes" (
  it : @test.Test,
) {
  let input = (
      #|classDiagram
      #|class Shape {
      #|<<abstract>>
      #|+draw() void
      #|}
      #|class Circle {
      #|+radius int
      #|+draw() void
      #|}
      #|Shape <|-- Circle : inherits
      #|
    )
    .trim_end()
    .to_string()

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_class_inheritance.svg", svg)

  assert_true(ascii.contains("Shape"))
  assert_true(ascii.contains("Circle"))
  assert_true(ascii.contains("inherits"))
  assert_true(unicode.contains("Shape"))
  assert_true(unicode.contains("Circle"))
  assert_true(unicode.contains("inherits"))
  assert_true(svg.contains(">Shape</text>"))
  assert_true(svg.contains(">Circle</text>"))
  assert_true(svg.contains(">inherits</text>"))
}

///|
test "Class abstract annotation renders across text and SVG modes" (
  it : @test.Test,
) {
  let input = (
      #|classDiagram
      #|class Service {
      #|<<abstract>>
      #|+run() void
      #|}
      #|class Worker {
      #|+run() void
      #|}
      #|Service <|-- Worker
      #|
    )
    .trim_end()
    .to_string()

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_class_abstract.svg", svg)

  assert_true(ascii.contains("Service"))
  assert_true(ascii.contains("Worker"))
  assert_true(ascii.contains("abstract"))
  assert_true(ascii.contains("run"))
  assert_true(unicode.contains("Service"))
  assert_true(unicode.contains("Worker"))
  assert_true(unicode.contains("abstract"))
  assert_true(unicode.contains("run"))
  assert_true(svg.contains(">Service</text>"))
  assert_true(svg.contains(">Worker</text>"))
  assert_true(svg.contains("&lt;&lt;abstract&gt;&gt;"))
  assert_true(svg.contains("marker-start=\"url(#class-inherit)\""))
}

///|
test "Class interface realization renders across text and SVG modes" (
  it : @test.Test,
) {
  let input = (
      #|classDiagram
      #|class Flyable {
      #|<<interface>>
      #|+fly() void
      #|}
      #|class Bird {
      #|+fly() void
      #|}
      #|Bird ..|> Flyable : implements
      #|
    )
    .trim_end()
    .to_string()

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_class_interface.svg", svg)

  assert_true(ascii.contains("Flyable"))
  assert_true(ascii.contains("Bird"))
  assert_true(ascii.contains("interface"))
  assert_true(ascii.contains("implements"))
  assert_true(unicode.contains("Flyable"))
  assert_true(unicode.contains("Bird"))
  assert_true(unicode.contains("interface"))
  assert_true(unicode.contains("implements"))
  assert_true(svg.contains(">Flyable</text>"))
  assert_true(svg.contains(">Bird</text>"))
  assert_true(svg.contains("&lt;&lt;interface&gt;&gt;"))
  assert_true(svg.contains(">implements</text>"))
}

///|
test "Class enum annotation renders across text and SVG modes" (it : @test.Test) {
  let input = (
      #|classDiagram
      #|class Status {
      #|<<enum>>
      #|+OPEN
      #|+CLOSED
      #|}
      #|Status --> Ticket : labels
      #|
    )
    .trim_end()
    .to_string()

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_class_enum.svg", svg)

  assert_true(ascii.contains("Status"))
  assert_true(ascii.contains("Ticket"))
  assert_true(ascii.contains("OPEN"))
  assert_true(ascii.contains("CLOSED"))
  assert_true(ascii.contains("labels"))
  assert_true(unicode.contains("Status"))
  assert_true(unicode.contains("Ticket"))
  assert_true(unicode.contains("OPEN"))
  assert_true(unicode.contains("CLOSED"))
  assert_true(unicode.contains("labels"))
  assert_true(svg.contains(">Status</text>"))
  assert_true(svg.contains(">Ticket</text>"))
  assert_true(svg.contains("&lt;&lt;enum&gt;&gt;"))
  assert_true(svg.contains(">labels</text>"))
}

///|
test "Class visibility members render across text and SVG modes" (
  it : @test.Test,
) {
  let input = (
      #|classDiagram
      #|class User {
      #|+int id
      #|-string secret
      #|#string name
      #|+login() bool
      #|}
      #|
    )
    .trim_end()
    .to_string()

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_class_visibility.svg", svg)

  assert_true(ascii.contains("User"))
  assert_true(ascii.contains("id"))
  assert_true(ascii.contains("secret"))
  assert_true(ascii.contains("name"))
  assert_true(ascii.contains("login"))
  assert_true(unicode.contains("User"))
  assert_true(unicode.contains("id"))
  assert_true(unicode.contains("secret"))
  assert_true(unicode.contains("name"))
  assert_true(unicode.contains("login"))
  assert_true(svg.contains(">User</text>"))
  assert_true(svg.contains("id"))
  assert_true(svg.contains("secret"))
  assert_true(svg.contains("name"))
  assert_true(svg.contains("login"))
}

///|
test "Class relationship set renders across text and SVG modes" (
  it : @test.Test,
) {
  let input = (
      #|classDiagram
      #|A <|-- B : inh
      #|C *-- D : own
      #|E o-- F : has
      #|G --> H : use
      #|I ..> J : dep
      #|K ..|> L : imp
      #|
    )
    .trim_end()
    .to_string()

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_class_relationship_set.svg", svg)

  assert_true(ascii.contains("inh"))
  assert_true(ascii.contains("own"))
  assert_true(ascii.contains("has"))
  assert_true(ascii.contains("use"))
  assert_true(ascii.contains("dep"))
  assert_true(ascii.contains("imp"))
  assert_true(unicode.contains("inh"))
  assert_true(unicode.contains("own"))
  assert_true(unicode.contains("has"))
  assert_true(unicode.contains("use"))
  assert_true(unicode.contains("dep"))
  assert_true(unicode.contains("imp"))
  assert_true(svg.contains(">A</text>"))
  assert_true(svg.contains(">L</text>"))
  assert_true(svg.contains(">inh</text>"))
  assert_true(svg.contains(">imp</text>"))
  assert_true(svg.contains("marker-start=\"url(#class-inherit)\""))
  assert_true(svg.contains("marker-start=\"url(#class-composition)\""))
  assert_true(svg.contains("marker-start=\"url(#class-aggregation)\""))
  assert_true(svg.contains("marker-end=\"url(#class-arrow)\""))
}

///|
test "ER entities and relationship labels render across text and SVG modes" (
  it : @test.Test,
) {
  let input = (
      #|erDiagram
      #|CUSTOMER {
      #|  int id PK
      #|  string email UK
      #|}
      #|ORDER {
      #|  int id PK
      #|  int customer_id FK
      #|}
      #|CUSTOMER ||--o{ ORDER : places
      #|
    )
    .trim_end()
    .to_string()

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_er_entities_relationship.svg", svg)

  assert_true(ascii.contains("CUSTOMER"))
  assert_true(ascii.contains("ORDER"))
  assert_true(ascii.contains("PK"))
  assert_true(ascii.contains("FK"))
  assert_true(ascii.contains("places"))
  assert_true(unicode.contains("CUSTOMER"))
  assert_true(unicode.contains("ORDER"))
  assert_true(unicode.contains("PK"))
  assert_true(unicode.contains("FK"))
  assert_true(unicode.contains("places"))
  assert_true(svg.contains(">CUSTOMER</text>"))
  assert_true(svg.contains(">ORDER</text>"))
  assert_true(svg.contains(">places</text>"))
}

///|
test "ER attribute keys render across text and SVG modes" (it : @test.Test) {
  let input = (
      #|erDiagram
      #|USER {
      #|  int id PK
      #|  int role_id FK
      #|  string email UK
      #|}
      #|
    )
    .trim_end()
    .to_string()

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_er_attribute_keys.svg", svg)

  assert_true(ascii.contains("USER"))
  assert_true(ascii.contains("id"))
  assert_true(ascii.contains("role_id"))
  assert_true(ascii.contains("email"))
  assert_true(ascii.contains("PK"))
  assert_true(ascii.contains("FK"))
  assert_true(ascii.contains("UK"))
  assert_true(unicode.contains("USER"))
  assert_true(unicode.contains("PK"))
  assert_true(unicode.contains("FK"))
  assert_true(unicode.contains("UK"))
  assert_true(svg.contains(">USER</text>"))
  assert_true(svg.contains("PK"))
  assert_true(svg.contains("FK"))
  assert_true(svg.contains("UK"))
}

///|
test "ER identifying and non-identifying edges render across text and SVG modes" (
  it : @test.Test,
) {
  let input = (
      #|erDiagram
      #|USER ||--o{ ORDER : places
      #|USER ||..o{ LOG : generates
      #|
    )
    .trim_end()
    .to_string()

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_er_identifying_mixed.svg", svg)

  assert_true(ascii.contains("USER"))
  assert_true(ascii.contains("ORDER"))
  assert_true(ascii.contains("LOG"))
  assert_true(ascii.contains("places"))
  assert_true(ascii.contains("generates"))
  assert_true(unicode.contains("USER"))
  assert_true(unicode.contains("ORDER"))
  assert_true(unicode.contains("LOG"))
  assert_true(unicode.contains("places"))
  assert_true(unicode.contains("generates"))
  assert_true(svg.contains(">USER</text>"))
  assert_true(svg.contains(">ORDER</text>"))
  assert_true(svg.contains(">LOG</text>"))
  assert_true(svg.contains(">places</text>"))
  assert_true(svg.contains(">generates</text>"))
  assert_true(svg.contains("stroke-dasharray=\"4 4\""))
}

///|
test "ER mixed cardinalities render across text and SVG modes" (it : @test.Test) {
  let input = "erDiagram\nA ||--|| B : one\nB ||--o{ C : many\nC |o--|{ D : optional\nD }|--o{ E : mixed"

  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = try! @beautiful_mermaid.render_mermaid(input)
  snapshot_svg(it, "integration_er_mixed_cardinalities.svg", svg)

  assert_true(ascii.contains("A"))
  assert_true(ascii.contains("E"))
  assert_true(ascii.contains("one"))
  assert_true(ascii.contains("many"))
  assert_true(ascii.contains("optional"))
  assert_true(ascii.contains("mixed"))
  assert_true(unicode.contains("A"))
  assert_true(unicode.contains("E"))
  assert_true(unicode.contains("one"))
  assert_true(unicode.contains("many"))
  assert_true(unicode.contains("optional"))
  assert_true(unicode.contains("mixed"))
  assert_true(svg.contains(">A</text>"))
  assert_true(svg.contains(">E</text>"))
  assert_true(svg.contains(">one</text>"))
  assert_true(svg.contains(">many</text>"))
  assert_true(svg.contains(">optional</text>"))
  assert_true(svg.contains(">mixed</text>"))
  assert_true(
    integration_count_occurrences(svg, "class=\"edge-endpoint\"") >= 4,
  )
}

///|
test "Flowchart cycle edge label pills do not overlap" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph LR\nA -->|forward| B\nB -->|back| A\nA -->|down| C",
  )
  snapshot_svg(it, "integration_flowchart_cycle_labels.svg", svg)

  let rects = collect_edge_label_rects(svg)
  assert_true(rects.length() >= 3)

  for i in 0..<rects.length() {
    for j in (i + 1)..<rects.length() {
      assert_true(!edge_label_rects_overlap(rects[i], rects[j]))
    }
  }
}
