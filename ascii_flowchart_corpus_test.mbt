///|
fn is_flowchart_case(case_data : @test_support.CorpusCase) -> Bool {
  case_data.header == "graph" || case_data.header == "flowchart"
}

///|
fn collect_flow_labels(
  graph : @beautiful_mermaid.MermaidGraph,
) -> Array[String] {
  let labels : Array[String] = []
  for _, node in graph.nodes {
    let label = if node.label == "" { node.id } else { node.label }
    if !labels.contains(label) {
      labels.push(label)
    }
  }
  labels
}

///|
fn assert_output_contains_flow_labels(
  output : String,
  labels : Array[String],
  case_name : String,
) -> Unit raise {
  for label in labels {
    if !output.contains(label) {
      fail("missing node label '\{label}' in \{case_name}")
    }
  }
}

///|
test "ASCII flowchart corpus keeps node labels visible" {
  for
    case_data in @test_support.supported_ascii_cases().filter(is_flowchart_case) {
    let graph = try! @beautiful_mermaid.parse_mermaid(case_data.input)
    let labels = collect_flow_labels(graph)
    if labels.length() == 0 {
      fail("expected at least one node for \{case_data.name}")
    }

    let output = try! @beautiful_mermaid.render_mermaid_ascii(case_data.input, options={
      use_ascii: true,
      padding_x: case_data.padding_x,
      padding_y: case_data.padding_y,
      box_border_padding: 1,
    })

    assert_output_contains_flow_labels(output, labels, case_data.name)
    assert_true(output.contains("+") || output.contains("["))
  }
}

///|
test "Unicode flowchart corpus keeps node labels visible" {
  for
    case_data in @test_support.supported_unicode_cases().filter(
      is_flowchart_case,
    ) {
    let graph = try! @beautiful_mermaid.parse_mermaid(case_data.input)
    let labels = collect_flow_labels(graph)
    if labels.length() == 0 {
      fail("expected at least one node for \{case_data.name}")
    }

    let output = try! @beautiful_mermaid.render_mermaid_ascii(case_data.input, options={
      use_ascii: false,
      padding_x: case_data.padding_x,
      padding_y: case_data.padding_y,
      box_border_padding: 1,
    })

    assert_output_contains_flow_labels(output, labels, case_data.name)
    assert_true(output.contains("┌") || output.contains("["))
  }
}
