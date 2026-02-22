///|
test "elk layered forster in-layer constraints keep already-satisfied order" {
  let node_ids = ["A", "B", "C"]
  let changed = apply_crossing_in_layer_successor_constraints_forster(
    node_ids,
    { "A": ["B"] },
    { "A": 0.0, "B": 1.0, "C": 2.0 },
    { "A": 1, "B": 1, "C": 1 },
  )
  assert_true(!changed)
  assert_eq(node_ids, ["A", "B", "C"])
}

///|
test "elk layered forster in-layer constraints merge violated predecessors" {
  let node_ids = ["C", "B", "A"]
  let changed = apply_crossing_in_layer_successor_constraints_forster(
    node_ids,
    { "A": ["B"] },
    { "A": 2.0, "B": 1.0, "C": 0.0 },
    { "A": 1, "B": 1, "C": 1 },
  )
  assert_true(changed)
  assert_eq(node_ids, ["C", "A", "B"])
}

///|
test "elk layered forster in-layer constraints use weighted merged barycenter" {
  let node_ids = ["C", "B", "A"]
  let changed = apply_crossing_in_layer_successor_constraints_forster(
    node_ids,
    { "A": ["B"] },
    { "A": 3.0, "B": 1.0, "C": 0.0 },
    { "A": 3, "B": 1, "C": 1 },
  )
  assert_true(changed)
  // weighted barycenter of merged [A,B] = (3*3 + 1*1) / 4 = 2.5, so C stays first.
  assert_eq(node_ids, ["C", "A", "B"])
}
