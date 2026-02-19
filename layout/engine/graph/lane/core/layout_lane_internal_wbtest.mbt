///|
fn flow_edge(source : String, target : String) -> MermaidEdge {
  {
    source,
    target,
    label: None,
    style: Solid,
    has_arrow_start: false,
    has_arrow_end: true,
    relation_operator: Some("-->"),
  }
}

///|
fn lane_policy_graph(
  direction : @model.Direction,
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
  subgraphs : Array[MermaidSubgraph],
) -> MermaidGraph {
  let nodes : Map[String, MermaidNode] = {}
  for node in nodes_in_order {
    nodes[node.id] = node
  }
  {
    diagram_kind: Flowchart,
    direction,
    nodes,
    edges,
    subgraphs,
    class_defs: {},
    class_assignments: {},
    node_styles: {},
    sequence_actor_order: [],
    sequence_actor_kinds: {},
    sequence_blocks: [],
    sequence_notes: [],
    sequence_activation_commands: [],
  }
}

///|
fn sorted_int_array(values : Array[Int]) -> Array[Int] {
  let sorted = values.copy()
  sorted.sort()
  sorted
}

///|
fn sorted_string_array(values : Array[String]) -> Array[String] {
  let sorted = values.copy()
  sorted.sort()
  sorted
}

///|
fn collect_rank_orders_from_lanes(
  nodes_in_order : Array[MermaidNode],
  rank_by_id : Map[String, Int],
  lane_by_id : Map[String, Int],
  max_rank : Int,
) -> Array[Array[String]] {
  let rank_orders : Array[Array[String]] = []
  for rank in 0..<=max_rank {
    let node_ids : Array[String] = []
    for node in nodes_in_order {
      if option_int_or(rank_by_id.get(node.id), -1) == rank {
        node_ids.push(node.id)
      }
    }
    node_ids.sort_by((left_id, right_id) => {
      let left_lane = option_int_or(lane_by_id.get(left_id), 0)
      let right_lane = option_int_or(lane_by_id.get(right_id), 0)
      let lane_cmp = left_lane.compare(right_lane)
      if lane_cmp != 0 {
        lane_cmp
      } else {
        left_id.compare(right_id)
      }
    })
    rank_orders.push(node_ids)
  }
  rank_orders
}

///|
fn option_edge_index_count(indices : Array[Int]?) -> Int {
  match indices {
    Some(found) => found.length()
    None => 0
  }
}

///|
fn active_tree_edge_keys_from_seed_state(
  nodes_in_order : Array[MermaidNode],
  seed_state : DagreNetworkSimplexSeedState,
) -> Array[String] {
  let keys : Array[String] = []
  for tree_edge_index in 0..<seed_state.tree_edge_u.length() {
    if !seed_state.tree_edge_active[tree_edge_index] {
      continue
    }
    let left_id = nodes_in_order[seed_state.tree_edge_u[tree_edge_index]].id
    let right_id = nodes_in_order[seed_state.tree_edge_v[tree_edge_index]].id
    let normalized_key = if left_id < right_id {
      "\{left_id}->\{right_id}"
    } else {
      "\{right_id}->\{left_id}"
    }
    keys.push(normalized_key)
  }
  keys
}

///|
fn normalized_node_pair_key(left_id : String, right_id : String) -> String {
  if left_id < right_id {
    "\{left_id}->\{right_id}"
  } else {
    "\{right_id}->\{left_id}"
  }
}

///|
fn normalized_tree_edge_key_from_seed_state(
  nodes_in_order : Array[MermaidNode],
  seed_state : DagreNetworkSimplexSeedState,
  tree_edge_index : Int,
) -> String {
  let left_id = nodes_in_order[seed_state.tree_edge_u[tree_edge_index]].id
  let right_id = nodes_in_order[seed_state.tree_edge_v[tree_edge_index]].id
  normalized_node_pair_key(left_id, right_id)
}

///|
fn directed_graph_edge_key_from_index(
  nodes_in_order : Array[MermaidNode],
  prepared_graph : DagreNetworkSimplexPreparedGraph,
  edge_index : Int,
) -> String {
  let source_id = nodes_in_order[prepared_graph.edge_source_index[edge_index]].id
  let target_id = nodes_in_order[prepared_graph.edge_target_index[edge_index]].id
  "\{source_id}->\{target_id}"
}

///|
fn active_tree_cut_entries_from_cut_phase(
  nodes_in_order : Array[MermaidNode],
  seed_state : DagreNetworkSimplexSeedState,
  cut_phase_state : DagreNetworkSimplexCutPhaseState,
) -> Map[String, Int] {
  let entries : Map[String, Int] = {}
  for tree_edge_index in 0..<seed_state.tree_edge_u.length() {
    if !seed_state.tree_edge_active[tree_edge_index] {
      continue
    }
    let key = normalized_tree_edge_key_from_seed_state(
      nodes_in_order, seed_state, tree_edge_index,
    )
    entries[key] = cut_phase_state.tree_edge_cutvalue[tree_edge_index]
  }
  entries
}

///|
fn active_tree_cut_entries_from_exchange_step(
  nodes_in_order : Array[MermaidNode],
  exchange_step : DagreNetworkSimplexExchangeStep,
) -> Map[String, Int] {
  let entries : Map[String, Int] = {}
  for tree_edge_index in 0..<exchange_step.tree_edge_u.length() {
    if !exchange_step.tree_edge_active[tree_edge_index] {
      continue
    }
    let left_id = nodes_in_order[exchange_step.tree_edge_u[tree_edge_index]].id
    let right_id = nodes_in_order[exchange_step.tree_edge_v[tree_edge_index]].id
    let key = normalized_node_pair_key(left_id, right_id)
    entries[key] = exchange_step.tree_edge_cutvalue[tree_edge_index]
  }
  entries
}

///|
fn normalized_leave_tree_edge_key_from_exchange_step(
  nodes_in_order : Array[MermaidNode],
  exchange_step : DagreNetworkSimplexExchangeStep,
) -> String {
  normalized_node_pair_key(
    nodes_in_order[exchange_step.leave_tree_edge_u].id,
    nodes_in_order[exchange_step.leave_tree_edge_v].id,
  )
}

///|
fn directed_enter_graph_edge_key_from_exchange_step(
  nodes_in_order : Array[MermaidNode],
  exchange_step : DagreNetworkSimplexExchangeStep,
) -> String {
  let source_id = nodes_in_order[exchange_step.enter_graph_edge_source].id
  let target_id = nodes_in_order[exchange_step.enter_graph_edge_target].id
  "\{source_id}->\{target_id}"
}

///|
fn map_string_int_entry_count(entries : Map[String, Int]) -> Int {
  let mut count = 0
  for _, _ in entries {
    count += 1
  }
  count
}

///|
fn sorted_back_edge_indices(back_edges : Map[Int, Bool]) -> Array[Int] {
  let indices : Array[Int] = []
  for edge_index, _ in back_edges {
    indices.push(edge_index)
  }
  sorted_int_array(indices)
}

///|
fn fixture_nodes_and_edges_for_acyclic_phase(
  source : String,
) -> (Array[MermaidNode], Array[MermaidEdge]) raise {
  let (graph, nodes_in_order) = fixture_graph_and_nodes_for_flow_layout(source)
  (nodes_in_order, graph.edges)
}

///|
fn fixture_graph_and_nodes_for_flow_layout(
  source : String,
) -> (MermaidGraph, Array[MermaidNode]) raise {
  let graph = @parser.parse_mermaid(source.trim_end().to_string())
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, true,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order,
    graph.edges,
  )
  (graph, nodes_in_order)
}

///|
fn edge_key_from_index(edges : Array[MermaidEdge], edge_index : Int) -> String {
  let edge = edges[edge_index]
  "\{edge.source}->\{edge.target}"
}

///|
fn reversed_back_edge_keys(
  edges : Array[MermaidEdge],
  reversed_back_edge_indices : Array[Int],
) -> Array[String] {
  let keys : Array[String] = []
  for edge_index in reversed_back_edge_indices {
    keys.push(edge_key_from_index(edges, edge_index))
  }
  sorted_string_array(keys)
}

///|
fn stress_003_subgraph_bridges_source() -> String {
  (
    #|graph LR
    #|SRC[SRC]
    #|SNK[SNK]
    #|
    #|subgraph LEFT
    #|L1[L1]
    #|L2[L2]
    #|L3[L3]
    #|L4[L4]
    #|L5[L5]
    #|end
    #|
    #|subgraph MID
    #|M1[M1]
    #|M2[M2]
    #|M3[M3]
    #|M4[M4]
    #|M5[M5]
    #|end
    #|
    #|subgraph RIGHT
    #|R1[R1]
    #|R2[R2]
    #|R3[R3]
    #|R4[R4]
    #|R5[R5]
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
    #|L5 --> L2
    #|
    #|M1 --> M2
    #|M2 --> M3
    #|M3 --> M4
    #|M4 --> M5
    #|M5 --> M2
    #|
    #|R1 --> R2
    #|R2 --> R3
    #|R3 --> R4
    #|R4 --> R5
    #|R5 --> R2
    #|
    #|L2 --> M1
    #|L3 --> M2
    #|L4 --> M3
    #|L5 --> M4
    #|L1 --> M5
    #|
    #|M2 --> R1
    #|M3 --> R2
    #|M4 --> R3
    #|M5 --> R4
    #|M1 --> R5
    #|
    #|R4 --> M1
    #|R3 --> L2
    #|M3 --> L1
    #|R2 --> L4
    #|
    #|L5 --> SNK
    #|M5 --> SNK
    #|R5 --> SNK
    #|SNK --> M2
    #|
  )
  .trim_end()
  .to_string()
}

///|
fn stress_005_long_span_backjumps_source() -> String {
  (
    #|graph LR
    #|S[S]
    #|T[T]
    #|A1[A1]
    #|A2[A2]
    #|A3[A3]
    #|B1[B1]
    #|B2[B2]
    #|B3[B3]
    #|C1[C1]
    #|C2[C2]
    #|C3[C3]
    #|D1[D1]
    #|D2[D2]
    #|D3[D3]
    #|E1[E1]
    #|E2[E2]
    #|E3[E3]
    #|
    #|S --> A1
    #|S --> A2
    #|S --> A3
    #|
    #|A1 --> B1
    #|A2 --> B2
    #|A3 --> B3
    #|
    #|B1 --> C1
    #|B2 --> C2
    #|B3 --> C3
    #|
    #|C1 --> D1
    #|C2 --> D2
    #|C3 --> D3
    #|
    #|D1 --> E1
    #|D2 --> E2
    #|D3 --> E3
    #|
    #|E1 --> T
    #|E2 --> T
    #|E3 --> T
    #|
    #|A1 --> D2
    #|A2 --> D3
    #|A3 --> D1
    #|B1 --> E2
    #|B2 --> E3
    #|B3 --> E1
    #|A1 --> E3
    #|A3 --> E2
    #|S --> C2
    #|S --> D3
    #|
    #|E3 --> B1
    #|E2 --> B3
    #|D3 --> A2
    #|C3 --> A1
    #|D1 --> C2
    #|T --> C1
    #|
  )
  .trim_end()
  .to_string()
}

