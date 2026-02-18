///|
priv struct RankLayerParityMetrics {
  shared_node_count : Int
  exact_match_count : Int
  displacement_sum : Int
  composition_mismatch_count : Int
}

///|
fn parity_score(metrics : RankLayerParityMetrics) -> Int {
  metrics.composition_mismatch_count * 10 + metrics.displacement_sum
}

///|
fn int_abs(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
fn normalized_rank_layers(
  layers : Array[Array[String]],
) -> Array[Array[String]] {
  let normalized : Array[Array[String]] = []
  for layer in layers {
    let sorted_layer = layer.copy()
    sorted_layer.sort()
    normalized.push(sorted_layer)
  }
  normalized
}

///|
fn build_rank_index_by_node_id(
  layers : Array[Array[String]],
) -> Map[String, Int] {
  let rank_by_node_id : Map[String, Int] = {}
  for rank, layer in layers {
    for node_id in layer {
      rank_by_node_id[node_id] = rank
    }
  }
  rank_by_node_id
}

///|
fn rank_layer_mismatch_count(
  local_layers : Array[Array[String]],
  official_layers : Array[Array[String]],
) -> Int {
  let max_layer_count = local_layers.length().max(official_layers.length())
  let mut mismatch_count = 0
  for rank in 0..<max_layer_count {
    let local_layer = if rank < local_layers.length() {
      local_layers[rank]
    } else {
      []
    }
    let official_layer = if rank < official_layers.length() {
      official_layers[rank]
    } else {
      []
    }
    let mut same = local_layer.length() == official_layer.length()
    if same {
      for i in 0..<local_layer.length() {
        if local_layer[i] != official_layer[i] {
          same = false
          break
        }
      }
    }
    if !same {
      mismatch_count += 1
    }
  }
  mismatch_count
}

///|
fn collect_rank_layers_from_seed_state(
  nodes_in_order : Array[@model.MermaidNode],
  rank_seed_state : ElkLayeredRankSeedState,
) -> Array[Array[String]] {
  let rank_by_node_id = rank_seed_state.rank_by_node_id
  let max_rank = rank_seed_state.max_rank
  let layers : Array[Array[String]] = []
  for _ in 0..<=max_rank {
    layers.push([])
  }
  for node in nodes_in_order {
    let rank = option_int_or(rank_by_node_id.get(node.id), 0)
    if rank < 0 {
      continue
    }
    if rank >= layers.length() {
      for _ in layers.length()..<=rank {
        layers.push([])
      }
    }
    layers[rank].push(node.id)
  }
  normalized_rank_layers(layers)
}

///|
fn compute_rank_layer_parity(
  local_layers : Array[Array[String]],
  official_layers : Array[Array[String]],
) -> RankLayerParityMetrics {
  let local_rank_by_node_id = build_rank_index_by_node_id(local_layers)
  let official_rank_by_node_id = build_rank_index_by_node_id(official_layers)
  let mut shared_node_count = 0
  let mut exact_match_count = 0
  let mut displacement_sum = 0
  for node_id, official_rank in official_rank_by_node_id {
    match local_rank_by_node_id.get(node_id) {
      Some(local_rank) => {
        shared_node_count += 1
        if local_rank == official_rank {
          exact_match_count += 1
        }
        displacement_sum += int_abs(local_rank - official_rank)
      }
      None => ()
    }
  }
  let composition_mismatch_count = rank_layer_mismatch_count(
    local_layers, official_layers,
  )
  {
    shared_node_count,
    exact_match_count,
    displacement_sum,
    composition_mismatch_count,
  }
}

///|
fn stress_006_source() -> String {
  (
    #|graph TB
    #|SRC[SRC]
    #|SNK[SNK]
    #|
    #|subgraph LEFT_CLUSTER
    #|L0[L0]
    #|L1[L1]
    #|L2[L2]
    #|subgraph LEFT_INNER
    #|LI1[LI1]
    #|LI2[LI2]
    #|LI3[LI3]
    #|end
    #|L3[L3]
    #|L4[L4]
    #|end
    #|
    #|subgraph RIGHT_CLUSTER
    #|R0[R0]
    #|R1[R1]
    #|R2[R2]
    #|subgraph RIGHT_INNER
    #|RI1[RI1]
    #|RI2[RI2]
    #|RI3[RI3]
    #|end
    #|R3[R3]
    #|R4[R4]
    #|end
    #|
    #|SRC --> L0
    #|SRC --> R0
    #|
    #|L0 --> L1
    #|L1 --> L2
    #|L2 --> L3
    #|L3 --> L4
    #|L4 --> SNK
    #|
    #|R0 --> R1
    #|R1 --> R2
    #|R2 --> R3
    #|R3 --> R4
    #|R4 --> SNK
    #|
    #|L1 --> LI1
    #|LI1 --> LI2
    #|LI2 --> LI3
    #|LI3 --> L3
    #|
    #|R1 --> RI1
    #|RI1 --> RI2
    #|RI2 --> RI3
    #|RI3 --> R3
    #|
    #|LI1 --> RI2
    #|LI2 --> R2
    #|L2 --> RI1
    #|L3 --> R1
    #|
    #|RI1 --> LI3
    #|R2 --> LI2
    #|RI3 --> L1
    #|R3 --> L2
    #|
    #|L4 --> RI3
    #|R4 --> LI3
    #|SNK --> LI1
    #|
  )
  .trim_end()
  .to_string()
}

///|
fn stress_012_source() -> String {
  (
    #|graph LR
    #|SRC[SRC]
    #|SNK[SNK]
    #|
    #|subgraph LEFT_FLOW
    #|L1[L1]
    #|L2[L2]
    #|L3[L3]
    #|L4[L4]
    #|subgraph LEFT_CORE
    #|LC1[LC1]
    #|LC2[LC2]
    #|LC3[LC3]
    #|end
    #|L5[L5]
    #|L6[L6]
    #|end
    #|
    #|subgraph MID_FLOW
    #|M1[M1]
    #|M2[M2]
    #|M3[M3]
    #|M4[M4]
    #|M5[M5]
    #|M6[M6]
    #|end
    #|
    #|subgraph RIGHT_FLOW
    #|R1[R1]
    #|R2[R2]
    #|R3[R3]
    #|R4[R4]
    #|subgraph RIGHT_CORE
    #|RC1[RC1]
    #|RC2[RC2]
    #|RC3[RC3]
    #|end
    #|R5[R5]
    #|R6[R6]
    #|end
    #|
    #|SRC --> L1
    #|SRC --> M1
    #|SRC --> R1
    #|
    #|L1 --> L2
    #|L2 --> L3
    #|L3 --> L4
    #|L4 --> L5
    #|L5 --> L6
    #|
    #|R1 --> R2
    #|R2 --> R3
    #|R3 --> R4
    #|R4 --> R5
    #|R5 --> R6
    #|
    #|M1 --> M2
    #|M2 --> M3
    #|M3 --> M4
    #|M4 --> M5
    #|M5 --> M6
    #|
    #|L2 --> LC1
    #|LC1 --> LC2
    #|LC2 --> LC3
    #|LC3 --> L5
    #|
    #|R2 --> RC1
    #|RC1 --> RC2
    #|RC2 --> RC3
    #|RC3 --> R5
    #|
    #|L3 --> M2
    #|L4 --> M3
    #|L5 --> M4
    #|LC2 --> M5
    #|
    #|M2 --> R2
    #|M3 --> R3
    #|M4 --> R4
    #|M5 --> R5
    #|
    #|R3 --> M2
    #|R4 --> M3
    #|R5 --> M4
    #|RC2 --> M5
    #|
    #|M3 --> LC1
    #|M4 --> LC2
    #|M5 --> LC3
    #|
    #|M2 --> RC1
    #|M3 --> RC2
    #|M4 --> RC3
    #|
    #|L6 --> SNK
    #|M6 --> SNK
    #|R6 --> SNK
    #|
    #|R6 --> L3
    #|M6 --> L2
    #|M6 --> R2
    #|LC3 --> R1
    #|RC3 --> L1
    #|R4 --> LC2
    #|L4 --> RC2
    #|SNK --> M3
    #|SNK --> L4
    #|SNK --> R4
    #|
  )
  .trim_end()
  .to_string()
}

///|
fn official_layers_stress_006() -> Array[Array[String]] {
  normalized_rank_layers([
    ["SRC"],
    ["L0"],
    ["L1"],
    ["L2"],
    ["L3"],
    ["L4", "R0"],
    ["R1", "SNK"],
    ["LI1", "RI1"],
    ["LI2", "RI2"],
    ["R2", "RI3"],
    ["R3"],
    ["R4"],
    ["LI3"],
  ])
}

///|
fn official_layers_stress_012() -> Array[Array[String]] {
  normalized_rank_layers([
    ["SRC"],
    ["L1"],
    ["L2"],
    ["L3"],
    ["L4"],
    ["L5"],
    ["L6"],
    ["SNK"],
    ["M3"],
    ["M4"],
    ["M5"],
    ["M6"],
    ["R2"],
    ["M1", "R3"],
    ["LC1", "M2", "R4"],
    ["LC2", "RC1"],
    ["LC3", "RC2"],
    ["R1", "RC3"],
    ["R5"],
    ["R6"],
  ])
}

///|
fn build_seed_parity_metrics_for_source(
  source : String,
  official_layers : Array[Array[String]],
) -> (
  ElkLayeredRankSeedState,
  ElkLayeredRankSeedState,
  RankLayerParityMetrics,
  RankLayerParityMetrics,
) raise {
  let graph = @parser_header_core.parse_mermaid(source)
  let setup_state = run_elk_layered_setup_phase({
    graph,
    options: @model.RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  })
  let legacy_state = build_elk_layered_rank_seed_state(
    graph,
    LegacyLaneSeed,
    setup_state.use_subgraph_redirects,
    setup_state.subgraph_entry_by_id,
    setup_state.subgraph_exit_by_id,
    setup_state.nodes_in_order,
    setup_state.node_ids_in_order,
    setup_state.base_order_index_by_node_id,
    setup_state.horizontal,
    setup_state.compact_fanin,
  )
  let native_state = build_elk_layered_rank_seed_state(
    graph,
    NativeFeedback,
    setup_state.use_subgraph_redirects,
    setup_state.subgraph_entry_by_id,
    setup_state.subgraph_exit_by_id,
    setup_state.nodes_in_order,
    setup_state.node_ids_in_order,
    setup_state.base_order_index_by_node_id,
    setup_state.horizontal,
    setup_state.compact_fanin,
  )
  let legacy_layers = collect_rank_layers_from_seed_state(
    setup_state.nodes_in_order,
    legacy_state,
  )
  let native_layers = collect_rank_layers_from_seed_state(
    setup_state.nodes_in_order,
    native_state,
  )
  let legacy_metrics = compute_rank_layer_parity(legacy_layers, official_layers)
  let native_metrics = compute_rank_layer_parity(native_layers, official_layers)
  (legacy_state, native_state, legacy_metrics, native_metrics)
}

///|
fn assert_legacy_seed_not_worse_than_native_for_fixture(
  fixture_name : String,
  legacy_metrics : RankLayerParityMetrics,
  native_metrics : RankLayerParityMetrics,
) -> Unit raise {
  if legacy_metrics.shared_node_count != native_metrics.shared_node_count {
    fail(
      "shared node mismatch for \{fixture_name}: legacy=\{legacy_metrics.shared_node_count} native=\{native_metrics.shared_node_count}",
    )
  }
  if parity_score(legacy_metrics) > parity_score(native_metrics) {
    fail(
      "legacy rank parity worse on \{fixture_name}: legacy(score=\{parity_score(legacy_metrics)} disp=\{legacy_metrics.displacement_sum} mismatch=\{legacy_metrics.composition_mismatch_count}) native(score=\{parity_score(native_metrics)} disp=\{native_metrics.displacement_sum} mismatch=\{native_metrics.composition_mismatch_count})",
    )
  }
}

///|
test "elk layered rank parity selector baseline is not worse than native on stress_006" {
  let (_, _, legacy_metrics, native_metrics) = build_seed_parity_metrics_for_source(
    stress_006_source(),
    official_layers_stress_006(),
  )
  assert_legacy_seed_not_worse_than_native_for_fixture(
    "stress_006", legacy_metrics, native_metrics,
  )
  assert_eq(legacy_metrics.shared_node_count, 18)
  assert_true(legacy_metrics.exact_match_count > 0)
}

///|
test "elk layered rank parity selector baseline is not worse than native on stress_012" {
  let (_, _, legacy_metrics, native_metrics) = build_seed_parity_metrics_for_source(
    stress_012_source(),
    official_layers_stress_012(),
  )
  assert_legacy_seed_not_worse_than_native_for_fixture(
    "stress_012", legacy_metrics, native_metrics,
  )
  assert_eq(legacy_metrics.shared_node_count, 26)
  assert_true(legacy_metrics.exact_match_count > 0)
}
