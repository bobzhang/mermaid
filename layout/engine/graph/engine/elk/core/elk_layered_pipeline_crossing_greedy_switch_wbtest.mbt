///|
test "elk layered crossing greedy switch swaps adjacent pair when it reduces crossings" {
  let free_node_ids = ["L", "R"]
  let changed = apply_crossing_greedy_switch_rank_by_fixed_layer(
    free_node_ids,
    { "L": ["F2"], "R": ["F1"] },
    {},
    { "F1": 0, "F2": 1 },
    { "L": 0, "R": 1 },
    true,
    2,
  )
  assert_true(changed)
  assert_eq(free_node_ids, ["R", "L"])
}

///|
test "elk layered crossing greedy switch keeps order on tie when preserving current order" {
  let free_node_ids = ["L", "R"]
  let changed = apply_crossing_greedy_switch_rank_by_fixed_layer(
    free_node_ids,
    { "L": ["F1"], "R": ["F1"] },
    {},
    { "F1": 0 },
    { "L": 1, "R": 0 },
    true,
    2,
  )
  assert_true(!changed)
  assert_eq(free_node_ids, ["L", "R"])
}

///|
test "elk layered crossing greedy switch uses model order tie break when preserving order is disabled" {
  let free_node_ids = ["L", "R"]
  let changed = apply_crossing_greedy_switch_rank_by_fixed_layer(
    free_node_ids,
    { "L": ["F1"], "R": ["F1"] },
    {},
    { "F1": 0 },
    { "L": 1, "R": 0 },
    false,
    2,
  )
  assert_true(changed)
  assert_eq(free_node_ids, ["R", "L"])
}

///|
test "elk layered crossing greedy switch pass limit controls multi-step convergence" {
  let predecessor_by_node_id : Map[String, Array[String]] = {
    "A": ["F0"],
    "B": ["F1"],
    "C": ["F2"],
  }
  let rank_position_by_node_id : Map[String, Int] = {
    "F0": 0,
    "F1": 1,
    "F2": 2,
  }
  let order_index_by_node_id : Map[String, Int] = { "C": 0, "B": 1, "A": 2 }

  let one_pass = ["C", "B", "A"]
  let one_pass_changed = apply_crossing_greedy_switch_rank_by_fixed_layer(
    one_pass,
    predecessor_by_node_id,
    {},
    rank_position_by_node_id,
    order_index_by_node_id,
    true,
    1,
  )
  assert_true(one_pass_changed)
  assert_eq(one_pass, ["B", "A", "C"])

  let two_passes = ["C", "B", "A"]
  let two_passes_changed = apply_crossing_greedy_switch_rank_by_fixed_layer(
    two_passes,
    predecessor_by_node_id,
    {},
    rank_position_by_node_id,
    order_index_by_node_id,
    true,
    2,
  )
  assert_true(two_passes_changed)
  assert_eq(two_passes, ["A", "B", "C"])
}

///|
test "elk layered crossing greedy switch uses both predecessor and successor crossing deltas" {
  let free_node_ids = ["L", "R"]
  let changed = apply_crossing_greedy_switch_rank_by_fixed_layer(
    free_node_ids,
    { "L": ["P2"], "R": ["P1"] },
    { "L": ["S2"], "R": ["S1"] },
    { "P1": 0, "P2": 1, "S1": 0, "S2": 1 },
    { "L": 0, "R": 1 },
    true,
    2,
  )
  assert_true(changed)
  assert_eq(free_node_ids, ["R", "L"])
}