///|
fn stress_006_nested_bridge_loops_source() -> String {
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
fn stress_010_bipartite_crossfire_source() -> String {
  (
    #|graph LR
    #|U1[U1]
    #|U2[U2]
    #|U3[U3]
    #|U4[U4]
    #|U5[U5]
    #|U6[U6]
    #|
    #|H1[H1]
    #|H2[H2]
    #|H3[H3]
    #|H4[H4]
    #|
    #|T1[T1]
    #|T2[T2]
    #|T3[T3]
    #|T4[T4]
    #|T5[T5]
    #|T6[T6]
    #|
    #|M1[M1]
    #|M2[M2]
    #|M3[M3]
    #|M4[M4]
    #|
    #|Z1[Z1]
    #|Z2[Z2]
    #|Z3[Z3]
    #|Z4[Z4]
    #|
    #|U1 --> H1
    #|U1 --> H2
    #|U2 --> H1
    #|U2 --> H3
    #|U3 --> H2
    #|U3 --> H4
    #|U4 --> H3
    #|U4 --> H4
    #|U5 --> H1
    #|U5 --> H4
    #|U6 --> H2
    #|U6 --> H3
    #|
    #|H1 --> T1
    #|H1 --> T2
    #|H1 --> T4
    #|H2 --> T2
    #|H2 --> T3
    #|H2 --> T5
    #|H3 --> T1
    #|H3 --> T4
    #|H3 --> T6
    #|H4 --> T3
    #|H4 --> T5
    #|H4 --> T6
    #|
    #|U1 --> T5
    #|U2 --> T6
    #|U3 --> T1
    #|U4 --> T2
    #|U5 --> T3
    #|U6 --> T4
    #|
    #|T1 --> M1
    #|T1 --> M2
    #|T2 --> M1
    #|T2 --> M3
    #|T3 --> M2
    #|T3 --> M4
    #|T4 --> M1
    #|T4 --> M4
    #|T5 --> M2
    #|T5 --> M3
    #|T6 --> M3
    #|T6 --> M4
    #|
    #|M1 --> Z1
    #|M1 --> Z2
    #|M2 --> Z2
    #|M2 --> Z3
    #|M3 --> Z3
    #|M3 --> Z4
    #|M4 --> Z1
    #|M4 --> Z4
    #|
    #|Z2 --> H2
    #|Z3 --> H3
    #|Z4 --> H1
    #|M4 --> H2
    #|T6 --> H4
    #|T5 --> H1
    #|Z1 --> T3
    #|Z4 --> T2
    #|
  )
  .trim_end()
  .to_string()
}

///|
fn stress_012_interleaved_subgraph_feedback_source() -> String {
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
fn normalize_rank_layers_for_assert(
  layers : Array[Array[String]],
) -> Array[Array[String]] {
  let normalized : Array[Array[String]] = []
  for layer in layers {
    normalized.push(sorted_string_array(layer))
  }
  normalized
}

///|
fn collect_rank_layers_from_assignment(
  nodes_in_order : Array[MermaidNode],
  rank_by_id : Map[String, Int],
  max_rank : Int,
) -> Array[Array[String]] {
  let layers : Array[Array[String]] = []
  for _ in 0..<=max_rank {
    layers.push([])
  }
  for node in nodes_in_order {
    let rank = option_int_or(rank_by_id.get(node.id), 0)
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
  normalize_rank_layers_for_assert(layers)
}

///|
fn official_layers_layout_stress_003() -> Array[Array[String]] {
  normalize_rank_layers_for_assert([
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
  ])
}

///|
fn official_layers_layout_stress_006() -> Array[Array[String]] {
  normalize_rank_layers_for_assert([
    ["SRC"],
    [],
    ["L0"],
    ["L1"],
    ["L2"],
    ["L3"],
    [],
    ["L4", "R0"],
    ["R1", "SNK"],
    [],
    ["LI1", "RI1"],
    ["LI2", "RI2"],
    ["R2", "RI3"],
    [],
    ["R3"],
    ["R4"],
    [],
    ["LI3"],
  ])
}

///|
fn official_layers_layout_stress_012() -> Array[Array[String]] {
  normalize_rank_layers_for_assert([
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
fn collect_fixture_dagre_nesting_rank_layers(
  source : String,
) -> Array[Array[String]] raise {
  let graph = @parser.parse_mermaid(source.trim_end().to_string())
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, true,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order,
    graph.edges,
  )
  let acyclic_phase_state = collect_non_state_flow_acyclic_phase_state(
    nodes_in_order,
    graph.edges,
    false,
    false,
  )
  let rank_edge_specs = collect_dagre_rank_edge_specs(
    graph.edges,
    acyclic_phase_state.relaxed_edge_indices,
    acyclic_phase_state.reversed_back_edge_indices,
  )
  let (raw_rank_by_id, raw_max_rank, rank_ok) = collect_dagre_nesting_rank_result(
    nodes_in_order,
    rank_edge_specs,
    graph.subgraphs,
  )
  if !rank_ok {
    fail("expected dagre nesting rank result")
  }
  let horizontal = @layout_engine_graph_internal_core.layout_direction_is_horizontal(
    graph.direction,
  )
  let (rank_by_id, max_rank) = if horizontal && graph.subgraphs.length() > 0 {
    densify_rank_assignment(nodes_in_order, raw_rank_by_id)
  } else {
    (raw_rank_by_id, raw_max_rank)
  }
  collect_rank_layers_from_assignment(nodes_in_order, rank_by_id, max_rank)
}

///|
fn collect_fixture_lane_state_rank_layers_for_dagre_parity(
  source : String,
) -> Array[Array[String]] raise {
  let graph = @parser.parse_mermaid(source.trim_end().to_string())
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, true,
  )
  let nodes_in_order = @layout_engine_graph_internal_core.reorder_nodes_for_flow_layout(
    prep_state.nodes_in_order,
    graph.edges,
  )
  let horizontal = @layout_engine_graph_internal_core.layout_direction_is_horizontal(
    graph.direction,
  )
  let lane_state = compute_legacy_lane_state(
    graph, nodes_in_order, false, false, horizontal, false, false, false, true,
  )
  collect_rank_layers_from_assignment(
    nodes_in_order,
    lane_state.flow_rank_by_node_id,
    lane_state.flow_max_rank,
  )
}

///|
fn collect_simplex_rank_trace_case(
  edges : Array[MermaidEdge],
) -> (Bool, Int, Int, Array[Int]) {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
    { id: "G", label: "G", shape: Rectangle },
    { id: "H", label: "H", shape: Rectangle },
  ]
  let relaxed_edge_indices : Array[Int] = []
  for edge_index in 0..<edges.length() {
    relaxed_edge_indices.push(edge_index)
  }
  let (ranks, max_rank, ok, exchange_trace) = collect_dagre_network_simplex_ranks_with_trace(
    nodes,
    edges,
    relaxed_edge_indices,
    [],
    true,
  )
  let rank_vector : Array[Int] = []
  for node in nodes {
    rank_vector.push(option_int_or(ranks.get(node.id), -1))
  }
  (ok, max_rank, exchange_trace.length(), rank_vector)
}

///|
test "Layout lane collection accounts for long-span edges via virtual segments" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "M", label: "M", shape: Rectangle },
    { id: "X", label: "X", shape: Rectangle },
    { id: "Y", label: "Y", shape: Rectangle },
  ]
  let rank_by_id : Map[String, Int] = { "A": 0, "B": 0, "M": 1, "X": 2, "Y": 2 }
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "M"),
    flow_edge("B", "M"),
    flow_edge("M", "X"),
    flow_edge("M", "Y"),
    flow_edge("A", "Y"),
    flow_edge("B", "X"),
  ]

  let lanes = collect_non_state_flow_lanes(
    nodes, rank_by_id, 2, edges, false, false, true, false,
  )
  assert_true(
    option_int_or(lanes.get("Y"), 0) < option_int_or(lanes.get("X"), 0),
  )
}

///|
test "Layout lane collection uses long-span backward edges for ordering" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]
  let rank_by_id : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "C": 1,
    "D": 1,
    "E": 3,
    "F": 3,
  }
  let edges : Array[MermaidEdge] = [
    {
      source: "F",
      target: "A",
      label: None,
      style: Dotted,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-.->"),
    },
    {
      source: "E",
      target: "B",
      label: None,
      style: Dotted,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-.->"),
    },
  ]

  let lanes = collect_non_state_flow_lanes(
    nodes, rank_by_id, 3, edges, false, false, true, false,
  )
  assert_true(
    option_int_or(lanes.get("F"), 0) < option_int_or(lanes.get("E"), 0),
  )
}

///|
test "Layout lane dagre parity ordering phase keeps corpus baseline" {
  let case1_nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "M", label: "M", shape: Rectangle },
    { id: "X", label: "X", shape: Rectangle },
    { id: "Y", label: "Y", shape: Rectangle },
  ]
  let case1_ranks : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "M": 1,
    "X": 2,
    "Y": 2,
  }
  let case1_edges : Array[MermaidEdge] = [
    flow_edge("A", "M"),
    flow_edge("B", "M"),
    flow_edge("M", "X"),
    flow_edge("M", "Y"),
    flow_edge("A", "Y"),
    flow_edge("B", "X"),
  ]
  let case1_lanes = collect_non_state_flow_lanes(
    case1_nodes, case1_ranks, 2, case1_edges, false, false, false, true,
  )
  assert_eq(
    collect_rank_orders_from_lanes(case1_nodes, case1_ranks, case1_lanes, 2),
    [["B", "A"], ["M"], ["X", "Y"]],
  )

  let case2_nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]
  let case2_ranks : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "C": 1,
    "D": 1,
    "E": 2,
    "F": 2,
  }
  let case2_edges : Array[MermaidEdge] = [
    flow_edge("A", "D"),
    flow_edge("B", "C"),
    flow_edge("A", "E"),
    flow_edge("B", "F"),
    flow_edge("C", "F"),
    flow_edge("D", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "E"),
  ]
  let case2_lanes = collect_non_state_flow_lanes(
    case2_nodes, case2_ranks, 2, case2_edges, false, false, false, true,
  )
  assert_eq(
    collect_rank_orders_from_lanes(case2_nodes, case2_ranks, case2_lanes, 2),
    [["A", "B"], ["D", "C"], ["E", "F"]],
  )

  let case3_nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
    { id: "G", label: "G", shape: Rectangle },
    { id: "H", label: "H", shape: Rectangle },
  ]
  let case3_ranks : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "C": 1,
    "D": 1,
    "E": 2,
    "F": 2,
    "G": 3,
    "H": 3,
  }
  let case3_edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("C", "E"),
    flow_edge("D", "F"),
    flow_edge("C", "F"),
    flow_edge("D", "E"),
    flow_edge("E", "G"),
    flow_edge("F", "H"),
    flow_edge("E", "H"),
    flow_edge("F", "G"),
  ]
  let case3_lanes = collect_non_state_flow_lanes(
    case3_nodes, case3_ranks, 3, case3_edges, false, false, false, true,
  )
  assert_eq(
    collect_rank_orders_from_lanes(case3_nodes, case3_ranks, case3_lanes, 3),
    [["B", "A"], ["D", "C"], ["F", "E"], ["H", "G"]],
  )
}

