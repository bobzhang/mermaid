///|
test "elk layered crossing component bundle maps default plan roles" {
  let plan = default_crossing_execution_plan(LayerSweepWithLocalRefinement)
  let components = build_crossing_component_bundle(plan)
  assert_eq(components.heuristic.role, "layer-sweep-neighbor-mean")
  assert_true(components.heuristic.sweep_kernel is NeighborMeanBidirectional)
  assert_eq(components.port_distributor.role, "integrated-port-distribution")
  assert_eq(
    components.constraint_resolver.role,
    "local-refinement-constraint-resolver",
  )
  assert_eq(components.counter.role, "rank-segment-objective-counter")
}

///|
test "elk layered crossing component bundle maps edge-slot heuristic role" {
  let default_plan = default_crossing_execution_plan(
    LayerSweepWithLocalRefinement,
  )
  let plan = { ..default_plan, sweep_kernel: NeighborMeanEdgeSlotBidirectional }
  let components = build_crossing_component_bundle(plan)
  assert_eq(components.heuristic.role, "layer-sweep-edge-slot")
  assert_true(
    components.heuristic.sweep_kernel is NeighborMeanEdgeSlotBidirectional,
  )
}

///|
test "elk layered crossing component bundle maps port-rank heuristic role" {
  let default_plan = default_crossing_execution_plan(
    LayerSweepWithLocalRefinement,
  )
  let plan = { ..default_plan, sweep_kernel: NeighborMeanPortRankBidirectional }
  let components = build_crossing_component_bundle(plan)
  assert_eq(components.heuristic.role, "layer-sweep-port-rank")
  assert_true(
    components.heuristic.sweep_kernel is NeighborMeanPortRankBidirectional,
  )
}
