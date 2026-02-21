///|
test "elk layered crossing component bundle maps default plan roles" {
  let plan = default_crossing_execution_plan(LayerSweepWithLocalRefinement)
  let components = build_crossing_component_bundle(plan)
  assert_true(components.heuristic is LayerSweepNeighborMeanHeuristic)
  assert_true(components.port_distributor is IntegratedPortDistribution)
  assert_true(
    components.constraint_resolver is LocalRefinementConstraintResolver,
  )
  assert_true(components.counter is RankSegmentObjectiveCounter)
}

///|
test "elk layered crossing component bundle maps edge-slot heuristic role" {
  let default_plan = default_crossing_execution_plan(
    LayerSweepWithLocalRefinement,
  )
  let plan = { ..default_plan, sweep_kernel: NeighborMeanEdgeSlotBidirectional }
  let components = build_crossing_component_bundle(plan)
  assert_true(components.heuristic is LayerSweepEdgeSlotHeuristic)
}

///|
test "elk layered crossing component bundle maps port-rank heuristic role" {
  let default_plan = default_crossing_execution_plan(
    LayerSweepWithLocalRefinement,
  )
  let plan = { ..default_plan, sweep_kernel: NeighborMeanPortRankBidirectional }
  let components = build_crossing_component_bundle(plan)
  assert_true(components.heuristic is LayerSweepPortRankHeuristic)
}
