///|
priv struct ElkLayeredCrossingHeuristicContract {
  role : String
  sweep_kernel : ElkLayeredCrossingSweepKernel
}

///|
priv struct ElkLayeredCrossingPortDistributorContract {
  role : String
}

///|
priv struct ElkLayeredCrossingConstraintResolverContract {
  role : String
}

///|
priv struct ElkLayeredCrossingCounterContract {
  role : String
}

///|
priv struct ElkLayeredCrossingComponentBundle {
  heuristic : ElkLayeredCrossingHeuristicContract
  port_distributor : ElkLayeredCrossingPortDistributorContract
  constraint_resolver : ElkLayeredCrossingConstraintResolverContract
  counter : ElkLayeredCrossingCounterContract
}

///|
fn crossing_heuristic_role_tag(
  sweep_kernel : ElkLayeredCrossingSweepKernel,
) -> String {
  match sweep_kernel {
    NeighborMeanBidirectional => "layer-sweep-neighbor-mean"
    NeighborMedianBidirectional => "layer-sweep-neighbor-median"
    NeighborMeanEdgeSlotBidirectional => "layer-sweep-edge-slot"
    NeighborMeanPortRankBidirectional => "layer-sweep-port-rank"
  }
}

///|
fn build_crossing_heuristic_contract(
  sweep_kernel : ElkLayeredCrossingSweepKernel,
) -> ElkLayeredCrossingHeuristicContract {
  { role: crossing_heuristic_role_tag(sweep_kernel), sweep_kernel }
}

///|
fn build_crossing_port_distributor_contract() -> ElkLayeredCrossingPortDistributorContract {
  { role: "integrated-port-distribution" }
}

///|
fn build_crossing_constraint_resolver_contract() -> ElkLayeredCrossingConstraintResolverContract {
  { role: "local-refinement-constraint-resolver" }
}

///|
fn build_crossing_counter_contract() -> ElkLayeredCrossingCounterContract {
  { role: "rank-segment-objective-counter" }
}

///|
fn build_crossing_component_bundle(
  plan : ElkLayeredCrossingExecutionPlan,
) -> ElkLayeredCrossingComponentBundle {
  {
    heuristic: build_crossing_heuristic_contract(plan.sweep_kernel),
    port_distributor: build_crossing_port_distributor_contract(),
    constraint_resolver: build_crossing_constraint_resolver_contract(),
    counter: build_crossing_counter_contract(),
  }
}

///|
fn evaluate_crossing_objective_with_counter(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  objective_context : ElkLayeredCrossingObjectiveContext,
  components : ElkLayeredCrossingComponentBundle,
) -> ElkLayeredCrossingObjective {
  let _ = components.counter.role
  evaluate_crossing_objective(rank_node_ids_by_rank, objective_context)
}

///|
fn apply_crossing_sweep_heuristic_once(
  sweep_input : ElkLayeredCrossingSweepInput,
  forward_sweep : Bool,
  is_first_sweep : Bool,
  components : ElkLayeredCrossingComponentBundle,
) -> Bool {
  let _ = components.heuristic.role
  let _ = components.port_distributor.role
  sweep_rank_order_once_from_input_with_kernel(
    sweep_input,
    components.heuristic.sweep_kernel,
    forward_sweep,
    is_first_sweep,
  )
}

///|
fn apply_crossing_constraint_resolver(
  refinement_input : ElkLayeredCrossingRefinementInput,
  config : ElkLayeredCrossingOptimizationConfig,
  local_refinement_kernels : Array[ElkLayeredCrossingLocalRefinementKernel],
  components : ElkLayeredCrossingComponentBundle,
) -> Unit {
  let _ = components.constraint_resolver.role
  apply_crossing_local_refinement_kernels(
    refinement_input, config, local_refinement_kernels,
  )
}