///|
test "Layout lane dagre parity ordering phase keeps sweep trace baseline" {
  let case1_nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "M", label: "M", shape: Rectangle },
    { id: "X", label: "X", shape: Rectangle },
    { id: "Y", label: "Y", shape: Rectangle },
  ]
  let case1_ranks : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "M": 1,
    "X": 2,
    "Y": 2,
  }
  let case1_edges : Array[MermaidEdge] = [
    flow_edge("A", "M"),
    flow_edge("B", "M"),
    flow_edge("M", "X"),
    flow_edge("M", "Y"),
    flow_edge("A", "Y"),
    flow_edge("B", "X"),
  ]
  let case1_trace : Array[Array[Array[String]]] = []
  let case1_step_trace : Array[DagreParitySweepStepTrace] = []
  let _ = collect_non_state_flow_lanes_internal(
    case1_nodes,
    case1_ranks,
    2,
    case1_edges,
    false,
    false,
    false,
    true,
    Some(case1_trace),
    Some(case1_step_trace),
  )
  assert_eq(case1_trace, [
    [["A", "B"], ["M", "__lane_dummy_f_4_1", "__lane_dummy_f_5_1"], ["X", "Y"]],
    [["B", "A"], ["__lane_dummy_f_5_1", "M", "__lane_dummy_f_4_1"], ["X", "Y"]],
    [["B", "A"], ["__lane_dummy_f_5_1", "M", "__lane_dummy_f_4_1"], ["X", "Y"]],
    [["B", "A"], ["__lane_dummy_f_5_1", "M", "__lane_dummy_f_4_1"], ["X", "Y"]],
    [["B", "A"], ["__lane_dummy_f_5_1", "M", "__lane_dummy_f_4_1"], ["X", "Y"]],
    [["B", "A"], ["__lane_dummy_f_5_1", "M", "__lane_dummy_f_4_1"], ["X", "Y"]],
  ])
  assert_eq(case1_step_trace.length(), 4)
  assert_eq(
    [
      case1_step_trace[0].pass_index,
      case1_step_trace[1].pass_index,
      case1_step_trace[2].pass_index,
      case1_step_trace[3].pass_index,
    ],
    [0, 1, 2, 3],
  )
  assert_eq(
    [
      case1_step_trace[0].incoming_from_neighbor,
      case1_step_trace[1].incoming_from_neighbor,
      case1_step_trace[2].incoming_from_neighbor,
      case1_step_trace[3].incoming_from_neighbor,
    ],
    [false, true, false, true],
  )
  assert_eq(
    [
      case1_step_trace[0].bias_right,
      case1_step_trace[1].bias_right,
      case1_step_trace[2].bias_right,
      case1_step_trace[3].bias_right,
    ],
    [false, false, true, true],
  )
  assert_eq(
    [
      case1_step_trace[0].candidate_crossings,
      case1_step_trace[1].candidate_crossings,
      case1_step_trace[2].candidate_crossings,
      case1_step_trace[3].candidate_crossings,
    ],
    [0, 0, 0, 0],
  )
  assert_eq(case1_step_trace[0].barycenters_by_rank, {
    0: { "A": "3/2", "B": "1/2" },
    1: { "M": "1/2", "__lane_dummy_f_4_1": "1/1", "__lane_dummy_f_5_1": "0/1" },
  })
  assert_eq(case1_step_trace[1].barycenters_by_rank, {
    1: { "M": "1/2", "__lane_dummy_f_4_1": "1/1", "__lane_dummy_f_5_1": "0/1" },
    2: { "X": "1/2", "Y": "3/2" },
  })
  assert_eq(
    case1_step_trace[2].barycenters_by_rank,
    case1_step_trace[0].barycenters_by_rank,
  )
  assert_eq(
    case1_step_trace[3].barycenters_by_rank,
    case1_step_trace[1].barycenters_by_rank,
  )
  for i in 0..<case1_step_trace.length() {
    assert_eq(case1_step_trace[i].rank_nodes, case1_trace[i + 1])
  }

  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]
  let ranks : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "C": 1,
    "D": 1,
    "E": 2,
    "F": 2,
  }
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "D"),
    flow_edge("B", "C"),
    flow_edge("A", "E"),
    flow_edge("B", "F"),
    flow_edge("C", "F"),
    flow_edge("D", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "E"),
  ]
  let trace : Array[Array[Array[String]]] = []
  let step_trace : Array[DagreParitySweepStepTrace] = []
  let _ = collect_non_state_flow_lanes_internal(
    nodes,
    ranks,
    2,
    edges,
    false,
    false,
    false,
    true,
    Some(trace),
    Some(step_trace),
  )
  assert_eq(trace, [
    [
      ["A", "B"],
      [
        "D", "__lane_dummy_f_2_1", "__lane_dummy_f_6_1", "C", "__lane_dummy_f_3_1",
        "__lane_dummy_f_7_1",
      ],
      ["E", "F"],
    ],
    [
      ["A", "B"],
      [
        "D", "__lane_dummy_f_2_1", "__lane_dummy_f_7_1", "__lane_dummy_f_6_1", "C",
        "__lane_dummy_f_3_1",
      ],
      ["E", "F"],
    ],
    [
      ["A", "B"],
      [
        "D", "__lane_dummy_f_2_1", "__lane_dummy_f_6_1", "C", "__lane_dummy_f_3_1",
        "__lane_dummy_f_7_1",
      ],
      ["E", "F"],
    ],
    [
      ["B", "A"],
      [
        "__lane_dummy_f_7_1", "__lane_dummy_f_2_1", "D", "__lane_dummy_f_3_1", "C",
        "__lane_dummy_f_6_1",
      ],
      ["E", "F"],
    ],
    [
      ["B", "A"],
      [
        "__lane_dummy_f_7_1", "__lane_dummy_f_3_1", "C", "__lane_dummy_f_6_1", "__lane_dummy_f_2_1",
        "D",
      ],
      ["F", "E"],
    ],
    [
      ["A", "B"],
      [
        "D", "__lane_dummy_f_2_1", "__lane_dummy_f_7_1", "__lane_dummy_f_6_1", "C",
        "__lane_dummy_f_3_1",
      ],
      ["E", "F"],
    ],
  ])
  assert_eq(step_trace.length(), 4)
  assert_eq(
    [
      step_trace[0].pass_index,
      step_trace[1].pass_index,
      step_trace[2].pass_index,
      step_trace[3].pass_index,
    ],
    [0, 1, 2, 3],
  )
  assert_eq(
    [
      step_trace[0].incoming_from_neighbor,
      step_trace[1].incoming_from_neighbor,
      step_trace[2].incoming_from_neighbor,
      step_trace[3].incoming_from_neighbor,
    ],
    [false, true, false, true],
  )
  assert_eq(
    [
      step_trace[0].bias_right,
      step_trace[1].bias_right,
      step_trace[2].bias_right,
      step_trace[3].bias_right,
    ],
    [false, false, true, true],
  )
  assert_eq(
    [
      step_trace[0].candidate_crossings,
      step_trace[1].candidate_crossings,
      step_trace[2].candidate_crossings,
      step_trace[3].candidate_crossings,
    ],
    [1, 3, 4, 3],
  )
  assert_eq(step_trace[0].barycenters_by_rank, {
    0: { "A": "4/3", "B": "11/3" },
    1: {
      "C": "1/1",
      "D": "0/1",
      "__lane_dummy_f_2_1": "0/1",
      "__lane_dummy_f_3_1": "1/1",
      "__lane_dummy_f_6_1": "1/1",
      "__lane_dummy_f_7_1": "0/1",
    },
  })
  assert_eq(step_trace[1].barycenters_by_rank, {
    1: {
      "C": "1/1",
      "D": "0/1",
      "__lane_dummy_f_2_1": "0/1",
      "__lane_dummy_f_3_1": "1/1",
      "__lane_dummy_f_6_1": "0/1",
      "__lane_dummy_f_7_1": "1/1",
    },
    2: { "E": "6/3", "F": "9/3" },
  })
  assert_eq(step_trace[2].barycenters_by_rank, {
    0: { "A": "8/3", "B": "7/3" },
    1: {
      "C": "1/1",
      "D": "0/1",
      "__lane_dummy_f_2_1": "0/1",
      "__lane_dummy_f_3_1": "1/1",
      "__lane_dummy_f_6_1": "1/1",
      "__lane_dummy_f_7_1": "0/1",
    },
  })
  assert_eq(step_trace[3].barycenters_by_rank, {
    1: {
      "C": "0/1",
      "D": "1/1",
      "__lane_dummy_f_2_1": "1/1",
      "__lane_dummy_f_3_1": "0/1",
      "__lane_dummy_f_6_1": "1/1",
      "__lane_dummy_f_7_1": "0/1",
    },
    2: { "E": "9/3", "F": "6/3" },
  })
  for i in 0..<step_trace.length() {
    assert_eq(step_trace[i].rank_nodes, trace[i + 1])
  }

  let case3_nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
    { id: "G", label: "G", shape: Rectangle },
    { id: "H", label: "H", shape: Rectangle },
  ]
  let case3_ranks : Map[String, Int] = {
    "A": 0,
    "B": 0,
    "C": 1,
    "D": 1,
    "E": 2,
    "F": 2,
    "G": 3,
    "H": 3,
  }
  let case3_edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("C", "E"),
    flow_edge("D", "F"),
    flow_edge("C", "F"),
    flow_edge("D", "E"),
    flow_edge("E", "G"),
    flow_edge("F", "H"),
    flow_edge("E", "H"),
    flow_edge("F", "G"),
  ]
  let case3_trace : Array[Array[Array[String]]] = []
  let case3_step_trace : Array[DagreParitySweepStepTrace] = []
  let _ = collect_non_state_flow_lanes_internal(
    case3_nodes,
    case3_ranks,
    3,
    case3_edges,
    false,
    false,
    false,
    true,
    Some(case3_trace),
    Some(case3_step_trace),
  )
  assert_eq(case3_trace, [
    [["A", "B"], ["C", "D"], ["E", "F"], ["G", "H"]],
    [["A", "B"], ["C", "D"], ["E", "F"], ["G", "H"]],
    [["A", "B"], ["C", "D"], ["E", "F"], ["G", "H"]],
    [["B", "A"], ["D", "C"], ["F", "E"], ["G", "H"]],
    [["B", "A"], ["D", "C"], ["F", "E"], ["H", "G"]],
    [["B", "A"], ["D", "C"], ["F", "E"], ["H", "G"]],
  ])
  assert_eq(case3_step_trace.length(), 4)
  assert_eq(
    [
      case3_step_trace[0].pass_index,
      case3_step_trace[1].pass_index,
      case3_step_trace[2].pass_index,
      case3_step_trace[3].pass_index,
    ],
    [0, 1, 2, 3],
  )
  assert_eq(
    [
      case3_step_trace[0].incoming_from_neighbor,
      case3_step_trace[1].incoming_from_neighbor,
      case3_step_trace[2].incoming_from_neighbor,
      case3_step_trace[3].incoming_from_neighbor,
    ],
    [false, true, false, true],
  )
  assert_eq(
    [
      case3_step_trace[0].bias_right,
      case3_step_trace[1].bias_right,
      case3_step_trace[2].bias_right,
      case3_step_trace[3].bias_right,
    ],
    [false, false, true, true],
  )
  assert_eq(
    [
      case3_step_trace[0].candidate_crossings,
      case3_step_trace[1].candidate_crossings,
      case3_step_trace[2].candidate_crossings,
      case3_step_trace[3].candidate_crossings,
    ],
    [3, 3, 3, 3],
  )
  assert_eq(case3_step_trace[0].barycenters_by_rank, {
    0: { "A": "1/2", "B": "1/2" },
    1: { "C": "1/2", "D": "1/2" },
    2: { "E": "1/2", "F": "1/2" },
  })
  assert_eq(case3_step_trace[1].barycenters_by_rank, {
    1: { "C": "1/2", "D": "1/2" },
    2: { "E": "1/2", "F": "1/2" },
    3: { "G": "1/2", "H": "1/2" },
  })
  assert_eq(
    case3_step_trace[2].barycenters_by_rank,
    case3_step_trace[0].barycenters_by_rank,
  )
  assert_eq(
    case3_step_trace[3].barycenters_by_rank,
    case3_step_trace[1].barycenters_by_rank,
  )
  for i in 0..<case3_step_trace.length() {
    assert_eq(case3_step_trace[i].rank_nodes, case3_trace[i + 1])
  }
  assert_eq(case3_step_trace[3].rank_nodes, case3_trace[4])
  assert_eq(case3_trace[5], case3_trace[4])
}

///|
test "Layout cycle detection flags simple feedback loops" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
  ]
  let cyclic_edges : Array[MermaidEdge] = [
    {
      source: "A",
      target: "B",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "B",
      target: "C",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "C",
      target: "A",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
  ]
  let acyclic_edges : Array[MermaidEdge] = [
    {
      source: "A",
      target: "B",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "B",
      target: "C",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
  ]

  assert_true(graph_has_cycle(nodes, cyclic_edges))
  assert_eq(graph_has_cycle(nodes, acyclic_edges), false)
}

///|
test "Layout greedy feedback edge selector marks incoming edges of max score pivot" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    {
      source: "A",
      target: "B",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "B",
      target: "C",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "C",
      target: "A",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "C",
      target: "D",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "D",
      target: "B",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
  ]
  let considered_edge_indices = [0, 1, 2, 3, 4]

  let back_edges = collect_greedy_feedback_edge_indices(
    nodes, edges, considered_edge_indices,
  )
  let mut back_edge_count = 0
  for _, _ in back_edges {
    back_edge_count += 1
  }

  assert_eq(back_edge_count, 1)
  assert_true(back_edges.contains(1))
}

