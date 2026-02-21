///|
test "elk_trace parse_cli_args defaults to all case" {
  guard parse_cli_args([])
    is Some(
      {
        show_help: false,
        case_name: Some("all"),
        source: None,
        sweep_kernel: Default,
      }
    ) else {
    fail("expected default all-case args")
  }
}

///|
test "elk_trace parse_cli_args accepts case flag forms" {
  guard parse_cli_args(["--case", "fanout"])
    is Some(
      {
        show_help: false,
        case_name: Some("fanout"),
        source: None,
        sweep_kernel: Default,
      }
    ) else {
    fail("expected --case fanout to parse")
  }
  guard parse_cli_args(["--case=feedback_mesh"])
    is Some(
      {
        show_help: false,
        case_name: Some("feedback_mesh"),
        source: None,
        sweep_kernel: Default,
      }
    ) else {
    fail("expected --case=feedback_mesh to parse")
  }
}

///|
test "elk_trace parse_cli_args accepts source payload" {
  let source = (
      #|graph TD
      #|A --> B
    )
    .trim_end()
    .to_string()
  guard parse_cli_args(["--source", source])
    is Some(
      {
        show_help: false,
        case_name: None,
        source: Some(_),
        sweep_kernel: Default,
      }
    ) else {
    fail("expected --source payload to parse")
  }
}

///|
test "elk_trace parse_cli_args decodes escaped newlines in source payload" {
  guard parse_cli_args(["--source", "graph TD\\nA --> B\\nB --> C"])
    is Some(
      {
        show_help: false,
        case_name: None,
        source: Some("graph TD\nA --> B\nB --> C"),
        sweep_kernel: Default,
      }
    ) else {
    fail("expected escaped newline source payload to decode")
  }
}

///|
test "elk_trace parse_cli_args rejects conflicting source and case" {
  let source = (
      #|graph TD
      #|A --> B
    )
    .trim_end()
    .to_string()
  assert_true(parse_cli_args(["--case", "fanout", "--source", source]) is None)
}

///|
test "elk_trace parse_cli_args preserves help mode" {
  guard parse_cli_args(["--help"])
    is Some(
      { show_help: true, case_name: None, source: None, sweep_kernel: Default }
    ) else {
    fail("expected --help to parse")
  }
}

///|
test "elk_trace parse_cli_args accepts sweep-kernel flag forms" {
  guard parse_cli_args(["--sweep-kernel", "edge-slot"])
    is Some(
      {
        show_help: false,
        case_name: Some("all"),
        source: None,
        sweep_kernel: NeighborMeanEdgeSlotBidirectional,
      }
    ) else {
    fail("expected --sweep-kernel edge-slot to parse")
  }
  guard parse_cli_args(["--sweep-kernel=neighbor-mean"])
    is Some(
      {
        show_help: false,
        case_name: Some("all"),
        source: None,
        sweep_kernel: NeighborMeanBidirectional,
      }
    ) else {
    fail("expected --sweep-kernel=neighbor-mean to parse")
  }
}

///|
test "elk_trace parse_cli_args rejects invalid sweep-kernel values" {
  assert_true(parse_cli_args(["--sweep-kernel", "unknown"]) is None)
  assert_true(parse_cli_args(["--sweep-kernel=unknown"]) is None)
}
