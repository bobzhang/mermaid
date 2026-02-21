///|
priv enum ElkLayeredCrossingOptimizerStrategy {
  LayerSweepWithLocalRefinement
}

///|
priv enum ElkLayeredCrossingSweepKernel {
  NeighborMeanBidirectional
  NeighborMedianBidirectional
  NeighborMeanEdgeSlotBidirectional
  NeighborMeanPortRankBidirectional
}

///|
priv enum ElkLayeredCrossingLocalRefinementKernel {
  AdjacentSwap
  RankPermutation
}

///|
priv enum ElkLayeredCrossingLocalRefinementProfile {
  DefaultLocalRefinementProfile
  NoLocalRefinement
  AdjacentSwapOnly
  RankPermutationOnly
  AdjacentSwapThenRankPermutation
}

///|
priv enum ElkLayeredCrossingTrialContinuationPolicy {
  ContinueWhilePassChanges
  ContinueWhileObjectiveImproves
}

///|
fn default_crossing_trial_continuation_policy() -> ElkLayeredCrossingTrialContinuationPolicy {
  available_crossing_trial_continuation_policies()[0]
}

///|
fn available_crossing_trial_continuation_policies() -> Array[
  ElkLayeredCrossingTrialContinuationPolicy,
] {
  [ContinueWhilePassChanges, ContinueWhileObjectiveImproves]
}

///|
fn crossing_trial_continuation_policy_tag(
  trial_continuation_policy : ElkLayeredCrossingTrialContinuationPolicy,
) -> String {
  match trial_continuation_policy {
    ContinueWhilePassChanges => "while-pass-changes"
    ContinueWhileObjectiveImproves => "while-objective-improves"
  }
}

///|
fn default_crossing_sweep_kernel() -> ElkLayeredCrossingSweepKernel {
  available_crossing_sweep_kernels()[0]
}

///|
fn available_crossing_sweep_kernels() -> Array[ElkLayeredCrossingSweepKernel] {
  [
    NeighborMeanBidirectional,
    NeighborMedianBidirectional,
    NeighborMeanEdgeSlotBidirectional,
    NeighborMeanPortRankBidirectional,
  ]
}

///|
fn crossing_sweep_kernel_tag(
  sweep_kernel : ElkLayeredCrossingSweepKernel,
) -> String {
  match sweep_kernel {
    NeighborMeanBidirectional => "neighbor-mean-bidirectional"
    NeighborMedianBidirectional => "neighbor-median-bidirectional"
    NeighborMeanEdgeSlotBidirectional => "neighbor-mean-edge-slot-bidirectional"
    NeighborMeanPortRankBidirectional => "neighbor-mean-port-rank-bidirectional"
  }
}

///|
fn default_crossing_local_refinement_profile() -> ElkLayeredCrossingLocalRefinementProfile {
  available_crossing_local_refinement_profiles()[0]
}

///|
fn available_crossing_local_refinement_profiles() -> Array[
  ElkLayeredCrossingLocalRefinementProfile,
] {
  [
    DefaultLocalRefinementProfile,
    NoLocalRefinement,
    AdjacentSwapOnly,
    RankPermutationOnly,
    AdjacentSwapThenRankPermutation,
  ]
}

///|
fn crossing_local_refinement_kernel_tag(
  kernel : ElkLayeredCrossingLocalRefinementKernel,
) -> String {
  match kernel {
    AdjacentSwap => "adjacent-swap"
    RankPermutation => "rank-permutation"
  }
}

///|
fn crossing_local_refinement_kernels_tag(
  kernels : Array[ElkLayeredCrossingLocalRefinementKernel],
) -> String {
  if kernels.length() == 0 {
    return "none"
  }
  let tags : Array[String] = []
  for kernel in kernels {
    tags.push(crossing_local_refinement_kernel_tag(kernel))
  }
  tags.join(",")
}

///|
priv struct ElkLayeredCrossingOptimizationConfig {
  preserve_order_node_threshold : Int
  preserve_order_edge_threshold : Int
  sweep_pass_count : Int
  trial_count : Int
  trial_random_seed : Int
  trial_continuation_policy : ElkLayeredCrossingTrialContinuationPolicy
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
    trial_continuation_policy: default_crossing_trial_continuation_policy(),
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
  crossing_local_refinement_kernels_for_profile(
    default_crossing_local_refinement_profile(),
  )
}

///|
fn crossing_local_refinement_kernels_for_profile(
  profile : ElkLayeredCrossingLocalRefinementProfile,
) -> Array[ElkLayeredCrossingLocalRefinementKernel] {
  match profile {
    DefaultLocalRefinementProfile => [AdjacentSwap, RankPermutation]
    NoLocalRefinement => []
    AdjacentSwapOnly => [AdjacentSwap]
    RankPermutationOnly => [RankPermutation]
    AdjacentSwapThenRankPermutation => [AdjacentSwap, RankPermutation]
  }
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
