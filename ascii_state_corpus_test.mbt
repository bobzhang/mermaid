///|
fn is_state_case(case_data : @test_support.CorpusCase) -> Bool {
  case_data.header == "statediagram" || case_data.header == "statediagram-v2"
}

///|
fn collect_state_labels(
  graph : @beautiful_mermaid.MermaidGraph,
) -> Array[String] {
  let labels : Array[String] = []
  for _, node in graph.nodes {
    let shape_name = node.shape.to_string()
    if shape_name == "StateStart" || shape_name == "StateEnd" {
      continue
    }
    let label = if node.label == "" { node.id } else { node.label }
    if label != "" && !labels.contains(label) {
      labels.push(label)
    }
  }
  labels
}

///|
fn graph_has_state_pseudostates(
  graph : @beautiful_mermaid.MermaidGraph,
) -> Bool {
  for _, node in graph.nodes {
    let shape_name = node.shape.to_string()
    if shape_name == "StateStart" || shape_name == "StateEnd" {
      return true
    }
  }
  false
}

///|
fn assert_state_output_invariants(
  output : String,
  graph : @beautiful_mermaid.MermaidGraph,
  case_name : String,
) -> Unit raise {
  if output.contains("state_start_") || output.contains("state_end_") {
    fail("internal state node ids leaked in \{case_name}")
  }

  for label in collect_state_labels(graph) {
    if !output.contains(label) {
      fail("missing state label '\{label}' in \{case_name}")
    }
  }

  if graph_has_state_pseudostates(graph) && output.trim() == "" {
    fail("empty output for state pseudostates in \{case_name}")
  }
}

///|
test "ASCII state corpus keeps readable labels and pseudostate rendering" {
  for case_data in @test_support.supported_ascii_cases().filter(is_state_case) {
    let graph = try! @beautiful_mermaid.parse_mermaid(case_data.input)
    let output = try! @beautiful_mermaid.render_mermaid_ascii(case_data.input, options={
      use_ascii: true,
      padding_x: case_data.padding_x,
      padding_y: case_data.padding_y,
      box_border_padding: 1,
    })
    assert_state_output_invariants(output, graph, case_data.name)
  }
}

///|
test "Unicode state corpus keeps readable labels and pseudostate rendering" {
  for case_data in @test_support.supported_unicode_cases().filter(is_state_case) {
    let graph = try! @beautiful_mermaid.parse_mermaid(case_data.input)
    let output = try! @beautiful_mermaid.render_mermaid_ascii(case_data.input, options={
      use_ascii: false,
      padding_x: case_data.padding_x,
      padding_y: case_data.padding_y,
      box_border_padding: 1,
    })
    assert_state_output_invariants(output, graph, case_data.name)
  }
}
