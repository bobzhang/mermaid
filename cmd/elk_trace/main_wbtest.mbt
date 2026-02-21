///|
test "elk_trace parse_cli_args defaults to all case" {
  guard parse_cli_args([])
    is Some(
      {
        show_help: false,
        case_name: Some("all"),
        source: None,
        sweep_kernel: Default,
        trial_count_override: None,
        sweep_pass_count_override: None,
        compare_kernels: false,
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
        trial_count_override: None,
        sweep_pass_count_override: None,
        compare_kernels: false,
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
        trial_count_override: None,
        sweep_pass_count_override: None,
        compare_kernels: false,
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
        trial_count_override: None,
        sweep_pass_count_override: None,
        compare_kernels: false,
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
        trial_count_override: None,
        sweep_pass_count_override: None,
        compare_kernels: false,
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
      {
        show_help: true,
        case_name: None,
        source: None,
        sweep_kernel: Default,
        trial_count_override: None,
        sweep_pass_count_override: None,
        compare_kernels: false,
      }
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
        trial_count_override: None,
        sweep_pass_count_override: None,
        compare_kernels: false,
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
        trial_count_override: None,
        sweep_pass_count_override: None,
        compare_kernels: false,
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

///|
test "elk_trace parse_cli_args accepts compare-kernels flag" {
  guard parse_cli_args(["--compare-kernels"])
    is Some(
      {
        show_help: false,
        case_name: Some("all"),
        source: None,
        sweep_kernel: Default,
        trial_count_override: None,
        sweep_pass_count_override: None,
        compare_kernels: true,
      }
    ) else {
    fail("expected --compare-kernels to parse")
  }
}

///|
test "elk_trace parse_cli_args accepts crossing override flags" {
  guard parse_cli_args(["--trial-count", "5", "--sweep-pass-count=6"])
    is Some(
      {
        show_help: false,
        case_name: Some("all"),
        source: None,
        sweep_kernel: Default,
        trial_count_override: Some(5),
        sweep_pass_count_override: Some(6),
        compare_kernels: false,
      }
    ) else {
    fail("expected crossing override flags to parse")
  }
}

///|
test "elk_trace parse_cli_args rejects invalid crossing override values" {
  assert_true(parse_cli_args(["--trial-count", "0"]) is None)
  assert_true(parse_cli_args(["--trial-count=-1"]) is None)
  assert_true(parse_cli_args(["--trial-count", "x"]) is None)
  assert_true(parse_cli_args(["--sweep-pass-count", "0"]) is None)
  assert_true(parse_cli_args(["--sweep-pass-count=-2"]) is None)
  assert_true(parse_cli_args(["--sweep-pass-count", "x"]) is None)
}
