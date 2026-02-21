///|
test "elk_trace parse_cli_args defaults to all case" {
  guard parse_cli_args([])
    is Some({ show_help: false, case_name: Some("all"), source: None }) else {
    fail("expected default all-case args")
  }
}

///|
test "elk_trace parse_cli_args accepts case flag forms" {
  guard parse_cli_args(["--case", "fanout"])
    is Some({ show_help: false, case_name: Some("fanout"), source: None }) else {
    fail("expected --case fanout to parse")
  }
  guard parse_cli_args(["--case=feedback_mesh"])
    is Some(
      { show_help: false, case_name: Some("feedback_mesh"), source: None }
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
    is Some({ show_help: false, case_name: None, source: Some(_) }) else {
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
    is Some({ show_help: true, case_name: None, source: None }) else {
    fail("expected --help to parse")
  }
}
