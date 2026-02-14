///|
fn collect_subgraph_labels(
  subgraphs : Array[@beautiful_mermaid.MermaidSubgraph],
  labels : Array[String],
) -> Unit {
  for subgraph in subgraphs {
    if subgraph.label != "" && !labels.any(label => label == subgraph.label) {
      labels.push(subgraph.label)
    }
    collect_subgraph_labels(subgraph.children, labels)
  }
}

///|
fn assert_subgraph_labels_visible(
  output : String,
  labels : Array[String],
  case_name : String,
) -> Unit raise {
  for label in labels {
    if !output.contains(label) {
      fail("missing subgraph label '\{label}' in \{case_name}")
    }
  }
}

///|
fn is_flow_subgraph_case(case_data : CorpusCase) -> Bool {
  (case_data.header == "graph" || case_data.header == "flowchart") &&
  case_data.input.contains("subgraph ")
}

///|
test "ASCII flowchart corpus subgraph cases keep labels and borders" {
  for case_data in ts_supported_ascii_cases().filter(is_flow_subgraph_case) {
    let graph = @parser_header_core.parse_mermaid(case_data.input)
    if graph.subgraphs.length() == 0 {
      fail("expected parsed subgraphs for \{case_data.name}")
    }

    let labels : Array[String] = []
    collect_subgraph_labels(graph.subgraphs, labels)
    if labels.length() == 0 {
      fail("expected at least one subgraph label for \{case_data.name}")
    }

    let output = @beautiful_mermaid.render_mermaid_ascii(case_data.input, options={
      use_ascii: true,
      padding_x: case_data.padding_x,
      padding_y: case_data.padding_y,
      box_border_padding: 1,
    })
    assert_subgraph_labels_visible(output, labels, case_data.name)
    assert_true(output.contains("+"))
    assert_true(output.contains("|"))
  }
}

///|
test "Unicode flowchart corpus subgraph cases keep labels and borders" {
  for case_data in ts_supported_unicode_cases().filter(is_flow_subgraph_case) {
    let graph = @parser_header_core.parse_mermaid(case_data.input)
    if graph.subgraphs.length() == 0 {
      fail("expected parsed subgraphs for \{case_data.name}")
    }

    let labels : Array[String] = []
    collect_subgraph_labels(graph.subgraphs, labels)
    if labels.length() == 0 {
      fail("expected at least one subgraph label for \{case_data.name}")
    }

    let output = @beautiful_mermaid.render_mermaid_ascii(case_data.input, options={
      use_ascii: false,
      padding_x: case_data.padding_x,
      padding_y: case_data.padding_y,
      box_border_padding: 1,
    })
    assert_subgraph_labels_visible(output, labels, case_data.name)
    assert_true(output.contains("┌"))
    assert_true(output.contains("│"))
  }
}
