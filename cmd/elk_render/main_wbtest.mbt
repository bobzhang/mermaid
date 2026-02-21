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
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
        trial_model_order_inversion_influence_override: None,
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
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
        trial_model_order_inversion_influence_override: None,
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
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
        trial_model_order_inversion_influence_override: None,
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
  assert_true(
    parse_cli_args(["--trial-continuation-policy=unknown", "graph TD\\nA --> B"])
    is None,
  )
  assert_true(
    parse_cli_args([
      "--model-order-inversion-influence=-0.1", "graph TD\\nA --> B",
    ])
    is None,
  )
}

///|
test "elk_render parse_cli_args accepts model-order inversion influence override" {
  guard parse_cli_args([
      "--model-order-inversion-influence", "0.25", "graph TD\\nA --> B",
    ])
    is Some(
      {
        show_help: false,
        source: Some("graph TD\\nA --> B"),
        sweep_kernel: Default,
        trial_count_override: None,
        sweep_pass_count_override: None,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: None,
        trial_model_order_inversion_influence_override: Some(0.25),
        layout_engine: Elk,
      }
    ) else {
    fail("expected model-order inversion influence override parse")
  }
}

///|
test "elk_render parse_cli_args accepts trial continuation policy override" {
  guard parse_cli_args([
      "--trial-continuation-policy", "objective-improves", "graph TD\\nA --> B",
    ])
    is Some(
      {
        show_help: false,
        source: Some("graph TD\\nA --> B"),
        sweep_kernel: Default,
        trial_count_override: None,
        sweep_pass_count_override: None,
        trial_continuation_policy_override: Some(WhileObjectiveImproves),
        local_refinement_profile_override: None,
        trial_model_order_inversion_influence_override: None,
        layout_engine: Elk,
      }
    ) else {
    fail("expected trial continuation policy override parse")
  }
}

///|
test "elk_render parse_cli_args accepts local refinement profile override" {
  guard parse_cli_args([
      "--local-refinement-profile", "rank-permutation", "graph TD\\nA --> B",
    ])
    is Some(
      {
        show_help: false,
        source: Some("graph TD\\nA --> B"),
        sweep_kernel: Default,
        trial_count_override: None,
        sweep_pass_count_override: None,
        trial_continuation_policy_override: None,
        local_refinement_profile_override: Some(RankPermutationOnly),
        trial_model_order_inversion_influence_override: None,
        layout_engine: Elk,
      }
    ) else {
    fail("expected local refinement profile override parse")
  }
}

///|
test "elk_render parse_cli_args rejects invalid local refinement profile values" {
  assert_true(
    parse_cli_args(["--local-refinement-profile=unknown", "graph TD\\nA --> B"])
    is None,
  )
}
