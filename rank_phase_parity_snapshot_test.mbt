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
fn collect_rank_layers_from_setup(
  setup_state : @layout_legacy_setup.LegacyLayoutSetupState,
) -> Array[Array[String]] {
  let rank_by_node_id = setup_state.lane_state.flow_rank_by_node_id
  let layers : Array[Array[String]] = []
  let max_rank = setup_state.lane_state.flow_max_rank
  for _ in 0..<=max_rank {
    layers.push([])
  }
  for node in setup_state.nodes_in_order {
    let rank = match rank_by_node_id.get(node.id) {
      Some(value) => value
      None => 0
    }
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
fn rank_layers_to_section(
  title : String,
  layers : Array[Array[String]],
) -> String {
  let lines : Array[String] = []
  for rank, layer in layers {
    let joined = layer.join(",")
    lines.push("r\{rank}: [\{joined}]")
  }
  let body = if lines.length() == 0 { "(none)" } else { lines.join("\n") }
  ["[\{title}]", body].join("\n")
}

///|
fn rank_layer_mismatch_lines(
  local_layers : Array[Array[String]],
  official_layers : Array[Array[String]],
) -> Array[String] {
  let mismatches : Array[String] = []
  let max_layer_count = local_layers.length().max(official_layers.length())
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
      let local_joined = local_layer.join(",")
      let official_joined = official_layer.join(",")
      mismatches.push(
        "r\{rank}: local=[\{local_joined}] official=[\{official_joined}]",
      )
    }
  }
  mismatches
}

///|
fn official_layers_layout_stress_006() -> Array[Array[String]] {
  [
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
  ]
}

///|
fn official_layers_layout_stress_012() -> Array[Array[String]] {
  [
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
  ]
}

///|
fn official_layers_layout_stress_003() -> Array[Array[String]] {
  [
    ["SRC"],
    ["L1"],
    ["L2"],
    ["L3"],
    ["L4"],
    ["L5"],
    ["M4"],
    ["M5"],
    ["M2"],
    ["M3", "R1"],
    ["R2"],
    ["R3"],
    ["R4"],
    ["M1"],
    ["R5"],
    ["SNK"],
  ]
}

///|
async fn snapshot_rank_phase_parity(
  it : @test.Test,
  fixture_path : String,
  snapshot_filename : String,
  official_layers : Array[Array[String]],
) -> Unit {
  let source = @fs.read_file(fixture_path).text()
  let graph = @parser_header_core.parse_mermaid(source.trim_end().to_string())
  let setup_state = @layout_legacy_setup.build_legacy_layout_setup(
    graph,
    @model.RenderOptions::default(),
    true,
    false,
  )
  let local_layers = collect_rank_layers_from_setup(setup_state)
  let normalized_official_layers = normalized_rank_layers(official_layers)

  let local_rank_by_node_id = build_rank_index_by_node_id(local_layers)
  let official_rank_by_node_id = build_rank_index_by_node_id(
    normalized_official_layers,
  )
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

  let mismatch_lines = rank_layer_mismatch_lines(
    local_layers, normalized_official_layers,
  )
  let mismatch_section = if mismatch_lines.length() == 0 {
    ["[composition_mismatch]", "(none)"].join("\n")
  } else {
    ["[composition_mismatch]", mismatch_lines.join("\n")].join("\n")
  }
  let summary_section = [
    "[summary]",
    "shared_nodes=\{shared_node_count}",
    "exact_matches=\{exact_match_count}",
    "displacement_sum=\{displacement_sum}",
    "composition_mismatch_count=\{mismatch_lines.length()}",
  ].join("\n")
  let official_section = rank_layers_to_section(
    "official_layers", normalized_official_layers,
  )
  let local_section = rank_layers_to_section("local_layers", local_layers)
  let snapshot = [
    "[fixture]",
    "path=\{fixture_path}",
    "local_layer_count=\{local_layers.length()}",
    "official_layer_count=\{normalized_official_layers.length()}",
    "",
    official_section,
    "",
    local_section,
    "",
    mismatch_section,
    "",
    summary_section,
  ].join("\n")
  it.write(snapshot)
  it.snapshot(filename=snapshot_filename)
}

///|
async test "Rank phase parity snapshot: layout_stress_006 nested bridge loops" (
  it : @test.Test,
) {
  snapshot_rank_phase_parity(
    it,
    "fixtures/layout_stress_006_nested_bridge_loops.mmd",
    "rank_phase_parity_layout_stress_006.txt",
    official_layers_layout_stress_006(),
  )
}

///|
async test "Rank phase parity snapshot: layout_stress_012 interleaved subgraph feedback" (
  it : @test.Test,
) {
  snapshot_rank_phase_parity(
    it,
    "fixtures/layout_stress_012_interleaved_subgraph_feedback.mmd",
    "rank_phase_parity_layout_stress_012.txt",
    official_layers_layout_stress_012(),
  )
}

///|
async test "Rank phase parity snapshot: layout_stress_003 subgraph bridges" (
  it : @test.Test,
) {
  snapshot_rank_phase_parity(
    it,
    "fixtures/layout_stress_003_subgraph_bridges.mmd",
    "rank_phase_parity_layout_stress_003.txt",
    official_layers_layout_stress_003(),
  )
}
