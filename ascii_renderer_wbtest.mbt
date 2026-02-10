///|
fn state_lifecycle_source() -> String {
  (
    #|stateDiagram-v2
    #|  [*] --> Closed
    #|  Closed --> Connecting : connect
    #|  Connecting --> Connected : success
    #|  Connecting --> Closed : timeout
    #|  Connected --> Disconnecting : close
    #|  Connected --> Reconnecting : error
    #|  Reconnecting --> Connected : success
    #|  Reconnecting --> Closed : max_retries
    #|  Disconnecting --> Closed : done
    #|  Closed --> [*]
  )
}

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
    shape: StateStart,
    x: 0,
    y: 0,
    width: 10,
    height: 10,
    inline_style: None,
  }
  let regular = PositionedNode::{
    id: "Idle",
    label: "Idle",
    shape: Rounded,
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
  let graph = parse_mermaid(
    (
      #|graph LR
      #|A --> B
    ),
  )
  let output = render_ascii(graph, {
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
    (
      #|graph TD
      #|A[Normal] --> B[Highlighted] --> C[Error]
    ),
  )
  let output = render_ascii(graph, {
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
  let graph = parse_mermaid(
    (
      #|graph LR
      #|A[Client] <-->|sync| B[Server]
    ),
  )
  let output = render_ascii(graph, {
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })

  assert_true(output.contains("| Client |sync->| Server |"))
  assert_eq(output.contains("<"), false)
}

///|
test "non-state chained labels stay on horizontal edge runs" {
  let graph = parse_mermaid(
    (
      #|graph LR
      #|A[Client] <-->|sync| B[Server]
      #|B <-.->|heartbeat| C[Monitor]
      #|C <==>|data| D[Storage]
    ),
  )
  let output = render_ascii(graph, {
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })

  assert_true(output.contains("sync->"))
  assert_true(output.contains("heartbeat>"))
  assert_true(output.contains("data->"))
}

///|
test "non-state vertical fan-in avoids source-row cross-links" {
  let graph = parse_mermaid(
    (
      #|graph TD
      #|A[Input] & B[Config] --> C[Processor]
      #|C --> D[Output] & E[Log]
    ),
  )
  let output = render_ascii(graph, {
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })

  assert_eq(output.contains("|   Input   |-----"), false)
  assert_true(output.contains("| Processor |<"))
}

///|
test "non-state subgraph override keeps border crossings clean" {
  let graph = parse_mermaid(
    (
      #|graph TD
      #|subgraph pipeline [Processing Pipeline]
      #|direction LR
      #|A[Input] --> B[Parse] --> C[Transform] --> D[Output]
      #|end
      #|E[Source] --> A
      #|D --> F[Sink]
    ),
  )
  let output = render_ascii(graph, {
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })

  assert_eq(output.contains("|<+---|"), false)
  assert_true(output.contains("|<----|"))
  assert_true(output.contains("+-------|-------+"))
}

///|
test "state lifecycle ascii keeps compact right lane width" {
  let source = state_lifecycle_source()
  let graph = parse_mermaid(source)
  let output = render_ascii(graph, {
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
  let source = state_lifecycle_source()
  let graph = parse_mermaid(source)
  let output = render_ascii(graph, {
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })

  assert_true(output.contains("|     Closed    |"))
}

///|
test "state lifecycle ascii anchors done label near disconnecting source" {
  let source = state_lifecycle_source()
  let graph = parse_mermaid(source)
  let output = render_ascii(graph, {
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })

  assert_true(output.contains("| Disconnecting |   done-+"))
}

///|
test "state lifecycle ascii keeps leftward back-edge arrow off closed border" {
  let source = state_lifecycle_source()
  let graph = parse_mermaid(source)
  let output = render_ascii(graph, {
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