///|
test "Layout greedy feedback edge selector prefers lighter reverse direction with multi-edges" {
  let nodes : Array[MermaidNode] = [
    { id: "N1", label: "N1", shape: Rectangle },
    { id: "N2", label: "N2", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    {
      source: "N1",
      target: "N2",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "N1",
      target: "N2",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "N2",
      target: "N1",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
  ]

  let back_edges = collect_greedy_feedback_edge_indices(nodes, edges, [0, 1, 2])
  let mut back_edge_count = 0
  for _, _ in back_edges {
    back_edge_count += 1
  }

  assert_eq(back_edge_count, 1)
  assert_true(back_edges.contains(2))
  assert_eq(back_edges.contains(0), false)
  assert_eq(back_edges.contains(1), false)
}

///|
test "Layout greedy feedback edge selector expands aggregated reverse multi-edges" {
  let nodes : Array[MermaidNode] = [
    { id: "N1", label: "N1", shape: Rectangle },
    { id: "N2", label: "N2", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    {
      source: "N1",
      target: "N2",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "N2",
      target: "N1",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "N2",
      target: "N1",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
  ]

  let back_edges = collect_greedy_feedback_edge_indices(nodes, edges, [0, 1, 2])
  let mut back_edge_count = 0
  for _, _ in back_edges {
    back_edge_count += 1
  }

  assert_eq(back_edge_count, 1)
  assert_true(back_edges.contains(0))
  assert_eq(back_edges.contains(1), false)
  assert_eq(back_edges.contains(2), false)
}

///|
test "Layout greedy feedback edge selector matches upstream corpus" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]

  let case0_edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("E", "C"),
    flow_edge("A", "E"),
    flow_edge("E", "D"),
    flow_edge("E", "C"),
    flow_edge("D", "E"),
    flow_edge("A", "D"),
    flow_edge("D", "B"),
    flow_edge("C", "B"),
    flow_edge("A", "D"),
  ]
  let case0_back_edges = collect_greedy_feedback_edge_indices(
    nodes,
    case0_edges,
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  )
  assert_eq(sorted_back_edge_indices(case0_back_edges), [5])

  let case1_edges : Array[MermaidEdge] = [
    flow_edge("D", "E"),
    flow_edge("F", "D"),
    flow_edge("D", "B"),
    flow_edge("C", "B"),
    flow_edge("B", "D"),
    flow_edge("D", "B"),
    flow_edge("C", "F"),
    flow_edge("D", "F"),
    flow_edge("F", "E"),
    flow_edge("E", "F"),
    flow_edge("C", "F"),
  ]
  let case1_back_edges = collect_greedy_feedback_edge_indices(
    nodes,
    case1_edges,
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  )
  assert_eq(sorted_back_edge_indices(case1_back_edges), [1, 4, 8])

  let case2_edges : Array[MermaidEdge] = [
    flow_edge("E", "D"),
    flow_edge("B", "A"),
    flow_edge("C", "D"),
    flow_edge("B", "E"),
    flow_edge("C", "E"),
    flow_edge("B", "E"),
    flow_edge("F", "B"),
    flow_edge("A", "E"),
    flow_edge("E", "F"),
    flow_edge("F", "A"),
    flow_edge("E", "B"),
    flow_edge("F", "A"),
    flow_edge("A", "F"),
  ]
  let case2_back_edges = collect_greedy_feedback_edge_indices(
    nodes,
    case2_edges,
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  )
  assert_eq(sorted_back_edge_indices(case2_back_edges), [6, 8, 10, 12])

  let case3_edges : Array[MermaidEdge] = [
    flow_edge("A", "F"),
    flow_edge("D", "F"),
    flow_edge("B", "E"),
    flow_edge("F", "D"),
    flow_edge("A", "F"),
    flow_edge("C", "E"),
    flow_edge("B", "C"),
    flow_edge("A", "F"),
    flow_edge("D", "F"),
    flow_edge("E", "F"),
    flow_edge("C", "F"),
    flow_edge("C", "B"),
    flow_edge("D", "C"),
    flow_edge("F", "A"),
  ]
  let case3_back_edges = collect_greedy_feedback_edge_indices(
    nodes,
    case3_edges,
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
  )
  assert_eq(sorted_back_edge_indices(case3_back_edges), [3, 11, 13])
}

///|
test "Layout acyclic DFS phase matches upstream back-edge decomposition" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("B", "A"),
    flow_edge("A", "C"),
    flow_edge("C", "B"),
    flow_edge("C", "D"),
  ]

  let phase_state = collect_non_state_flow_acyclic_phase_state(
    nodes, edges, false, false,
  )

  assert_eq(sorted_int_array(phase_state.relaxed_edge_indices), [1, 2, 3])
  assert_eq(sorted_int_array(phase_state.reversed_back_edge_indices), [0])
  assert_eq(sorted_int_array(phase_state.definition_backward_edge_indices), [])
  assert_eq(
    option_edge_index_count(
      phase_state.incoming_relaxed_edge_indices_by_target.get("A"),
    ),
    0,
  )
  assert_eq(
    option_edge_index_count(
      phase_state.incoming_relaxed_edge_indices_by_target.get("B"),
    ),
    1,
  )
}

///|
test "Layout acyclic DFS phase matches upstream corpus" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]

  let case0_edges : Array[MermaidEdge] = [
    flow_edge("E", "B"),
    flow_edge("A", "E"),
    flow_edge("C", "D"),
    flow_edge("F", "A"),
    flow_edge("E", "A"),
    flow_edge("A", "E"),
    flow_edge("A", "C"),
    flow_edge("D", "F"),
    flow_edge("B", "D"),
  ]
  let case0_state = collect_non_state_flow_acyclic_phase_state(
    nodes, case0_edges, false, false,
  )
  assert_eq(sorted_int_array(case0_state.reversed_back_edge_indices), [3, 4])

  let case1_edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("A", "B"),
    flow_edge("C", "F"),
    flow_edge("C", "D"),
    flow_edge("F", "B"),
    flow_edge("C", "B"),
    flow_edge("D", "B"),
    flow_edge("F", "A"),
    flow_edge("C", "B"),
    flow_edge("D", "B"),
    flow_edge("D", "C"),
  ]
  let case1_state = collect_non_state_flow_acyclic_phase_state(
    nodes, case1_edges, false, false,
  )
  assert_eq(sorted_int_array(case1_state.reversed_back_edge_indices), [7, 10])

  let case2_edges : Array[MermaidEdge] = [
    flow_edge("F", "C"),
    flow_edge("C", "F"),
    flow_edge("C", "D"),
    flow_edge("B", "F"),
    flow_edge("B", "C"),
    flow_edge("B", "E"),
    flow_edge("A", "E"),
    flow_edge("C", "F"),
    flow_edge("F", "B"),
    flow_edge("F", "C"),
    flow_edge("C", "A"),
    flow_edge("A", "E"),
  ]
  let case2_state = collect_non_state_flow_acyclic_phase_state(
    nodes, case2_edges, false, false,
  )
  assert_eq(sorted_int_array(case2_state.reversed_back_edge_indices), [1, 7, 8])

  let case3_edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("D", "F"),
    flow_edge("E", "D"),
    flow_edge("E", "C"),
    flow_edge("A", "B"),
    flow_edge("D", "B"),
    flow_edge("D", "A"),
    flow_edge("D", "A"),
    flow_edge("C", "D"),
    flow_edge("A", "D"),
    flow_edge("D", "B"),
    flow_edge("D", "C"),
    flow_edge("A", "B"),
  ]
  let case3_state = collect_non_state_flow_acyclic_phase_state(
    nodes, case3_edges, false, false,
  )
  assert_eq(sorted_int_array(case3_state.reversed_back_edge_indices), [6, 7, 8])
}

///|
test "Layout acyclic DFS phase matches upstream stress fixture decomposition" {
  let (stress003_nodes, stress003_edges) = fixture_nodes_and_edges_for_acyclic_phase(
    stress_003_subgraph_bridges_source(),
  )
  let stress003_phase_state = collect_non_state_flow_acyclic_phase_state(
    stress003_nodes, stress003_edges, false, false,
  )
  assert_eq(
    reversed_back_edge_keys(
      stress003_edges,
      stress003_phase_state.reversed_back_edge_indices,
    ),
    sorted_string_array([
      "L5->L2", "M3->M4", "R5->R2", "SNK->M2", "M1->M2", "R3->L2", "R2->L4", "M3->L1",
    ]),
  )
  assert_eq(stress003_phase_state.definition_backward_edge_indices.length(), 0)

  let (stress006_nodes, stress006_edges) = fixture_nodes_and_edges_for_acyclic_phase(
    stress_006_nested_bridge_loops_source(),
  )
  let stress006_phase_state = collect_non_state_flow_acyclic_phase_state(
    stress006_nodes, stress006_edges, false, false,
  )
  assert_eq(
    reversed_back_edge_keys(
      stress006_edges,
      stress006_phase_state.reversed_back_edge_indices,
    ),
    sorted_string_array(["LI3->L3", "R4->SNK", "R3->L2", "R2->LI2", "RI3->L1"]),
  )
  assert_eq(stress006_phase_state.definition_backward_edge_indices.length(), 0)

  let (stress010_nodes, stress010_edges) = fixture_nodes_and_edges_for_acyclic_phase(
    stress_010_bipartite_crossfire_source(),
  )
  let stress010_phase_state = collect_non_state_flow_acyclic_phase_state(
    stress010_nodes, stress010_edges, false, false,
  )
  assert_eq(
    reversed_back_edge_keys(
      stress010_edges,
      stress010_phase_state.reversed_back_edge_indices,
    ),
    sorted_string_array([
      "H2->T3", "H3->T1", "H4->T3", "H4->T6", "M4->H2", "M4->Z1", "T2->M1", "T4->M1",
      "T5->H1", "T5->M2", "T5->M3", "T6->M3", "Z4->H1", "Z4->T2",
    ]),
  )
  assert_eq(stress010_phase_state.definition_backward_edge_indices.length(), 0)

  let (stress012_nodes, stress012_edges) = fixture_nodes_and_edges_for_acyclic_phase(
    stress_012_interleaved_subgraph_feedback_source(),
  )
  let stress012_phase_state = collect_non_state_flow_acyclic_phase_state(
    stress012_nodes, stress012_edges, false, false,
  )
  assert_eq(
    reversed_back_edge_keys(
      stress012_edges,
      stress012_phase_state.reversed_back_edge_indices,
    ),
    sorted_string_array([
      "M6->SNK", "M6->L2", "R6->SNK", "R6->L3", "R5->M4", "R4->M3", "LC3->L5", "R1->R2",
      "LC2->M5", "M2->M3", "M2->R2", "RC3->L1", "RC2->M5", "SNK->L4",
    ]),
  )
  assert_eq(stress012_phase_state.definition_backward_edge_indices.length(), 0)
}

///|
test "Layout dagre nesting rank phase matches upstream stress fixture layers" {
  let stress003_layers = collect_fixture_dagre_nesting_rank_layers(
    stress_003_subgraph_bridges_source(),
  )
  assert_eq(stress003_layers, official_layers_layout_stress_003())

  let stress006_layers = collect_fixture_dagre_nesting_rank_layers(
    stress_006_nested_bridge_loops_source(),
  )
  assert_eq(stress006_layers, official_layers_layout_stress_006())

  let stress012_layers = collect_fixture_dagre_nesting_rank_layers(
    stress_012_interleaved_subgraph_feedback_source(),
  )
  assert_eq(stress012_layers, official_layers_layout_stress_012())
}

///|
test "Layout lane state dagre parity keeps stress fixture rank layers faithful" {
  let stress003_layers = collect_fixture_lane_state_rank_layers_for_dagre_parity(
    stress_003_subgraph_bridges_source(),
  )
  assert_eq(stress003_layers, official_layers_layout_stress_003())

  let stress006_layers = collect_fixture_lane_state_rank_layers_for_dagre_parity(
    stress_006_nested_bridge_loops_source(),
  )
  assert_eq(stress006_layers, official_layers_layout_stress_006())

  let stress012_layers = collect_fixture_lane_state_rank_layers_for_dagre_parity(
    stress_012_interleaved_subgraph_feedback_source(),
  )
  assert_eq(stress012_layers, official_layers_layout_stress_012())
}

