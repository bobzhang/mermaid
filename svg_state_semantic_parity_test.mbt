///|
fn snapshot_state_svg(
  it : @test.Test,
  filename : String,
  svg : String,
) -> Unit raise {
  it.write(svg)
  it.snapshot(filename~)
}

///|
test "SVG state diagram renders basic labels and transition text" (
  it : @test.Test,
) {
  let svg = @beautiful_mermaid.render_mermaid(
    (
      #|stateDiagram-v2
      #|[*] --> Idle
      #|Idle --> Active : start
      #|Active --> Done
    ),
  )
  snapshot_state_svg(it, "semantic_state_basic_labels_transitions.svg", svg)

  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("</svg>"))
  assert_true(svg.contains(">Idle</text>"))
  assert_true(svg.contains(">Active</text>"))
  assert_true(svg.contains(">Done</text>"))
  assert_true(svg.contains(">start</text>"))
}

///|
test "SVG state normal states render rounded corners" (it : @test.Test) {
  let svg = @beautiful_mermaid.render_mermaid(
    (
      #|stateDiagram-v2
      #|Idle --> Active
    ),
  )
  snapshot_state_svg(it, "semantic_state_rounded_corners.svg", svg)

  assert_true(svg.contains("rx=\"6\""))
  assert_true(svg.contains(">Idle</text>"))
  assert_true(svg.contains(">Active</text>"))
}

///|
test "SVG state start pseudostate is a filled no-stroke circle" (
  it : @test.Test,
) {
  let svg = @beautiful_mermaid.render_mermaid(
    (
      #|stateDiagram-v2
      #|[*] --> Ready
    ),
  )
  snapshot_state_svg(it, "semantic_state_start_pseudostate.svg", svg)

  assert_true(svg.contains("<circle"))
  assert_true(svg.contains("class=\"state-start\""))
  assert_true(svg.contains("stroke=\"none\""))
}

///|
test "SVG state end pseudostate renders as a bullseye" (it : @test.Test) {
  let svg = @beautiful_mermaid.render_mermaid(
    (
      #|stateDiagram-v2
      #|Done --> [*]
    ),
  )
  snapshot_state_svg(it, "semantic_state_end_pseudostate.svg", svg)

  assert_true(ts_count_occurrences(svg, "<circle") >= 2)
  assert_true(svg.contains("fill=\"none\""))
  assert_true(svg.contains("stroke=\"none\""))
}

///|
test "SVG state composite declarations avoid duplicate state labels" (
  it : @test.Test,
) {
  let svg = @beautiful_mermaid.render_mermaid(
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
  snapshot_state_svg(
    it, "semantic_state_composite_no_duplicate_labels.svg", svg,
  )

  assert_true(svg.contains(">Idle</text>"))
  assert_true(svg.contains(">Complete</text>"))
  assert_true(svg.contains(">Processing</text>"))
  assert_true(svg.contains(">parse</text>"))
  assert_true(svg.contains(">validate</text>"))
  assert_true(svg.contains(">execute</text>"))
  assert_true(svg.contains(">submit</text>"))
  assert_true(svg.contains(">done</text>"))
  assert_eq(ts_count_occurrences(svg, ">Processing</text>"), 1)
}

///|
test "SVG state cycle renders edge label background pills" (it : @test.Test) {
  let svg = @beautiful_mermaid.render_mermaid(
    (
      #|stateDiagram-v2
      #|[*] --> Ready
      #|Ready --> Running : start
      #|Running --> Paused : pause
      #|Paused --> Running : resume
      #|Running --> Stopped : stop
      #|Stopped --> [*]
    ),
  )
  snapshot_state_svg(it, "semantic_state_cycle_label_bg_pills.svg", svg)

  assert_true(ts_count_occurrences(svg, "class=\"edge-label-bg\"") >= 3)
  assert_true(svg.contains(">start</text>"))
  assert_true(svg.contains(">pause</text>"))
  assert_true(svg.contains(">resume</text>"))
  assert_true(svg.contains(">stop</text>"))
}

///|
test "SVG state cycle edge label pills do not overlap" (it : @test.Test) {
  let svg = @beautiful_mermaid.render_mermaid(
    (
      #|stateDiagram-v2
      #|[*] --> Ready
      #|Ready --> Running : start
      #|Running --> Paused : pause
      #|Paused --> Running : resume
      #|Running --> Stopped : stop
      #|Stopped --> [*]
    ),
  )
  snapshot_state_svg(
    it, "semantic_state_cycle_label_pills_non_overlap.svg", svg,
  )

  let rects = ts_collect_edge_label_rects(svg)
  assert_true(rects.length() >= 3)

  for i in 0..<rects.length() {
    for j in (i + 1)..<rects.length() {
      assert_true(!ts_rects_overlap(rects[i], rects[j]))
    }
  }
}

///|
test "SVG state supports nested composite declarations" (it : @test.Test) {
  let svg = @beautiful_mermaid.render_mermaid(
    (
      #|stateDiagram-v2
      #|[*] --> Active
      #|state Active {
      #|  state Processing {
      #|    state Validating {
      #|      check --> verify
      #|    }
      #|  }
      #|}
      #|Active --> [*]
    ),
  )
  snapshot_state_svg(it, "semantic_state_nested_composite.svg", svg)

  assert_true(svg.contains("<svg"))
  assert_true(svg.contains(">Active</text>"))
  assert_true(svg.contains(">Processing</text>"))
  assert_true(svg.contains(">Validating</text>"))
  assert_true(svg.contains(">check</text>"))
  assert_true(svg.contains(">verify</text>"))
}

///|
test "SVG state diagram direction override changes orientation" (
  it : @test.Test,
) {
  let lr_svg = @beautiful_mermaid.render_mermaid(
    (
      #|stateDiagram-v2
      #|direction LR
      #|[*] --> A
      #|A --> [*]
    ),
  )
  snapshot_state_svg(it, "semantic_state_direction_lr.svg", lr_svg)
  let td_svg = @beautiful_mermaid.render_mermaid(
    (
      #|stateDiagram-v2
      #|[*] --> A
      #|A --> [*]
    ),
  )

  let lr_width = ts_option_or_zero(ts_svg_attr_int(lr_svg, "width"))
  let td_width = ts_option_or_zero(ts_svg_attr_int(td_svg, "width"))
  let lr_height = ts_option_or_zero(ts_svg_attr_int(lr_svg, "height"))
  let td_height = ts_option_or_zero(ts_svg_attr_int(td_svg, "height"))

  assert_true(lr_width > td_width)
  assert_true(td_height > lr_height)
}
