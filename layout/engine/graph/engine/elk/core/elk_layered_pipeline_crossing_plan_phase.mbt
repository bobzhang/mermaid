///|
priv enum ElkLayeredCrossingOptimizerStrategy {
  LayerSweepWithLocalRefinement
}

///|
priv enum ElkLayeredCrossingSweepKernel {
  NeighborMeanBidirectional
  NeighborMeanEdgeSlotBidirectional
}

///|
priv enum ElkLayeredCrossingLocalRefinementKernel {
  AdjacentSwap
  RankPermutation
}

///|
fn default_crossing_sweep_kernel() -> ElkLayeredCrossingSweepKernel {
  available_crossing_sweep_kernels()[0]
}

///|
fn available_crossing_sweep_kernels() -> Array[ElkLayeredCrossingSweepKernel] {
  [NeighborMeanBidirectional, NeighborMeanEdgeSlotBidirectional]
}

///|
priv struct ElkLayeredCrossingOptimizationConfig {
  preserve_order_node_threshold : Int
  preserve_order_edge_threshold : Int
  sweep_pass_count : Int
  trial_count : Int
  trial_random_seed : Int
  trial_model_order_inversion_influence : Double
  swap_refine_node_limit : Int
  swap_refine_edge_limit : Int
  permutation_refine_node_limit : Int
  permutation_refine_edge_limit : Int
  permutation_rank_size_limit : Int
}

///|
fn default_crossing_optimization_config() -> ElkLayeredCrossingOptimizationConfig {
  {
    preserve_order_node_threshold: 16,
    preserve_order_edge_threshold: 30,
    sweep_pass_count: 4,
    trial_count: 1,
    trial_random_seed: 1,
    trial_model_order_inversion_influence: 0.0,
    swap_refine_node_limit: 40,
    swap_refine_edge_limit: 120,
    permutation_refine_node_limit: 28,
    permutation_refine_edge_limit: 80,
    permutation_rank_size_limit: 6,
  }
}

///|
priv struct ElkLayeredCrossingExecutionPlan {
  strategy : ElkLayeredCrossingOptimizerStrategy
  config : ElkLayeredCrossingOptimizationConfig
  sweep_kernel : ElkLayeredCrossingSweepKernel
  local_refinement_kernels : Array[ElkLayeredCrossingLocalRefinementKernel]
}

///|
fn default_crossing_local_refinement_kernels() -> Array[
  ElkLayeredCrossingLocalRefinementKernel,
] {
  [AdjacentSwap, RankPermutation]
}

///|
fn default_crossing_execution_plan(
  strategy : ElkLayeredCrossingOptimizerStrategy,
) -> ElkLayeredCrossingExecutionPlan {
  {
    strategy,
    config: default_crossing_optimization_config(),
    sweep_kernel: default_crossing_sweep_kernel(),
    local_refinement_kernels: default_crossing_local_refinement_kernels(),
  }
}
