///|
test "trim_flow_canvas_output trims outer blank lines and shared indent" {
  let raw = "\n\n   +---+\n   | A |\n   +---+\n\n"
  assert_eq(trim_flow_canvas_output(raw), "+---+\n| A |\n+---+")
}

///|
test "trim_flow_canvas_output preserves relative indentation" {
  let raw = "\n    root\n      child\n"
  assert_eq(trim_flow_canvas_output(raw), "root\n  child")
}

///|
test "trim_flow_canvas_output returns empty for blank canvas text" {
  let raw = "\n   \n\t\n"
  assert_eq(trim_flow_canvas_output(raw), "")
}

///|
test "flow_node_label hides state pseudo-state labels" {
  let start = PositionedNode::{
    id: "state_start_1",
    label: "",
    shape: NodeShape::StateStart,
    x: 0,
    y: 0,
    width: 10,
    height: 10,
    inline_style: None,
  }
  let regular = PositionedNode::{
    id: "Idle",
    label: "Idle",
    shape: NodeShape::Rounded,
    x: 0,
    y: 0,
    width: 10,
    height: 10,
    inline_style: None,
  }

  assert_eq(flow_node_label(start), "")
  assert_eq(flow_node_label(regular), "Idle")
}

///|
test "plain flowchart edges render as boxed diagrams instead of inline edges" {
  let graph = parse_mermaid("graph LR\nA --> B")
  let output = render_ascii(graph, AsciiRenderOptions::{
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })

  assert_true(output.contains("+"))
  assert_eq(output.contains("[A]--->[B]"), false)
}

///|
test "non-state vertical flow normalizes column width to widest label" {
  let graph = parse_mermaid(
    "graph TD\nA[Normal] --> B[Highlighted] --> C[Error]",
  )
  let output = render_ascii(graph, AsciiRenderOptions::{
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })

  assert_true(output.contains("+-------------+"))
  assert_true(output.contains("| Highlighted |"))
  assert_true(output.contains("|    Normal   |"))
  assert_true(output.contains("|    Error    |"))
}

///|
test "non-state bidirectional flow suppresses start arrowheads" {
  let graph = parse_mermaid("graph LR\nA[Client] <-->|sync| B[Server]")
  let output = render_ascii(graph, AsciiRenderOptions::{
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })

  assert_true(output.contains("| Client |---->| Server |"))
  assert_eq(output.contains("<"), false)
}

///|
test "state lifecycle ascii keeps compact right lane width" {
  let source = "stateDiagram-v2\n  [*] --> Closed\n  Closed --> Connecting : connect\n  Connecting --> Connected : success\n  Connecting --> Closed : timeout\n  Connected --> Disconnecting : close\n  Connected --> Reconnecting : error\n  Reconnecting --> Connected : success\n  Reconnecting --> Closed : max_retries\n  Disconnecting --> Closed : done\n  Closed --> [*]"
  let graph = parse_mermaid(source)
  let output = render_ascii(graph, AsciiRenderOptions::{
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })

  assert_true(output.contains("| Reconnecting |"))
  assert_true(output.contains("+--------------+"))
  assert_eq(output.contains("| Reconnecting  |"), false)
}

///|
test "state lifecycle ascii centers even-length labels with parity bias" {
  let source = "stateDiagram-v2\n  [*] --> Closed\n  Closed --> Connecting : connect\n  Connecting --> Connected : success\n  Connecting --> Closed : timeout\n  Connected --> Disconnecting : close\n  Connected --> Reconnecting : error\n  Reconnecting --> Connected : success\n  Reconnecting --> Closed : max_retries\n  Disconnecting --> Closed : done\n  Closed --> [*]"
  let graph = parse_mermaid(source)
  let output = render_ascii(graph, AsciiRenderOptions::{
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })

  assert_true(output.contains("|     Closed    |"))
}

///|
test "state lifecycle ascii anchors done label near disconnecting source" {
  let source = "stateDiagram-v2\n  [*] --> Closed\n  Closed --> Connecting : connect\n  Connecting --> Connected : success\n  Connecting --> Closed : timeout\n  Connected --> Disconnecting : close\n  Connected --> Reconnecting : error\n  Reconnecting --> Connected : success\n  Reconnecting --> Closed : max_retries\n  Disconnecting --> Closed : done\n  Closed --> [*]"
  let graph = parse_mermaid(source)
  let output = render_ascii(graph, AsciiRenderOptions::{
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })

  assert_true(output.contains("| Disconnecting |   done-+"))
}

///|
test "state lifecycle ascii keeps leftward back-edge arrow off closed border" {
  let source = "stateDiagram-v2\n  [*] --> Closed\n  Closed --> Connecting : connect\n  Connecting --> Connected : success\n  Connecting --> Closed : timeout\n  Connected --> Disconnecting : close\n  Connected --> Reconnecting : error\n  Reconnecting --> Connected : success\n  Reconnecting --> Closed : max_retries\n  Disconnecting --> Closed : done\n  Closed --> [*]"
  let graph = parse_mermaid(source)
  let output = render_ascii(graph, AsciiRenderOptions::{
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })

  assert_true(output.contains("|     Closed    |   <"))
  assert_eq(output.contains("|     Closed    |  <"), false)
  assert_eq(output.contains("|     Closed    |<"), false)
}

///|
test "unicode line merge uses top tee when crossing only continues downward" {
  let canvas = make_canvas(5, 5)
  flow_draw_vline(canvas, 2, 2, 4, "│")
  flow_draw_hline(canvas, 1, 3, 2, "─")

  assert_eq(canvas[2][2], "┬")
}

///|
test "unicode line merge uses left tee when vertical crosses rightward line" {
  let canvas = make_canvas(5, 5)
  flow_draw_hline(canvas, 2, 4, 2, "─")
  flow_draw_vline(canvas, 2, 1, 3, "│")

  assert_eq(canvas[2][2], "├")
}

///|
test "unicode junction normalization keeps one-sided bends as corners" {
  let canvas = make_canvas(6, 6)
  flow_draw_hline(canvas, 1, 4, 2, "─")
  flow_draw_vline(canvas, 4, 2, 5, "│")

  assert_eq(canvas[2][4], "┤")

  flow_normalize_unicode_junctions(canvas)

  assert_eq(canvas[2][4], "┐")
}
