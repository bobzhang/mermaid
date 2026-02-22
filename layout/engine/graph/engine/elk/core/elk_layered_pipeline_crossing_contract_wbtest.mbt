///|
test "elk layered crossing phase input enumerates rank nodes for port-order slots" {
  let rank_node_ids_by_rank : Map[Int, Array[String]] = {
    0: ["A", "B"],
    1: ["C"],
  }
  let input = build_crossing_phase_input(
    rank_node_ids_by_rank,
    1,
    { "A": [], "B": [], "C": ["A", "B"] },
    { "A": ["C"], "B": ["C"], "C": [] },
    { "A": 0, "B": 1, "C": 2 },
    { "A": 0, "B": 0, "C": 1 },
    3,
    2,
  )
  assert_true(input.port_order_slots_by_node_id.contains("A"))
  assert_true(input.port_order_slots_by_node_id.contains("B"))
  assert_true(input.port_order_slots_by_node_id.contains("C"))
  assert_eq(
    match input.port_order_slots_by_node_id.get("A") {
      Some(slots) => slots
      None => [1]
    },
    [],
  )
  assert_eq(input.ordering_edges, [("A", "C"), ("B", "C")])
}

///|
test "elk layered crossing phase input keeps duplicate edges in deterministic source order" {
  let input = build_crossing_phase_input(
    { 0: ["B", "A"], 1: ["C"] },
    1,
    { "A": [], "B": [], "C": ["A", "A", "B"] },
    { "B": ["C"], "A": ["C", "C"], "C": [] },
    { "A": 0, "B": 1, "C": 2 },
    { "A": 0, "B": 0, "C": 1 },
    3,
    3,
  )
  assert_eq(input.ordering_edges, [("A", "C"), ("A", "C"), ("B", "C")])
}

///|
test "elk layered crossing in-layer successor builder filters by rank and deduplicates edges" {
  let in_layer_successors_by_node_id = build_crossing_in_layer_successors_by_node_id(
    [("A", "B"), ("A", "B"), ("A", "C"), ("D", "E"), ("E", "D"), ("F", "F")],
    { "A": 0, "B": 0, "C": 1, "D": 2, "E": 2, "F": 3 },
  )
  assert_eq(
    match in_layer_successors_by_node_id.get("A") {
      Some(successors) => successors
      None => []
    },
    ["B"],
  )
  assert_eq(
    match in_layer_successors_by_node_id.get("D") {
      Some(successors) => successors
      None => []
    },
    ["E"],
  )
  assert_eq(
    match in_layer_successors_by_node_id.get("E") {
      Some(successors) => successors
      None => []
    },
    ["D"],
  )
  assert_true(!in_layer_successors_by_node_id.contains("F"))
}

///|
test "elk layered crossing optimization config keeps baseline thresholds" {
  let config = default_crossing_optimization_config()
  assert_eq(config.preserve_order_node_threshold, 16)
  assert_eq(config.preserve_order_edge_threshold, 30)
  assert_eq(config.sweep_pass_count, 4)
  assert_eq(config.trial_count, 1)
  assert_true(!config.neighbor_mean_barycenter_perturbation)
  assert_eq(config.neighbor_mean_barycenter_perturbation_amount, 0.07)
  assert_true(
    config.trial_continuation_policy is ContinueWhileObjectiveImproves,
  )
  assert_true(config.seed_candidate_source_policy is SeedAndReversed)
  assert_eq(config.swap_refine_node_limit, 200)
  assert_eq(config.swap_refine_edge_limit, 1000)
  assert_eq(config.permutation_refine_node_limit, 200)
  assert_eq(config.permutation_refine_edge_limit, 1000)
  assert_eq(config.permutation_rank_size_limit, 8)
}

///|
test "elk layered crossing seed-candidate source policy exposes all modes" {
  let policies = available_rank_seed_candidate_source_policies()
  assert_eq(policies.length(), 2)
  assert_true(policies[0] is SeedAndReversed)
  assert_true(policies[1] is SeedOnly)
  assert_eq(
    rank_seed_candidate_source_policy_tag(SeedAndReversed),
    "seed-and-reversed",
  )
  assert_eq(rank_seed_candidate_source_policy_tag(SeedOnly), "seed-only")
}

///|
test "elk layered crossing preserve-order tie threshold is strict greater-than" {
  let config = default_crossing_optimization_config()
  assert_true(
    !crossing_preserve_current_order_on_tie(
      config.preserve_order_node_threshold,
      config.preserve_order_edge_threshold,
      config,
    ),
  )
  assert_true(
    crossing_preserve_current_order_on_tie(
      config.preserve_order_node_threshold + 1,
      config.preserve_order_edge_threshold,
      config,
    ),
  )
  assert_true(
    crossing_preserve_current_order_on_tie(
      config.preserve_order_node_threshold,
      config.preserve_order_edge_threshold + 1,
      config,
    ),
  )
}

///|
test "elk layered crossing sweep input builder derives tie policy from phase input" {
  let config = default_crossing_optimization_config()
  let input = build_crossing_phase_input(
    { 0: ["A", "B"], 1: ["C", "D"] },
    1,
    { "A": [], "B": [], "C": ["B"], "D": ["A"] },
    { "A": ["D"], "B": ["C"], "C": [], "D": [] },
    { "A": 0, "B": 1, "C": 2, "D": 3 },
    { "A": 0, "B": 0, "C": 1, "D": 1 },
    17,
    2,
  )
  let sweep_input = build_crossing_sweep_input_from_phase_input_with_random_state(
    input.rank_node_ids_by_rank,
    input,
    config,
    build_crossing_neighbor_mean_random_state_by_seed(config.trial_random_seed),
  )
  assert_eq(sweep_input.max_rank, 1)
  assert_true(sweep_input.preserve_current_order_on_tie)
  assert_true(!sweep_input.neighbor_mean_barycenter_perturbation)
}

///|
test "elk layered crossing sweep input carries neighbor-mean perturbation seed" {
  let base_config = default_crossing_optimization_config()
  let config = {
    ..base_config,
    neighbor_mean_barycenter_perturbation: true,
    trial_random_seed: 7,
  }
  let input = build_crossing_phase_input(
    { 0: ["A", "B"], 1: ["C", "D"] },
    1,
    { "A": [], "B": [], "C": ["B"], "D": ["A"] },
    { "A": ["D"], "B": ["C"], "C": [], "D": [] },
    { "A": 0, "B": 1, "C": 2, "D": 3 },
    { "A": 0, "B": 0, "C": 1, "D": 1 },
    4,
    2,
  )
  let sweep_input = build_crossing_sweep_input_from_phase_input_with_random_state(
    input.rank_node_ids_by_rank,
    input,
    config,
    build_crossing_neighbor_mean_random_state_by_seed(
      config.trial_random_seed + 2,
    ),
  )
  assert_true(sweep_input.neighbor_mean_barycenter_perturbation)
  let actual = next_crossing_neighbor_mean_barycenter_perturbation(
    sweep_input.neighbor_mean_random_state_by_key,
    config.neighbor_mean_barycenter_perturbation_amount,
  )
  let expected = next_crossing_neighbor_mean_barycenter_perturbation(
    build_crossing_neighbor_mean_random_state_by_seed(
      config.trial_random_seed + 2,
    ),
    config.neighbor_mean_barycenter_perturbation_amount,
  )
  assert_eq(actual, expected)
}
