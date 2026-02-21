///|
test "elk_render parse_cli_args accepts default positional source" {
  guard parse_cli_args(["graph TD\\nA --> B"])
    is Some(
      {
        show_help: false,
        source: Some("graph TD\\nA --> B"),
        sweep_kernel: Default,
        trial_count_override: None,
        sweep_pass_count_override: None,
        layout_engine: Elk,
      }
    ) else {
    fail("expected positional source parse")
  }
}

///|
test "elk_render parse_cli_args accepts override flags" {
  guard parse_cli_args([
      "--source", "graph TD\\nA --> B", "--sweep-kernel=edge-slot", "--trial-count",
      "5", "--sweep-pass-count=6", "--layout-engine", "elk-layered",
    ])
    is Some(
      {
        show_help: false,
        source: Some("graph TD\\nA --> B"),
        sweep_kernel: NeighborMeanEdgeSlotBidirectional,
        trial_count_override: Some(5),
        sweep_pass_count_override: Some(6),
        layout_engine: ElkLayered,
      }
    ) else {
    fail("expected override flags parse")
  }
}

///|
test "elk_render parse_cli_args preserves help mode" {
  guard parse_cli_args(["--help"])
    is Some(
      {
        show_help: true,
        source: None,
        sweep_kernel: Default,
        trial_count_override: None,
        sweep_pass_count_override: None,
        layout_engine: Elk,
      }
    ) else {
    fail("expected help parse")
  }
}

///|
test "elk_render parse_cli_args rejects invalid values" {
  assert_true(
    parse_cli_args(["--trial-count", "0", "graph TD\\nA --> B"]) is None,
  )
  assert_true(
    parse_cli_args(["--sweep-pass-count=-1", "graph TD\\nA --> B"]) is None,
  )
  assert_true(
    parse_cli_args(["--layout-engine=dagre", "graph TD\\nA --> B"]) is None,
  )
  assert_true(
    parse_cli_args(["--sweep-kernel=unknown", "graph TD\\nA --> B"]) is None,
  )
}
