///|
priv enum ElkLayeredCrossingOptimizerStrategy {
  LayerSweepWithLocalRefinement
}

///|
priv enum ElkLayeredCrossingSweepKernel {
  NeighborMeanBidirectional
}

///|
priv enum ElkLayeredCrossingLocalRefinementKernel {
  AdjacentSwap
  RankPermutation
}

///|
fn default_crossing_sweep_kernel() -> ElkLayeredCrossingSweepKernel {
  NeighborMeanBidirectional
}

///|
priv struct ElkLayeredCrossingOptimizationConfig {
  preserve_order_node_threshold : Int
  preserve_order_edge_threshold : Int
  sweep_pass_count : Int
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
