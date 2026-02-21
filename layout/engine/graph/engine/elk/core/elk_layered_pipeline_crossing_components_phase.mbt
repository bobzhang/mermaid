///|
priv enum ElkLayeredCrossingHeuristic {
  LayerSweepNeighborMeanHeuristic
  LayerSweepNeighborMedianHeuristic
  LayerSweepEdgeSlotHeuristic
  LayerSweepPortRankHeuristic
}

///|
priv enum ElkLayeredCrossingPortDistributor {
  IntegratedPortDistribution
}

///|
priv enum ElkLayeredCrossingConstraintResolver {
  LocalRefinementConstraintResolver
}

///|
priv enum ElkLayeredCrossingCounter {
  RankSegmentObjectiveCounter
}

///|
priv struct ElkLayeredCrossingComponentBundle {
  heuristic : ElkLayeredCrossingHeuristic
  port_distributor : ElkLayeredCrossingPortDistributor
  constraint_resolver : ElkLayeredCrossingConstraintResolver
  counter : ElkLayeredCrossingCounter
}

///|
fn build_crossing_component_bundle(
  plan : ElkLayeredCrossingExecutionPlan,
) -> ElkLayeredCrossingComponentBundle {
  {
    heuristic: match plan.sweep_kernel {
      NeighborMeanBidirectional => LayerSweepNeighborMeanHeuristic
      NeighborMedianBidirectional => LayerSweepNeighborMedianHeuristic
      NeighborMeanEdgeSlotBidirectional => LayerSweepEdgeSlotHeuristic
      NeighborMeanPortRankBidirectional => LayerSweepPortRankHeuristic
    },
    port_distributor: IntegratedPortDistribution,
    constraint_resolver: LocalRefinementConstraintResolver,
    counter: RankSegmentObjectiveCounter,
  }
}

///|
fn evaluate_crossing_objective_with_counter(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  objective_context : ElkLayeredCrossingObjectiveContext,
  components : ElkLayeredCrossingComponentBundle,
) -> ElkLayeredCrossingObjective {
  match components.counter {
    RankSegmentObjectiveCounter =>
      evaluate_crossing_objective(rank_node_ids_by_rank, objective_context)
  }
}

///|
fn apply_crossing_sweep_heuristic_once(
  sweep_input : ElkLayeredCrossingSweepInput,
  forward_sweep : Bool,
  components : ElkLayeredCrossingComponentBundle,
) -> Bool {
  match components.port_distributor {
    IntegratedPortDistribution =>
      match components.heuristic {
        LayerSweepNeighborMeanHeuristic =>
          sweep_rank_order_once_from_input_with_kernel(
            sweep_input,
            NeighborMeanBidirectional,
            forward_sweep,
          )
        LayerSweepNeighborMedianHeuristic =>
          sweep_rank_order_once_from_input_with_kernel(
            sweep_input,
            NeighborMedianBidirectional,
            forward_sweep,
          )
        LayerSweepEdgeSlotHeuristic =>
          sweep_rank_order_once_from_input_with_kernel(
            sweep_input,
            NeighborMeanEdgeSlotBidirectional,
            forward_sweep,
          )
        LayerSweepPortRankHeuristic =>
          sweep_rank_order_once_from_input_with_kernel(
            sweep_input,
            NeighborMeanPortRankBidirectional,
            forward_sweep,
          )
      }
  }
}

///|
fn apply_crossing_constraint_resolver(
  refinement_input : ElkLayeredCrossingRefinementInput,
  config : ElkLayeredCrossingOptimizationConfig,
  local_refinement_kernels : Array[ElkLayeredCrossingLocalRefinementKernel],
  components : ElkLayeredCrossingComponentBundle,
) -> Unit {
  match components.constraint_resolver {
    LocalRefinementConstraintResolver =>
      apply_crossing_local_refinement_kernels(
        refinement_input, config, local_refinement_kernels,
      )
  }
}
