///|
fn trace_request_for_graph(
  graph : @model.MermaidGraph,
) -> GraphLayoutBackendRequest {
  let options = { ..@model.RenderOptions::default(), layout_engine: Some(Elk) }
  { graph, options, use_subgraph_redirects: true, compact_fanin: false }
}

///|
fn collect_rank_trace_for_graph(
  graph : @model.MermaidGraph,
) -> ElkLayeredRankTrace raise {
  match collect_elk_layered_rank_trace(trace_request_for_graph(graph)) {
    Some(trace) => trace
    None => fail("expected elk layered rank trace")
  }
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
test "elk layered rank trace keeps fanout kernel baseline" {
  let graph = wb_graph(["A", "B", "C", "D", "E", "F"], [
    ("A", "B"),
    ("A", "C"),
    ("A", "D"),
    ("B", "E"),
    ("C", "E"),
    ("D", "F"),
    ("E", "F"),
  ])
  let trace = collect_rank_trace_for_graph(graph)
  assert_eq(trace.rank_input_node_ids_in_order, ["A", "B", "C", "D", "E", "F"])
  assert_eq(trace.rank_input_resolved_edges, [
    ("A", "B"),
    ("A", "C"),
    ("A", "D"),
    ("B", "E"),
    ("C", "E"),
    ("D", "F"),
    ("E", "F"),
  ])
  assert_eq(trace.rank_seed_strategy, "native-feedback")
  assert_eq(trace.rank_order_strategy, "optimized-seed-with-virtual-candidate")
  assert_eq(trace.rank_order_selected_source, "virtual")
  assert_eq(
    trace.rank_feedback_oriented_edges_model_order,
    trace.rank_feedback_oriented_edges,
  )
  assert_eq(trace.rank_seed_layers, [["A"], ["B", "C"], ["D", "E"], ["F"]])
  assert_eq(
    trace.rank_order_optimized_reversed_seed_layers,
    trace.rank_order_optimized_seed_layers,
  )
  assert_eq(
    trace.rank_order_optimized_reversed_seed_crossings,
    trace.rank_order_optimized_seed_crossings,
  )
  assert_eq(trace.rank_order_selected_layers, [
    ["A"],
    ["C", "B"],
    ["E", "D"],
    ["F"],
  ])
  assert_eq(trace.rank_layers, [["A"], ["C", "B"], ["E", "D"], ["F"]])
  assert_eq(trace.placement_major_strategy, "rank-centered")
  assert_eq(trace.placement_major_coord_by_node_id.length(), 6)
  assert_eq(trace.placement_minor_coord_by_node_id.length(), 6)
  assert_true(
    option_int_or(trace.placement_major_coord_by_node_id.get("A"), 0) <
    option_int_or(trace.placement_major_coord_by_node_id.get("F"), 0),
  )
}

///|
test "elk layered rank trace keeps feedback mesh kernel baseline" {
  let graph = wb_graph(["S", "A", "B", "C", "D", "T"], [
    ("S", "A"),
    ("S", "B"),
    ("A", "C"),
    ("B", "C"),
    ("C", "D"),
    ("D", "T"),
    ("D", "B"),
    ("C", "A"),
  ])
  let trace = collect_rank_trace_for_graph(graph)
  assert_eq(trace.rank_seed_strategy, "native-feedback")
  assert_eq(trace.rank_order_strategy, "optimized-seed-with-virtual-candidate")
  assert_eq(trace.rank_order_selected_source, "virtual")
  assert_true(
    trace.rank_feedback_oriented_edges_model_order !=
    trace.rank_feedback_oriented_edges,
  )
  assert_eq(trace.rank_seed_layers, [["S"], ["A", "B"], ["C"], ["D"], ["T"]])
  assert_eq(
    trace.rank_order_optimized_reversed_seed_layers,
    trace.rank_order_optimized_seed_layers,
  )
  assert_eq(
    trace.rank_order_optimized_reversed_seed_crossings,
    trace.rank_order_optimized_seed_crossings,
  )
  assert_eq(trace.rank_order_optimized_seed_layers, [
    ["S"],
    ["B", "A"],
    ["C"],
    ["D"],
    ["T"],
  ])
  assert_eq(trace.rank_order_virtual_candidate_layers, [
    ["S"],
    ["A", "B"],
    ["C"],
    ["D"],
    ["T"],
  ])
  assert_eq(trace.rank_order_selected_layers, [
    ["S"],
    ["A", "B"],
    ["C"],
    ["D"],
    ["T"],
  ])
  assert_true(
    trace.rank_order_virtual_candidate_crossings <=
    trace.rank_order_optimized_seed_crossings,
  )
  assert_eq(trace.rank_layers, [["S"], ["A", "B"], ["C"], ["D"], ["T"]])
}

///|
test "elk layered rank trace keeps long span kernel baseline" {
  let graph = wb_graph(["N0", "N1", "N2", "N3", "N4", "N5", "N6"], [
    ("N0", "N1"),
    ("N1", "N2"),
    ("N2", "N3"),
    ("N3", "N4"),
    ("N4", "N5"),
    ("N5", "N6"),
    ("N0", "N4"),
    ("N1", "N5"),
    ("N2", "N6"),
    ("N6", "N3"),
  ])
  let trace = collect_rank_trace_for_graph(graph)
  assert_eq(trace.rank_seed_strategy, "native-feedback")
  assert_eq(trace.rank_order_strategy, "optimized-seed-with-virtual-candidate")
  assert_eq(trace.rank_order_selected_source, "virtual")
  assert_eq(trace.rank_seed_layers, [
    ["N0"],
    ["N1"],
    ["N2", "N5"],
    ["N6"],
    ["N3"],
    ["N4"],
  ])
  assert_eq(
    trace.rank_order_optimized_reversed_seed_layers,
    trace.rank_order_optimized_seed_layers,
  )
  assert_eq(
    trace.rank_order_optimized_reversed_seed_crossings,
    trace.rank_order_optimized_seed_crossings,
  )
  assert_eq(trace.rank_order_selected_layers, [
    ["N0"],
    ["N1"],
    ["N2", "N5"],
    ["N6"],
    ["N3"],
    ["N4"],
  ])
  assert_eq(
    trace.rank_order_optimized_seed_crossings,
    trace.rank_order_virtual_candidate_crossings,
  )
  assert_eq(trace.rank_layers, [
    ["N0"],
    ["N1"],
    ["N2", "N5"],
    ["N6"],
    ["N3"],
    ["N4"],
  ])
  assert_eq(trace.placement_major_strategy, "rank-centered")
  assert_eq(trace.placement_major_coord_by_node_id.length(), 7)
  assert_eq(trace.placement_minor_coord_by_node_id.length(), 7)
}

///|
test "elk layered rank trace matches upstream sort-by-input layers on stress_006 fixture" {
  let graph = @parser_header_core.parse_mermaid(
    stress_006_nested_bridge_loops_source(),
  )
  let trace = collect_rank_trace_for_graph(graph)
  assert_eq(trace.rank_seed_strategy, "native-feedback")
  assert_eq(trace.rank_seed_layers, [
    ["SRC"],
    ["L0", "R0"],
    ["L1", "L4", "R1", "R4"],
    ["SNK", "R2", "RI3"],
    ["LI1", "R3"],
    ["L2", "LI2"],
    ["RI1"],
    ["LI3", "RI2"],
    ["L3"],
  ])
  assert_eq(trace.placement_major_strategy, "relaxed-compaction")
  assert_eq(trace.placement_major_coord_by_node_id.length(), 18)
  assert_eq(trace.placement_minor_coord_by_node_id.length(), 18)
}