///|
test "Layout dagre simplex ranker matches upstream nested bridge loop baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "SRC", label: "SRC", shape: Rectangle },
    { id: "SNK", label: "SNK", shape: Rectangle },
    { id: "L0", label: "L0", shape: Rectangle },
    { id: "L1", label: "L1", shape: Rectangle },
    { id: "L2", label: "L2", shape: Rectangle },
    { id: "LI1", label: "LI1", shape: Rectangle },
    { id: "LI2", label: "LI2", shape: Rectangle },
    { id: "LI3", label: "LI3", shape: Rectangle },
    { id: "L3", label: "L3", shape: Rectangle },
    { id: "L4", label: "L4", shape: Rectangle },
    { id: "R0", label: "R0", shape: Rectangle },
    { id: "R1", label: "R1", shape: Rectangle },
    { id: "R2", label: "R2", shape: Rectangle },
    { id: "RI1", label: "RI1", shape: Rectangle },
    { id: "RI2", label: "RI2", shape: Rectangle },
    { id: "RI3", label: "RI3", shape: Rectangle },
    { id: "R3", label: "R3", shape: Rectangle },
    { id: "R4", label: "R4", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("SRC", "L0"),
    flow_edge("SRC", "R0"),
    flow_edge("L0", "L1"),
    flow_edge("L1", "L2"),
    flow_edge("L2", "L3"),
    flow_edge("L3", "L4"),
    flow_edge("L4", "SNK"),
    flow_edge("R0", "R1"),
    flow_edge("R1", "R2"),
    flow_edge("R2", "R3"),
    flow_edge("R3", "R4"),
    flow_edge("R4", "SNK"),
    flow_edge("L1", "LI1"),
    flow_edge("LI1", "LI2"),
    flow_edge("LI2", "LI3"),
    flow_edge("LI3", "L3"),
    flow_edge("R1", "RI1"),
    flow_edge("RI1", "RI2"),
    flow_edge("RI2", "RI3"),
    flow_edge("RI3", "R3"),
    flow_edge("LI1", "RI2"),
    flow_edge("LI2", "R2"),
    flow_edge("L2", "RI1"),
    flow_edge("L3", "R1"),
    flow_edge("RI1", "LI3"),
    flow_edge("R2", "LI2"),
    flow_edge("RI3", "L1"),
    flow_edge("R3", "L2"),
    flow_edge("L4", "RI3"),
    flow_edge("R4", "LI3"),
    flow_edge("SNK", "LI1"),
  ]

  let phase_state = collect_non_state_flow_acyclic_phase_state(
    nodes, edges, false, false,
  )
  assert_eq(sorted_int_array(phase_state.reversed_back_edge_indices), [
    11, 15, 25, 26, 27,
  ])

  let (rank_by_id, max_rank, simplex_ok) = collect_dagre_network_simplex_ranks(
    nodes,
    edges,
    phase_state.relaxed_edge_indices,
    phase_state.reversed_back_edge_indices,
  )
  assert_true(simplex_ok)
  assert_eq(max_rank, 12)
  assert_eq(option_int_or(rank_by_id.get("SRC"), -1), 0)
  assert_eq(option_int_or(rank_by_id.get("L0"), -1), 1)
  assert_eq(option_int_or(rank_by_id.get("L1"), -1), 2)
  assert_eq(option_int_or(rank_by_id.get("L2"), -1), 3)
  assert_eq(option_int_or(rank_by_id.get("L3"), -1), 4)
  assert_eq(option_int_or(rank_by_id.get("L4"), -1), 5)
  assert_eq(option_int_or(rank_by_id.get("R0"), -1), 5)
  assert_eq(option_int_or(rank_by_id.get("SNK"), -1), 6)
  assert_eq(option_int_or(rank_by_id.get("R1"), -1), 6)
  assert_eq(option_int_or(rank_by_id.get("LI1"), -1), 7)
  assert_eq(option_int_or(rank_by_id.get("RI1"), -1), 7)
  assert_eq(option_int_or(rank_by_id.get("LI2"), -1), 8)
  assert_eq(option_int_or(rank_by_id.get("RI2"), -1), 8)
  assert_eq(option_int_or(rank_by_id.get("R2"), -1), 9)
  assert_eq(option_int_or(rank_by_id.get("RI3"), -1), 9)
  assert_eq(option_int_or(rank_by_id.get("R3"), -1), 10)
  assert_eq(option_int_or(rank_by_id.get("R4"), -1), 11)
  assert_eq(option_int_or(rank_by_id.get("LI3"), -1), 12)
}

///|
test "Layout acyclic greedy phase matches upstream multi-edge decomposition" {
  let nodes : Array[MermaidNode] = [
    { id: "N1", label: "N1", shape: Rectangle },
    { id: "N2", label: "N2", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("N1", "N2"),
    flow_edge("N2", "N1"),
    flow_edge("N2", "N1"),
  ]

  let phase_state = collect_non_state_flow_acyclic_phase_state(
    nodes, edges, false, true,
  )

  assert_eq(sorted_int_array(phase_state.relaxed_edge_indices), [1, 2])
  assert_eq(sorted_int_array(phase_state.reversed_back_edge_indices), [0])
  assert_eq(sorted_int_array(phase_state.definition_backward_edge_indices), [])
}

///|
test "Layout acyclic phase excludes definition-backward edges from relaxed DAG" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [flow_edge("C", "A"), flow_edge("A", "B")]

  let phase_state = collect_non_state_flow_acyclic_phase_state(
    nodes, edges, true, false,
  )

  assert_eq(sorted_int_array(phase_state.relaxed_edge_indices), [1])
  assert_eq(sorted_int_array(phase_state.reversed_back_edge_indices), [])
  assert_eq(sorted_int_array(phase_state.definition_backward_edge_indices), [0])
}

///|
test "Layout definition-backward heuristic can collapse sink rank when sink is declared early" {
  let nodes : Array[MermaidNode] = [
    { id: "SRC", label: "SRC", shape: Rectangle },
    { id: "SNK", label: "SNK", shape: Rectangle },
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("SRC", "A"),
    flow_edge("A", "B"),
    flow_edge("B", "C"),
    flow_edge("C", "D"),
    flow_edge("D", "SNK"),
    flow_edge("SNK", "B"),
  ]

  let with_definition_filter = collect_non_state_flow_acyclic_phase_state(
    nodes, edges, true, false,
  )
  assert_eq(
    sorted_int_array(with_definition_filter.definition_backward_edge_indices),
    [4],
  )
  assert_eq(
    sorted_int_array(with_definition_filter.reversed_back_edge_indices),
    [5],
  )
  assert_eq(sorted_int_array(with_definition_filter.relaxed_edge_indices), [
    0, 1, 2, 3,
  ])

  let without_definition_filter = collect_non_state_flow_acyclic_phase_state(
    nodes, edges, false, false,
  )
  assert_eq(
    sorted_int_array(without_definition_filter.definition_backward_edge_indices),
    [],
  )
  assert_eq(
    sorted_int_array(without_definition_filter.reversed_back_edge_indices),
    [5],
  )
  assert_eq(sorted_int_array(without_definition_filter.relaxed_edge_indices), [
    0, 1, 2, 3, 4,
  ])

  let (ranks_with_definition_filter, _) = collect_non_state_flow_ranks(
    nodes, edges, false, true, false, true, false, false, false, false,
  )
  let (ranks_without_definition_filter, _) = collect_non_state_flow_ranks(
    nodes, edges, false, true, false, false, false, false, false, false,
  )

  let snk_rank_with_definition_filter = option_int_or(
    ranks_with_definition_filter.get("SNK"),
    -1,
  )
  let snk_rank_without_definition_filter = option_int_or(
    ranks_without_definition_filter.get("SNK"),
    -1,
  )
  let d_rank_with_definition_filter = option_int_or(
    ranks_with_definition_filter.get("D"),
    -1,
  )

  assert_true(snk_rank_with_definition_filter >= 0)
  assert_true(snk_rank_without_definition_filter >= 0)
  assert_true(
    snk_rank_without_definition_filter > snk_rank_with_definition_filter,
  )
  assert_true(d_rank_with_definition_filter > snk_rank_with_definition_filter)
}

///|
test "Layout cycle-aware rank collection rehydrates cyclic forward order" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    {
      source: "B",
      target: "A",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "A",
      target: "C",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "C",
      target: "B",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
    {
      source: "C",
      target: "D",
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    },
  ]

  let (legacy_ranks, _) = collect_non_state_flow_ranks(
    nodes, edges, false, false, false, false, false, false, false, false,
  )
  let (cycle_ranks, _) = collect_non_state_flow_ranks(
    nodes, edges, false, true, false, false, false, false, false, false,
  )

  let legacy_b = option_int_or(legacy_ranks.get("B"), -1)
  let cycle_b = option_int_or(cycle_ranks.get("B"), -1)
  let cycle_a = option_int_or(cycle_ranks.get("A"), -1)
  let cycle_d = option_int_or(cycle_ranks.get("D"), -1)

  assert_eq(legacy_b, 0)
  assert_eq(cycle_b, 2)
  assert_true(cycle_b > legacy_b)
  assert_true(cycle_b > cycle_a)
  assert_true(cycle_d >= cycle_b)
}

///|
test "Layout simplex prep aggregates relaxed and reversed edges into one directed edge" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("A", "B"),
    flow_edge("B", "A"),
  ]

  let prepared = prepare_dagre_network_simplex_graph(nodes, edges, [0, 1], [2])
  let aggregated_edge_index = prepared.directed_edge_index_by_key.get(
    dagre_rank_directed_edge_key(0, 1),
  )

  assert_eq(prepared.edge_source_index.length(), 1)
  assert_eq(aggregated_edge_index is Some(_), true)
  guard aggregated_edge_index is Some(edge_index) else {
    fail("expected aggregated edge")
  }
  assert_eq(prepared.edge_source_index[edge_index], 0)
  assert_eq(prepared.edge_target_index[edge_index], 1)
  assert_eq(prepared.edge_minlen[edge_index], 1)
  assert_eq(prepared.edge_weight[edge_index], 3)
}

///|
test "Layout simplex prep adds zero-cost connectors across weak components" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [flow_edge("A", "B"), flow_edge("C", "D")]

  let prepared = prepare_dagre_network_simplex_graph(nodes, edges, [0, 1], [])
  let connector_to_component_two = prepared.directed_edge_index_by_key.get(
    dagre_rank_directed_edge_key(0, 2),
  )
  let connector_to_component_three = prepared.directed_edge_index_by_key.get(
    dagre_rank_directed_edge_key(0, 4),
  )

  assert_eq(prepared.edge_source_index.length(), 4)
  guard connector_to_component_two is Some(edge_to_c) else {
    fail("expected connector to second component")
  }
  assert_eq(prepared.edge_minlen[edge_to_c], 0)
  assert_eq(prepared.edge_weight[edge_to_c], 0)
  guard connector_to_component_three is Some(edge_to_e) else {
    fail("expected connector to isolated component")
  }
  assert_eq(prepared.edge_minlen[edge_to_e], 0)
  assert_eq(prepared.edge_weight[edge_to_e], 0)
}

///|
fn find_rank_edge_spec(
  edge_specs : Array[DagreRankEdgeSpec],
  source_id : String,
  target_id : String,
) -> DagreRankEdgeSpec? {
  for edge_spec in edge_specs {
    if edge_spec.source_id == source_id && edge_spec.target_id == target_id {
      return Some(edge_spec)
    }
  }
  None
}

///|
test "Layout dagre rank edge specs respect relaxed and reversed directions" {
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("B", "C"),
    flow_edge("D", "A"),
  ]
  let specs = collect_dagre_rank_edge_specs(edges, [0, 1], [2])

  assert_eq(specs.length(), 3)
  assert_true(find_rank_edge_spec(specs, "A", "B") is Some(_))
  assert_true(find_rank_edge_spec(specs, "B", "C") is Some(_))
  assert_true(find_rank_edge_spec(specs, "A", "D") is Some(_))
  match find_rank_edge_spec(specs, "A", "D") {
    Some(spec) => {
      assert_eq(spec.minlen, 1)
      assert_eq(spec.weight, 1)
      assert_eq(spec.nesting_edge, false)
    }
    None => fail("expected reversed edge spec")
  }
}

