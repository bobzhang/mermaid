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
        trial_model_order_inversion_influence_override: None,
        compare_kernels: false,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
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
        trial_model_order_inversion_influence_override: None,
        compare_kernels: false,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
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
        trial_model_order_inversion_influence_override: None,
        compare_kernels: false,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
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
        trial_model_order_inversion_influence_override: None,
        compare_kernels: false,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
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
        trial_model_order_inversion_influence_override: None,
        compare_kernels: false,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
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
        trial_model_order_inversion_influence_override: None,
        compare_kernels: false,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
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
        trial_model_order_inversion_influence_override: None,
        compare_kernels: false,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
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
        trial_model_order_inversion_influence_override: None,
        compare_kernels: false,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
      }
    ) else {
    fail("expected --sweep-kernel=neighbor-mean to parse")
  }
  guard parse_cli_args(["--sweep-kernel=neighbor-median"])
    is Some(
      {
        show_help: false,
        case_name: Some("all"),
        source: None,
        sweep_kernel: NeighborMedianBidirectional,
        trial_count_override: None,
        sweep_pass_count_override: None,
        trial_model_order_inversion_influence_override: None,
        compare_kernels: false,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
      }
    ) else {
    fail("expected --sweep-kernel=neighbor-median to parse")
  }
  guard parse_cli_args(["--sweep-kernel=port-rank"])
    is Some(
      {
        show_help: false,
        case_name: Some("all"),
        source: None,
        sweep_kernel: NeighborMeanPortRankBidirectional,
        trial_count_override: None,
        sweep_pass_count_override: None,
        trial_model_order_inversion_influence_override: None,
        compare_kernels: false,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
      }
    ) else {
    fail("expected --sweep-kernel=port-rank to parse")
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
        trial_model_order_inversion_influence_override: None,
        compare_kernels: true,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
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
        trial_model_order_inversion_influence_override: None,
        compare_kernels: false,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
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
  assert_true(
    parse_cli_args(["--model-order-inversion-influence", "-0.1"]) is None,
  )
  assert_true(
    parse_cli_args(["--model-order-inversion-influence", "x"]) is None,
  )
}

///|
test "elk_trace parse_cli_args accepts model-order inversion influence override" {
  guard parse_cli_args(["--model-order-inversion-influence=0.25"])
    is Some(
      {
        show_help: false,
        case_name: Some("all"),
        source: None,
        sweep_kernel: Default,
        trial_count_override: None,
        sweep_pass_count_override: None,
        trial_model_order_inversion_influence_override: Some(0.25),
        compare_kernels: false,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
      }
    ) else {
    fail("expected model-order inversion influence override to parse")
  }
}

///|
test "elk_trace parse_cli_args accepts local refinement profile override" {
  guard parse_cli_args(["--local-refinement-profile", "none"])
    is Some(
      {
        show_help: false,
        case_name: Some("all"),
        source: None,
        sweep_kernel: Default,
        trial_count_override: None,
        sweep_pass_count_override: None,
        trial_model_order_inversion_influence_override: None,
        compare_kernels: false,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: Some(NoLocalRefinement),
      }
    ) else {
    fail("expected local refinement profile override to parse")
  }
  guard parse_cli_args(["--local-refinement-profile=adjacent-swap"])
    is Some(
      {
        show_help: false,
        case_name: Some("all"),
        source: None,
        sweep_kernel: Default,
        trial_count_override: None,
        sweep_pass_count_override: None,
        trial_model_order_inversion_influence_override: None,
        compare_kernels: false,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: Some(AdjacentSwapOnly),
      }
    ) else {
    fail("expected local refinement profile equals-form to parse")
  }
}

///|
test "elk_trace parse_cli_args rejects invalid local refinement profile values" {
  assert_true(parse_cli_args(["--local-refinement-profile", "unknown"]) is None)
  assert_true(parse_cli_args(["--local-refinement-profile=unknown"]) is None)
}
