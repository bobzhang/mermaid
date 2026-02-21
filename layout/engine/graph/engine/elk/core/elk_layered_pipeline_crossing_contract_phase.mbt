///|
priv struct ElkLayeredCrossingPhaseInput {
  rank_node_ids_by_rank : Map[Int, Array[String]]
  max_rank : Int
  predecessors_by_node_id : Map[String, Array[String]]
  successors_by_node_id : Map[String, Array[String]]
  order_index_by_node_id : Map[String, Int]
  rank_by_node_id : Map[String, Int]
  node_count : Int
  edge_count : Int
  // Reserved for future port-aware crossing objective alignment.
  port_order_slots_by_node_id : Map[String, Array[Int]]
}

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

///|
fn build_default_port_order_slots_by_node_id(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
) -> Map[String, Array[Int]] {
  let port_order_slots_by_node_id : Map[String, Array[Int]] = {}
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) =>
        for node_id in node_ids {
          port_order_slots_by_node_id[node_id] = []
        }
      None => ()
    }
  }
  port_order_slots_by_node_id
}

///|
fn build_crossing_phase_input(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
  rank_by_node_id : Map[String, Int],
  node_count : Int,
  edge_count : Int,
) -> ElkLayeredCrossingPhaseInput {
  {
    rank_node_ids_by_rank,
    max_rank,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    rank_by_node_id,
    node_count,
    edge_count,
    port_order_slots_by_node_id: build_default_port_order_slots_by_node_id(
      rank_node_ids_by_rank, max_rank,
    ),
  }
}

///|
priv struct ElkLayeredCrossingSweepInput {
  rank_node_ids_by_rank : Map[Int, Array[String]]
  max_rank : Int
  predecessors_by_node_id : Map[String, Array[String]]
  successors_by_node_id : Map[String, Array[String]]
  order_index_by_node_id : Map[String, Int]
  preserve_current_order_on_tie : Bool
}

///|
fn build_crossing_sweep_input(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  predecessors_by_node_id : Map[String, Array[String]],
  successors_by_node_id : Map[String, Array[String]],
  order_index_by_node_id : Map[String, Int],
  preserve_current_order_on_tie : Bool,
) -> ElkLayeredCrossingSweepInput {
  {
    rank_node_ids_by_rank,
    max_rank,
    predecessors_by_node_id,
    successors_by_node_id,
    order_index_by_node_id,
    preserve_current_order_on_tie,
  }
}

///|
fn crossing_preserve_current_order_on_tie(
  node_count : Int,
  edge_count : Int,
  config : ElkLayeredCrossingOptimizationConfig,
) -> Bool {
  node_count > config.preserve_order_node_threshold ||
  edge_count > config.preserve_order_edge_threshold
}

///|
fn build_crossing_sweep_input_from_phase_input(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  input : ElkLayeredCrossingPhaseInput,
  config : ElkLayeredCrossingOptimizationConfig,
) -> ElkLayeredCrossingSweepInput {
  build_crossing_sweep_input(
    rank_node_ids_by_rank,
    input.max_rank,
    input.predecessors_by_node_id,
    input.successors_by_node_id,
    input.order_index_by_node_id,
    crossing_preserve_current_order_on_tie(
      input.node_count,
      input.edge_count,
      config,
    ),
  )
}