///|
test "Layout dagre nesting prep mirrors upstream minlen and weight rules" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("B", "C"),
    flow_edge("D", "A"),
  ]
  let base_specs = collect_dagre_rank_edge_specs(edges, [0, 1], [2])
  let subgraphs : Array[MermaidSubgraph] = [
    {
      id: "SG_A",
      label: "SG_A",
      node_ids: ["A"],
      children: [
        {
          id: "SG_B",
          label: "SG_B",
          node_ids: ["B"],
          children: [],
          direction: None,
        },
      ],
      direction: None,
    },
    {
      id: "SG_C",
      label: "SG_C",
      node_ids: ["C"],
      children: [],
      direction: None,
    },
  ]

  let prep_state = collect_dagre_nesting_rank_prep_state(
    nodes, base_specs, subgraphs,
  )

  assert_eq(prep_state.node_rank_factor, 5)
  assert_eq(prep_state.expanded_nodes.length(), 11)
  assert_eq(prep_state.bounds_by_subgraph_id.length(), 3)
  assert_true(prep_state.node_in_subgraph.contains("A"))
  assert_true(prep_state.node_in_subgraph.contains("B"))
  assert_true(prep_state.node_in_subgraph.contains("C"))
  assert_true(!prep_state.node_in_subgraph.contains("D"))

  match prep_state.root_id {
    Some(root_id) => {
      let sg_a_bounds = prep_state.bounds_by_subgraph_id.get("SG_A")
      let sg_b_bounds = prep_state.bounds_by_subgraph_id.get("SG_B")
      let sg_c_bounds = prep_state.bounds_by_subgraph_id.get("SG_C")
      guard sg_a_bounds is Some(a_bounds) else { fail("expected SG_A bounds") }
      guard sg_b_bounds is Some(b_bounds) else { fail("expected SG_B bounds") }
      guard sg_c_bounds is Some(c_bounds) else { fail("expected SG_C bounds") }

      let base_ab = find_rank_edge_spec(prep_state.edge_specs, "A", "B")
      let base_bc = find_rank_edge_spec(prep_state.edge_specs, "B", "C")
      let base_ad = find_rank_edge_spec(prep_state.edge_specs, "A", "D")
      guard base_ab is Some(base_ab_spec) else {
        fail("expected A->B base edge")
      }
      guard base_bc is Some(base_bc_spec) else {
        fail("expected B->C base edge")
      }
      guard base_ad is Some(base_ad_spec) else {
        fail("expected A->D base edge")
      }
      assert_eq(base_ab_spec.minlen, 5)
      assert_eq(base_bc_spec.minlen, 5)
      assert_eq(base_ad_spec.minlen, 5)
      assert_eq(base_ab_spec.nesting_edge, false)
      assert_eq(base_bc_spec.nesting_edge, false)
      assert_eq(base_ad_spec.nesting_edge, false)

      let root_to_a_top = find_rank_edge_spec(
        prep_state.edge_specs,
        root_id,
        a_bounds.top_id,
      )
      let root_to_c_top = find_rank_edge_spec(
        prep_state.edge_specs,
        root_id,
        c_bounds.top_id,
      )
      let root_to_d = find_rank_edge_spec(prep_state.edge_specs, root_id, "D")
      guard root_to_a_top is Some(root_to_a_top_spec) else {
        fail("expected root to SG_A top edge")
      }
      guard root_to_c_top is Some(root_to_c_top_spec) else {
        fail("expected root to SG_C top edge")
      }
      guard root_to_d is Some(root_to_d_spec) else {
        fail("expected root to outside node edge")
      }
      assert_eq(root_to_a_top_spec.minlen, 3)
      assert_eq(root_to_c_top_spec.minlen, 3)
      assert_eq(root_to_d_spec.minlen, 5)
      assert_eq(root_to_a_top_spec.weight, 0)
      assert_eq(root_to_c_top_spec.weight, 0)
      assert_eq(root_to_d_spec.weight, 0)
      assert_eq(root_to_a_top_spec.nesting_edge, true)
      assert_eq(root_to_c_top_spec.nesting_edge, true)
      assert_eq(root_to_d_spec.nesting_edge, true)

      let a_to_a_bottom = find_rank_edge_spec(
        prep_state.edge_specs,
        "A",
        a_bounds.bottom_id,
      )
      let a_top_to_a = find_rank_edge_spec(
        prep_state.edge_specs,
        a_bounds.top_id,
        "A",
      )
      guard a_to_a_bottom is Some(a_to_a_bottom_spec) else {
        fail("expected SG_A leaf bottom edge")
      }
      guard a_top_to_a is Some(a_top_to_a_spec) else {
        fail("expected SG_A leaf top edge")
      }
      assert_eq(a_top_to_a_spec.minlen, 2)
      assert_eq(a_to_a_bottom_spec.minlen, 2)
      assert_eq(a_top_to_a_spec.weight, 8)
      assert_eq(a_to_a_bottom_spec.weight, 8)

      let b_top_to_b = find_rank_edge_spec(
        prep_state.edge_specs,
        b_bounds.top_id,
        "B",
      )
      let b_to_bottom = find_rank_edge_spec(
        prep_state.edge_specs,
        "B",
        b_bounds.bottom_id,
      )
      guard b_top_to_b is Some(b_top_to_b_spec) else {
        fail("expected SG_B leaf top edge")
      }
      guard b_to_bottom is Some(b_to_bottom_spec) else {
        fail("expected SG_B leaf bottom edge")
      }
      assert_eq(b_top_to_b_spec.minlen, 1)
      assert_eq(b_to_bottom_spec.minlen, 1)
      assert_eq(b_top_to_b_spec.weight, 8)
      assert_eq(b_to_bottom_spec.weight, 8)

      let a_top_to_b_top = find_rank_edge_spec(
        prep_state.edge_specs,
        a_bounds.top_id,
        b_bounds.top_id,
      )
      let b_bottom_to_a_bottom = find_rank_edge_spec(
        prep_state.edge_specs,
        b_bounds.bottom_id,
        a_bounds.bottom_id,
      )
      guard a_top_to_b_top is Some(a_top_to_b_top_spec) else {
        fail("expected SG_A to SG_B top constraint")
      }
      guard b_bottom_to_a_bottom is Some(b_bottom_to_a_bottom_spec) else {
        fail("expected SG_B to SG_A bottom constraint")
      }
      assert_eq(a_top_to_b_top_spec.minlen, 1)
      assert_eq(b_bottom_to_a_bottom_spec.minlen, 1)
      assert_eq(a_top_to_b_top_spec.weight, 4)
      assert_eq(b_bottom_to_a_bottom_spec.weight, 4)
      assert_eq(a_top_to_b_top_spec.nesting_edge, true)
      assert_eq(b_bottom_to_a_bottom_spec.nesting_edge, true)
    }
    None => fail("expected nesting root")
  }
}

///|
test "Layout dagre nesting rank phase matches upstream tiny compound baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("B", "C"),
    flow_edge("D", "A"),
  ]
  let base_specs = collect_dagre_rank_edge_specs(edges, [0, 1], [2])
  let subgraphs : Array[MermaidSubgraph] = [
    {
      id: "SG_A",
      label: "SG_A",
      node_ids: ["A"],
      children: [
        {
          id: "SG_B",
          label: "SG_B",
          node_ids: ["B"],
          children: [],
          direction: None,
        },
      ],
      direction: None,
    },
    {
      id: "SG_C",
      label: "SG_C",
      node_ids: ["C"],
      children: [],
      direction: None,
    },
  ]

  let (rank_by_id, max_rank, ok) = collect_dagre_nesting_rank_result(
    nodes, base_specs, subgraphs,
  )

  assert_true(ok)
  assert_eq(max_rank, 7)
  assert_eq(option_int_or(rank_by_id.get("A"), -1), 1)
  assert_eq(option_int_or(rank_by_id.get("B"), -1), 3)
  assert_eq(option_int_or(rank_by_id.get("C"), -1), 7)
  assert_eq(option_int_or(rank_by_id.get("D"), -1), 3)
}

///|
test "Layout simplex seed phase matches upstream fanout baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "D"),
    flow_edge("C", "D"),
  ]
  let prepared = prepare_dagre_network_simplex_graph(
    nodes,
    edges,
    [0, 1, 2, 3, 4],
    [],
  )
  let seed_state = collect_dagre_network_simplex_seed_state(nodes, prepared)
  guard seed_state is Some(seed) else { fail("expected simplex seed state") }

  assert_eq(seed.longest_path_rank_by_node_index, [-2, -1, -1, 0, 0, 0])
  assert_eq(seed.feasible_rank_by_node_index, [-1, 0, 0, 1, 0, 0])
  assert_eq(
    sorted_string_array(active_tree_edge_keys_from_seed_state(nodes, seed)),
    ["A->B", "A->E", "A->F", "B->D", "C->D"],
  )
}

///|
test "Layout simplex seed phase matches upstream pivot baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "E"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("B", "E"),
  ]
  let prepared = prepare_dagre_network_simplex_graph(
    nodes,
    edges,
    [0, 1, 2, 3, 4, 5],
    [],
  )
  let seed_state = collect_dagre_network_simplex_seed_state(nodes, prepared)
  guard seed_state is Some(seed) else { fail("expected simplex seed state") }

  assert_eq(seed.longest_path_rank_by_node_index, [-1, -1, 0, 0, 0])
  assert_eq(seed.feasible_rank_by_node_index, [-1, -1, 0, 0, 0])
  assert_eq(
    sorted_string_array(active_tree_edge_keys_from_seed_state(nodes, seed)),
    ["A->C", "B->C", "B->D", "B->E"],
  )
}

///|
test "Layout simplex cut phase matches upstream fanout baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "D"),
    flow_edge("C", "D"),
  ]
  let prepared = prepare_dagre_network_simplex_graph(
    nodes,
    edges,
    [0, 1, 2, 3, 4],
    [],
  )
  let seed_state = collect_dagre_network_simplex_seed_state(nodes, prepared)
  guard seed_state is Some(seed) else { fail("expected simplex seed state") }
  let cut_phase_state = collect_dagre_network_simplex_cut_phase_state(
    nodes, prepared, seed,
  )
  guard cut_phase_state is Some(cut_phase) else {
    fail("expected simplex cut phase state")
  }

  assert_eq(cut_phase.parent_by_node, [-1, 0, 3, 1, 0, 0])
  assert_eq(cut_phase.low_by_node, [1, 1, 1, 1, 4, 5])
  assert_eq(cut_phase.lim_by_node, [6, 3, 1, 2, 4, 5])
  let cut_entries = active_tree_cut_entries_from_cut_phase(
    nodes, seed, cut_phase,
  )
  assert_eq(map_string_int_entry_count(cut_entries), 5)
  assert_eq(option_int_or(cut_entries.get("A->B"), -999), 1)
  assert_eq(option_int_or(cut_entries.get("A->E"), -999), 1)
  assert_eq(option_int_or(cut_entries.get("A->F"), -999), 1)
  assert_eq(option_int_or(cut_entries.get("B->D"), -999), 1)
  assert_eq(option_int_or(cut_entries.get("C->D"), -999), 1)
  assert_eq(cut_phase.leave_tree_edge_index is None, true)
  assert_eq(cut_phase.enter_graph_edge_index is None, true)
}

///|
test "Layout simplex cut phase matches upstream pivot baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "E"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("B", "E"),
  ]
  let prepared = prepare_dagre_network_simplex_graph(
    nodes,
    edges,
    [0, 1, 2, 3, 4, 5],
    [],
  )
  let seed_state = collect_dagre_network_simplex_seed_state(nodes, prepared)
  guard seed_state is Some(seed) else { fail("expected simplex seed state") }
  let cut_phase_state = collect_dagre_network_simplex_cut_phase_state(
    nodes, prepared, seed,
  )
  guard cut_phase_state is Some(cut_phase) else {
    fail("expected simplex cut phase state")
  }

  assert_eq(cut_phase.parent_by_node, [-1, 2, 0, 1, 1])
  assert_eq(cut_phase.low_by_node, [1, 1, 1, 1, 2])
  assert_eq(cut_phase.lim_by_node, [5, 3, 4, 1, 2])
  let cut_entries = active_tree_cut_entries_from_cut_phase(
    nodes, seed, cut_phase,
  )
  assert_eq(map_string_int_entry_count(cut_entries), 4)
  assert_eq(option_int_or(cut_entries.get("A->C"), -999), 3)
  assert_eq(option_int_or(cut_entries.get("B->C"), -999), -1)
  assert_eq(option_int_or(cut_entries.get("B->D"), -999), 2)
  assert_eq(option_int_or(cut_entries.get("B->E"), -999), 2)
  guard cut_phase.leave_tree_edge_index is Some(leave_tree_edge_index) else {
    fail("expected negative cut edge")
  }
  assert_eq(
    normalized_tree_edge_key_from_seed_state(nodes, seed, leave_tree_edge_index),
    "B->C",
  )
  guard cut_phase.enter_graph_edge_index is Some(enter_graph_edge_index) else {
    fail("expected enter graph edge")
  }
  assert_eq(
    directed_graph_edge_key_from_index(nodes, prepared, enter_graph_edge_index),
    "A->D",
  )
}

///|
test "Layout simplex ranker matches upstream pivot baseline final ranks" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "E"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("B", "E"),
  ]

  let (ranks, max_rank, ok) = collect_dagre_network_simplex_ranks(
    nodes,
    edges,
    [0, 1, 2, 3, 4, 5],
    [],
  )
  assert_eq(ok, true)
  assert_eq(max_rank, 1)
  assert_eq(option_int_or(ranks.get("A"), -1), 0)
  assert_eq(option_int_or(ranks.get("B"), -1), 0)
  assert_eq(option_int_or(ranks.get("C"), -1), 1)
  assert_eq(option_int_or(ranks.get("D"), -1), 1)
  assert_eq(option_int_or(ranks.get("E"), -1), 1)
}

///|
test "Layout simplex exchange trace matches upstream multi-pivot baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
    { id: "G", label: "G", shape: Rectangle },
    { id: "H", label: "H", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("B", "C"),
    flow_edge("B", "E"),
    flow_edge("C", "F"),
    flow_edge("C", "G"),
    flow_edge("D", "F"),
    flow_edge("D", "G"),
    flow_edge("D", "H"),
    flow_edge("E", "F"),
    flow_edge("E", "G"),
    flow_edge("E", "H"),
  ]

  let (_, _, ok, exchange_steps) = collect_dagre_network_simplex_ranks_with_trace(
    nodes,
    edges,
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    [],
    true,
  )
  if !ok {
    fail("expected simplex exchange trace")
  }
  assert_eq(exchange_steps.length(), 3)

  let step0 = exchange_steps[0]
  assert_eq(
    normalized_leave_tree_edge_key_from_exchange_step(nodes, step0),
    "B->C",
  )
  assert_eq(
    directed_enter_graph_edge_key_from_exchange_step(nodes, step0),
    "C->F",
  )
  assert_eq(step0.rank_by_node_index, [-2, -2, -1, -1, -1, 0, 0, 0])
  assert_eq(step0.parent_by_node, [-1, 4, 0, 5, 5, 2, 3, 3])
  assert_eq(step0.low_by_node, [1, 4, 1, 1, 4, 1, 1, 2])
  assert_eq(step0.lim_by_node, [8, 4, 7, 3, 5, 6, 1, 2])
  let cut_entries0 = active_tree_cut_entries_from_exchange_step(nodes, step0)
  assert_eq(map_string_int_entry_count(cut_entries0), 7)
  assert_eq(option_int_or(cut_entries0.get("A->C"), -999), 1)
  assert_eq(option_int_or(cut_entries0.get("B->E"), -999), 2)
  assert_eq(option_int_or(cut_entries0.get("C->F"), -999), 1)
  assert_eq(option_int_or(cut_entries0.get("D->F"), -999), -2)
  assert_eq(option_int_or(cut_entries0.get("D->G"), -999), 3)
  assert_eq(option_int_or(cut_entries0.get("D->H"), -999), 2)
  assert_eq(option_int_or(cut_entries0.get("E->F"), -999), 4)

  let step1 = exchange_steps[1]
  assert_eq(
    normalized_leave_tree_edge_key_from_exchange_step(nodes, step1),
    "D->F",
  )
  assert_eq(
    directed_enter_graph_edge_key_from_exchange_step(nodes, step1),
    "C->G",
  )
  assert_eq(step1.rank_by_node_index, [-2, -2, -1, -1, -1, 0, 0, 0])
  assert_eq(step1.parent_by_node, [-1, 4, 0, 6, 5, 2, 2, 3])
  assert_eq(step1.low_by_node, [1, 1, 1, 4, 1, 1, 4, 4])
  assert_eq(step1.lim_by_node, [8, 1, 7, 5, 2, 3, 6, 4])
  let cut_entries1 = active_tree_cut_entries_from_exchange_step(nodes, step1)
  assert_eq(map_string_int_entry_count(cut_entries1), 7)
  assert_eq(option_int_or(cut_entries1.get("A->C"), -999), 1)
  assert_eq(option_int_or(cut_entries1.get("B->E"), -999), 2)
  assert_eq(option_int_or(cut_entries1.get("C->F"), -999), -1)
  assert_eq(option_int_or(cut_entries1.get("C->G"), -999), 2)
  assert_eq(option_int_or(cut_entries1.get("D->G"), -999), 1)
  assert_eq(option_int_or(cut_entries1.get("D->H"), -999), 2)
  assert_eq(option_int_or(cut_entries1.get("E->F"), -999), 4)

  let step2 = exchange_steps[2]
  assert_eq(
    normalized_leave_tree_edge_key_from_exchange_step(nodes, step2),
    "C->F",
  )
  assert_eq(
    directed_enter_graph_edge_key_from_exchange_step(nodes, step2),
    "B->C",
  )
  assert_eq(step2.rank_by_node_index, [-2, -2, -1, -1, -1, 0, 0, 0])
  assert_eq(step2.parent_by_node, [-1, 2, 0, 6, 1, 4, 2, 3])
  assert_eq(step2.low_by_node, [1, 1, 1, 4, 1, 1, 4, 4])
  assert_eq(step2.lim_by_node, [8, 3, 7, 5, 2, 1, 6, 4])
  let cut_entries2 = active_tree_cut_entries_from_exchange_step(nodes, step2)
  assert_eq(map_string_int_entry_count(cut_entries2), 7)
  assert_eq(option_int_or(cut_entries2.get("A->C"), -999), 1)
  assert_eq(option_int_or(cut_entries2.get("B->C"), -999), 1)
  assert_eq(option_int_or(cut_entries2.get("B->E"), -999), 1)
  assert_eq(option_int_or(cut_entries2.get("C->G"), -999), 2)
  assert_eq(option_int_or(cut_entries2.get("D->G"), -999), 1)
  assert_eq(option_int_or(cut_entries2.get("D->H"), -999), 2)
  assert_eq(option_int_or(cut_entries2.get("E->F"), -999), 3)
}

///|
test "Layout simplex ranker matches upstream rank corpus with pivot coverage" {
  let (ok0, max_rank0, pivots0, ranks0) = collect_simplex_rank_trace_case([
    flow_edge("A", "E"),
    flow_edge("A", "G"),
    flow_edge("A", "H"),
    flow_edge("B", "E"),
    flow_edge("C", "D"),
    flow_edge("C", "E"),
    flow_edge("C", "G"),
    flow_edge("F", "G"),
  ])
  assert_eq(ok0, true)
  assert_eq(max_rank0, 1)
  assert_eq(pivots0, 0)
  assert_eq(ranks0, [0, 0, 0, 1, 1, 0, 1, 1])

  let (ok1, max_rank1, pivots1, ranks1) = collect_simplex_rank_trace_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "F"),
    flow_edge("A", "H"),
    flow_edge("B", "D"),
    flow_edge("B", "G"),
    flow_edge("E", "F"),
    flow_edge("E", "G"),
    flow_edge("E", "H"),
  ])
  assert_eq(ok1, true)
  assert_eq(max_rank1, 1)
  assert_eq(pivots1, 1)
  assert_eq(ranks1, [0, 0, 1, 1, 0, 1, 1, 1])

  let (ok2, max_rank2, pivots2, ranks2) = collect_simplex_rank_trace_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "G"),
    flow_edge("A", "H"),
    flow_edge("B", "F"),
    flow_edge("B", "G"),
    flow_edge("C", "G"),
    flow_edge("C", "H"),
    flow_edge("D", "F"),
    flow_edge("E", "F"),
    flow_edge("E", "H"),
  ])
  assert_eq(ok2, true)
  assert_eq(max_rank2, 2)
  assert_eq(pivots2, 2)
  assert_eq(ranks2, [0, 1, 1, 1, 1, 2, 2, 2])

  let (ok3, max_rank3, pivots3, ranks3) = collect_simplex_rank_trace_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("B", "E"),
    flow_edge("B", "F"),
    flow_edge("B", "G"),
    flow_edge("C", "G"),
    flow_edge("C", "H"),
    flow_edge("D", "F"),
    flow_edge("D", "G"),
    flow_edge("E", "F"),
    flow_edge("E", "G"),
  ])
  assert_eq(ok3, true)
  assert_eq(max_rank3, 2)
  assert_eq(pivots3, 3)
  assert_eq(ranks3, [0, 0, 1, 1, 1, 2, 2, 2])

  let (ok4, max_rank4, pivots4, ranks4) = collect_simplex_rank_trace_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("A", "G"),
    flow_edge("A", "H"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("B", "E"),
    flow_edge("B", "F"),
    flow_edge("B", "G"),
    flow_edge("B", "H"),
    flow_edge("C", "D"),
    flow_edge("C", "F"),
    flow_edge("C", "H"),
    flow_edge("D", "H"),
    flow_edge("E", "G"),
    flow_edge("F", "H"),
    flow_edge("G", "H"),
  ])
  assert_eq(ok4, true)
  assert_eq(max_rank4, 3)
  assert_eq(pivots4, 4)
  assert_eq(ranks4, [0, 0, 1, 2, 1, 2, 2, 3])
}

///|
test "Layout simplex exchange sequence matches upstream corpus" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
    { id: "G", label: "G", shape: Rectangle },
    { id: "H", label: "H", shape: Rectangle },
  ]

  fn collect_exchange_sequence_case(
    edges : Array[MermaidEdge],
  ) -> (Bool, Array[String], Array[String]) {
    let relaxed_edge_indices : Array[Int] = []
    for edge_index in 0..<edges.length() {
      relaxed_edge_indices.push(edge_index)
    }
    let (_, _, ok, exchange_steps) = collect_dagre_network_simplex_ranks_with_trace(
      nodes,
      edges,
      relaxed_edge_indices,
      [],
      true,
    )
    let leave_keys : Array[String] = []
    let enter_keys : Array[String] = []
    for step in exchange_steps {
      leave_keys.push(
        normalized_leave_tree_edge_key_from_exchange_step(nodes, step),
      )
      enter_keys.push(
        directed_enter_graph_edge_key_from_exchange_step(nodes, step),
      )
    }
    (ok, leave_keys, enter_keys)
  }

  let (ok1, leave1, enter1) = collect_exchange_sequence_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "F"),
    flow_edge("A", "H"),
    flow_edge("B", "D"),
    flow_edge("B", "G"),
    flow_edge("E", "F"),
    flow_edge("E", "G"),
    flow_edge("E", "H"),
  ])
  assert_eq(ok1, true)
  assert_eq(leave1, ["B->D"])
  assert_eq(enter1, ["A->F"])

  let (ok2, leave2, enter2) = collect_exchange_sequence_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "G"),
    flow_edge("A", "H"),
    flow_edge("B", "F"),
    flow_edge("B", "G"),
    flow_edge("C", "G"),
    flow_edge("C", "H"),
    flow_edge("D", "F"),
    flow_edge("E", "F"),
    flow_edge("E", "H"),
  ])
  assert_eq(ok2, true)
  assert_eq(leave2, ["B->G", "E->F"])
  assert_eq(enter2, ["A->D", "C->H"])

  let (ok3, leave3, enter3) = collect_exchange_sequence_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("B", "E"),
    flow_edge("B", "F"),
    flow_edge("B", "G"),
    flow_edge("C", "G"),
    flow_edge("C", "H"),
    flow_edge("D", "F"),
    flow_edge("D", "G"),
    flow_edge("E", "F"),
    flow_edge("E", "G"),
  ])
  assert_eq(ok3, true)
  assert_eq(leave3, ["B->C", "E->F", "A->D"])
  assert_eq(enter3, ["A->D", "A->E", "B->C"])

  let (ok4, leave4, enter4) = collect_exchange_sequence_case([
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("A", "G"),
    flow_edge("A", "H"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("B", "E"),
    flow_edge("B", "F"),
    flow_edge("B", "G"),
    flow_edge("B", "H"),
    flow_edge("C", "D"),
    flow_edge("C", "F"),
    flow_edge("C", "H"),
    flow_edge("D", "H"),
    flow_edge("E", "G"),
    flow_edge("F", "H"),
    flow_edge("G", "H"),
  ])
  assert_eq(ok4, true)
  assert_eq(leave4, ["B->C", "A->C", "D->H", "F->H"])
  assert_eq(enter4, ["A->E", "C->D", "A->C", "C->F"])
}

///|
test "Layout dagre simplex ranker matches upstream fanout compaction baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "D"),
    flow_edge("C", "D"),
  ]

  let (ranks, max_rank) = collect_non_state_flow_ranks(
    nodes, edges, false, false, false, false, false, false, false, true,
  )

  assert_eq(max_rank, 2)
  assert_eq(option_int_or(ranks.get("A"), -1), 0)
  assert_eq(option_int_or(ranks.get("B"), -1), 1)
  assert_eq(option_int_or(ranks.get("C"), -1), 1)
  assert_eq(option_int_or(ranks.get("D"), -1), 2)
  assert_eq(option_int_or(ranks.get("E"), -1), 1)
  assert_eq(option_int_or(ranks.get("F"), -1), 1)
}

///|
test "Layout legacy ranker baseline stays unchanged when dagre simplex is disabled" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("A", "E"),
    flow_edge("A", "F"),
    flow_edge("B", "D"),
    flow_edge("C", "D"),
  ]

  let (ranks, max_rank) = collect_non_state_flow_ranks(
    nodes, edges, false, false, false, false, false, false, false, false,
  )

  assert_eq(max_rank, 2)
  assert_eq(option_int_or(ranks.get("A"), -1), 0)
  assert_eq(option_int_or(ranks.get("B"), -1), 1)
  assert_eq(option_int_or(ranks.get("C"), -1), 0)
  assert_eq(option_int_or(ranks.get("D"), -1), 2)
  assert_eq(option_int_or(ranks.get("E"), -1), 1)
  assert_eq(option_int_or(ranks.get("F"), -1), 1)
}

///|
test "Layout dagre simplex ranker preserves reversed feedback constraint baseline" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("B", "C"),
    flow_edge("C", "A"),
    flow_edge("C", "D"),
  ]

  let (ranks, max_rank) = collect_non_state_flow_ranks(
    nodes, edges, false, true, false, false, false, true, true, true,
  )

  assert_eq(max_rank, 3)
  assert_eq(option_int_or(ranks.get("A"), -1), 0)
  assert_eq(option_int_or(ranks.get("B"), -1), 1)
  assert_eq(option_int_or(ranks.get("C"), -1), 2)
  assert_eq(option_int_or(ranks.get("D"), -1), 3)
}

///|
test "Layout non-state rank selector keeps default strategy when exploration disabled" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [flow_edge("A", "B"), flow_edge("B", "A")]

  let selected = select_non_state_flow_rank_candidate(
    nodes,
    edges,
    [],
    false,
    false,
    true,
    false,
    false,
    false,
    true,
    true,
    true,
    false,
    false,
    false,
  )

  assert_true(selected.use_greedy_feedback_arc_set)
}

///|
test "Layout rank densify phase compacts sparse rank indices while preserving order" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
  ]
  let sparse_rank_by_id : Map[String, Int] = { "A": 0, "B": 2, "C": 5, "D": 2 }

  let (dense_rank_by_id, max_dense_rank) = densify_rank_assignment(
    nodes, sparse_rank_by_id,
  )

  assert_eq(max_dense_rank, 2)
  assert_eq(option_int_or(dense_rank_by_id.get("A"), -1), 0)
  assert_eq(option_int_or(dense_rank_by_id.get("B"), -1), 1)
  assert_eq(option_int_or(dense_rank_by_id.get("D"), -1), 1)
  assert_eq(option_int_or(dense_rank_by_id.get("C"), -1), 2)
}

///|
test "Layout non-state rank selector picks lower-scored candidate when exploration is enabled" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "B"),
    flow_edge("B", "C"),
    flow_edge("C", "A"),
    flow_edge("C", "D"),
    flow_edge("D", "B"),
  ]

  let dfs_candidate = collect_non_state_flow_rank_candidate(
    nodes,
    edges,
    [],
    false,
    false,
    true,
    false,
    false,
    false,
    false,
    true,
    true,
    false,
    false,
    false,
  )
  let greedy_candidate = collect_non_state_flow_rank_candidate(
    nodes,
    edges,
    [],
    false,
    false,
    true,
    false,
    false,
    false,
    false,
    true,
    true,
    true,
    false,
    false,
  )
  let selected = select_non_state_flow_rank_candidate(
    nodes,
    edges,
    [],
    false,
    false,
    true,
    false,
    false,
    false,
    true,
    true,
    false,
    true,
    false,
    false,
  )

  let selected_score = non_state_flow_rank_candidate_score(selected)
  assert_true(
    selected_score <= non_state_flow_rank_candidate_score(dfs_candidate),
  )
  assert_true(
    selected_score <= non_state_flow_rank_candidate_score(greedy_candidate),
  )
}

///|
test "Layout horizontal dagre parity candidate comparison gate follows policy" {
  assert_true(
    should_compare_horizontal_dagre_ordering_candidates(true, true, true, 30),
  )
  assert_true(
    !should_compare_horizontal_dagre_ordering_candidates(true, true, true, 29),
  )
  assert_true(
    !should_compare_horizontal_dagre_ordering_candidates(false, true, true, 40),
  )
  assert_true(
    !should_compare_horizontal_dagre_ordering_candidates(true, false, true, 40),
  )
  assert_true(
    !should_compare_horizontal_dagre_ordering_candidates(true, true, false, 40),
  )
}

///|
test "Layout primary rank selection prefers lower-scored parity ordering on stress 005" {
  let (graph, nodes_in_order) = fixture_graph_and_nodes_for_flow_layout(
    stress_005_long_span_backjumps_source(),
  )
  let horizontal = @layout_engine_graph_internal_core.layout_direction_is_horizontal(
    graph.direction,
  )
  let cycle_aware_layout = graph_has_cycle(nodes_in_order, graph.edges)

  assert_true(horizontal)
  assert_true(cycle_aware_layout)
  assert_true(graph.edges.length() >= 30)
  assert_true(
    should_compare_horizontal_dagre_ordering_candidates(
      true,
      horizontal,
      cycle_aware_layout,
      graph.edges.length(),
    ),
  )

  let legacy_order_candidate = select_non_state_flow_rank_candidate(
    nodes_in_order,
    graph.edges,
    graph.subgraphs,
    horizontal,
    false,
    cycle_aware_layout,
    false,
    false,
    true,
    true,
    true,
    false,
    false,
    true,
    false,
  )
  let parity_order_candidate = select_non_state_flow_rank_candidate(
    nodes_in_order,
    graph.edges,
    graph.subgraphs,
    horizontal,
    false,
    cycle_aware_layout,
    false,
    false,
    true,
    true,
    true,
    false,
    false,
    true,
    true,
  )
  let selected_candidate = select_primary_non_state_flow_rank_candidate(
    nodes_in_order,
    graph.edges,
    graph.subgraphs,
    horizontal,
    false,
    cycle_aware_layout,
    false,
    false,
    true,
    true,
    true,
    false,
    false,
    true,
  )

  let legacy_score = non_state_flow_rank_candidate_score(legacy_order_candidate)
  let parity_score = non_state_flow_rank_candidate_score(parity_order_candidate)
  let selected_score = non_state_flow_rank_candidate_score(selected_candidate)

  assert_true(parity_score < legacy_score)
  assert_eq(selected_score, parity_score)
  assert_eq(
    selected_candidate.lane_crossings,
    parity_order_candidate.lane_crossings,
  )
  assert_eq(
    selected_candidate.total_rank_edge_span,
    parity_order_candidate.total_rank_edge_span,
  )
}

///|
fn map_int_bool_entry_count(entries : Map[Int, Bool]) -> Int {
  let mut count = 0
  for _, _ in entries {
    count += 1
  }
  count
}

///|
test "Layout dagre simplex horizontal mode keeps per-rank lanes distinct" {
  let nodes : Array[MermaidNode] = [
    { id: "A", label: "A", shape: Rectangle },
    { id: "B", label: "B", shape: Rectangle },
    { id: "C", label: "C", shape: Rectangle },
    { id: "D", label: "D", shape: Rectangle },
    { id: "E", label: "E", shape: Rectangle },
    { id: "F", label: "F", shape: Rectangle },
    { id: "G", label: "G", shape: Rectangle },
    { id: "H", label: "H", shape: Rectangle },
  ]
  let edges : Array[MermaidEdge] = [
    flow_edge("A", "C"),
    flow_edge("A", "D"),
    flow_edge("B", "C"),
    flow_edge("B", "D"),
    flow_edge("C", "E"),
    flow_edge("D", "F"),
    flow_edge("C", "F"),
    flow_edge("D", "E"),
    flow_edge("E", "G"),
    flow_edge("F", "H"),
    flow_edge("E", "H"),
    flow_edge("F", "G"),
  ]
  let graph = lane_policy_graph(LR, nodes, edges, [])
  let lane_state = compute_legacy_lane_state(
    graph, nodes, false, false, true, false, false, false, true,
  )
  for rank in 0..<=lane_state.flow_max_rank {
    let lanes : Map[Int, Bool] = {}
    let mut node_count = 0
    for node in nodes {
      if option_int_or(lane_state.flow_rank_by_node_id.get(node.id), -1) == rank {
        node_count += 1
        lanes[option_int_or(lane_state.flow_lane_by_node_id.get(node.id), 0)] = true
      }
    }
    assert_eq(map_int_bool_entry_count(lanes), node_count)
  }
}

///|
test "Layout lane feedback strategy policy disables greedy path in dagre simplex mode" {
  let node_ids = [
    "N0", "N1", "N2", "N3", "N4", "N5", "N6", "N7", "N8", "N9", "N10", "N11",
  ]
  let nodes : Array[MermaidNode] = []
  for node_id in node_ids {
    nodes.push({ id: node_id, label: node_id, shape: Rectangle })
  }
  let edges : Array[MermaidEdge] = []
  let node_count = node_ids.length()
  for i in 0..<node_count {
    edges.push(flow_edge(node_ids[i], node_ids[(i + 1) % node_count]))
    edges.push(flow_edge(node_ids[i], node_ids[(i + 2) % node_count]))
    edges.push(flow_edge(node_ids[i], node_ids[(i + 5) % node_count]))
    edges.push(flow_edge(node_ids[(i + 3) % node_count], node_ids[i]))
    edges.push(flow_edge(node_ids[(i + 6) % node_count], node_ids[i]))
    edges.push(flow_edge(node_ids[(i + 7) % node_count], node_ids[i]))
  }
  let graph = lane_policy_graph(TB, nodes, edges, [])

  assert_true(
    select_default_use_greedy_feedback_arc_set(
      graph, true, false, false, false, false,
    ),
  )
  assert_true(
    should_allow_feedback_strategy_selection(
      graph, true, false, false, false, false,
    ),
  )
  assert_true(
    !select_default_use_greedy_feedback_arc_set(
      graph, true, false, false, false, true,
    ),
  )
  assert_true(
    !should_allow_feedback_strategy_selection(
      graph, true, false, false, false, true,
    ),
  )
}
